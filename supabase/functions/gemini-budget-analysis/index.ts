/**
 * Supabase Edge Function: gemini-budget-analysis
 * 
 * Automatically identifies user income and fixed costs using Gemini 2.0 Flash.
 * Triggered after transaction sync.
 */

import { createServiceRoleClient, requireAuth, handleCors, jsonResponse } from '../_shared/auth.ts';

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY');
const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

interface Transaction {
    date: string;
    amount: number;
    name: string;
    personal_finance_category: string | null;
    account_type: string;
}

interface BudgetItem {
    name: string;
    pattern: string;
    amount: number;
    frequency: string;
    monthly_amount: number;
    type: 'income' | 'fixed_expense';
    confidence: number;
    last_seen_date: string;
}

Deno.serve(async (req: Request) => {
    // Handle CORS
    const corsResponse = handleCors(req);
    if (corsResponse) return corsResponse;

    try {
        const supabase = createServiceRoleClient();

        // 0. Get user_id from body or JWT
        let user_id: string | undefined;
        try {
            const body = await req.json();
            user_id = body.user_id;
        } catch {
            // Body might be empty, try to get from JWT
            console.log('No valid JSON body, attempting to get user from auth token');
        }

        if (!user_id) {
            const authResult = await requireAuth(req);
            if (authResult instanceof Response) {
                return authResult;
            }
            if (authResult && 'id' in authResult) {
                user_id = authResult.id;
            }
        }

        if (!user_id) {
            return jsonResponse({ error: 'Missing user_id' }, 400);
        }

        console.log(`🤖 Starting budget analysis for user: ${user_id}`);

        // 1. Fetch transactions (last 90 days)
        const ninetyDaysAgo = new Date();
        ninetyDaysAgo.setDate(ninetyDaysAgo.getDate() - 90);

        const { data: transactions, error: txError } = await supabase
            .from('transactions') // Using the 'transactions' view which should join with accounts
            .select('date, amount, name, personal_finance_category, type')
            .eq('user_id', user_id)
            .gte('date', ninetyDaysAgo.toISOString().split('T')[0])
            .order('date', { ascending: false });

        if (txError) {
            console.error('❌ Database error fetching transactions:', txError.message);
            throw txError;
        }
        if (!transactions || transactions.length === 0) {
            console.log('No transactions found for analysis');
            return jsonResponse({ success: true, message: 'No transactions to analyze' });
        }

        // 2. Format transactions for Gemini
        // Filter out transfers and tiny transactions to save tokens
        const transactionList = transactions as Transaction[];
        console.log(`📊 Processing ${transactionList.length} total transactions`);

        const filteredTxs = transactionList
            .filter((tx: any) => {
                // Primary exclusions: Transfers and tiny transactions
                const isExcluded = Math.abs(tx.amount) <= 5 || tx.personal_finance_category?.toLowerCase().includes('transfer');
                if (isExcluded) return false;

                // SPECIAL RULE: If it's a credit or loan account, ignore INFLOWS (negative amounts) 
                // as primary income. These are likely payments or refunds.
                if ((tx.type === 'credit' || tx.type === 'loan') && tx.amount < 0) {
                    console.log(`⚠️ Ignoring inflow on ${tx.type} account as potential income: ${tx.name} (${tx.amount})`);
                    return false;
                }

                return true;
            })
            .map((tx: any) => `${tx.date} | ${tx.amount.toFixed(2)} | ${tx.name} | ${tx.personal_finance_category || 'N/A'} | [${tx.type}]`)
            .join('\n');

        console.log(`📝 Filtered down to ${filteredTxs.split('\n').length} transactions for Gemini prompt`);

        const prompt = `You are a senior financial analyst. Analyze the following 90 days of transaction data.

**Goal**: Identify all recurring Income and Fixed Obligations.

**Amount Sign Logic (CRITICAL)**:
- **Positive Amount (> 0)**: Money LEAVING the account (Spent / Expense). 
  *Example: 100.00 means you paid $100.*
- **Negative Amount (< 0)**: Money ENTERING the account (Earned / Income). 
  *Example: -3500.00 means you received $3500.*

**Rules**:
1. **Categorization**: 
   - **'income'**: MUST have been a NEGATIVE amount in the data. Examples: Paychecks, Dividends.
   - **'fixed_expense'**: MUST have been a POSITIVE amount in the data. Examples: Rent, Netflix, Insurance.
2. **Exclusions (DO NOT INCLUDE)**:
   - **Credit Card Payments**: Ignore anything named 'Payment', 'Credit Card Payment', or 'Autopay'. These are transfers, not expenses.
   - **Internal Transfers**: Ignore anything between your own accounts.
   - **One-off Items**: Only include things that happen monthly, bi-weekly, or weekly.
3. **Confidence**: Assign a score from 0.0 to 1.0. Only items >= 0.85 will be used for the budget.
4. **Accuracy**: For items with fluctuating amounts, provide the monthly average.
5. **Pattern**: Provide a clean substring of the transaction name for future matching.

**Important**: Your JSON output MUST exactly match this structure for every item:
- name: Concise label (e.g. 'Rent', 'Netflix')
- pattern: Core description substring (e.g. 'NETFLIX.COM')
- amount: Typical amount per occurrence
- frequency: One of: weekly, bi-weekly, monthly, quarterly, yearly
- monthly_amount: Calculated monthly equivalent
- type: One of: income, fixed_expense
- confidence: Number (0.0 to 1.0)
- last_seen_date: YYYY-MM-DD of the most recent occurrence

**Data**:
${filteredTxs}

**Return ONLY JSON** in this format:
{ "items": [...] }`;

        // 3. Call Gemini
        const response = await fetch(`${GEMINI_API_URL}?key=${GEMINI_API_KEY}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                contents: [{ parts: [{ text: prompt }] }],
                generationConfig: { response_mime_type: "application/json" }
            }),
        });

        if (!response.ok) {
            const err = await response.text();
            throw new Error(`Gemini API error: ${err}`);
        }

        const genData = await response.json();
        const resultText = genData.candidates?.[0]?.content?.parts?.[0]?.text;
        if (!resultText) throw new Error('No response from Gemini');

        const result = JSON.parse(resultText);
        let items = result.items || [];

        console.log(`✅ Gemini identified ${items.length} potential recurring items`);

        // Post-processing and Validation
        items = items.filter((item: any) => {
            // 1. Sanity check: Income must be positive after conversion to monthly_amount
            // (Gemini returns absolute monthly_amount, but we check logic here)

            // 2. Ignore anything named 'Payment' - too many false positives for transfers
            if (item.name.toLowerCase().includes('payment')) {
                console.log(`   🚫 Filtering out 'Payment' item: ${item.name}`);
                return false;
            }

            // 3. More aggressive pattern check
            if (item.pattern.toLowerCase() === 'payment') return false;

            return true;
        });

        items.forEach((item: any) => {
            console.log(`   - [${item.confidence >= 0.85 ? 'HIGH' : 'LOW'}] ${item.name}: $${item.monthly_amount} (${item.type})`);
        });

        if (items.length > 0) {
            // 4. Upsert into budget_items_table
            const budgetItemsToUpsert = items.map((item: any) => ({
                user_id,
                name: item.name,
                pattern: item.pattern,
                amount: item.amount,
                frequency: item.frequency,
                monthly_amount: item.monthly_amount,
                type: item.type,
                confidence: item.confidence,
                last_seen_date: item.last_seen_date,
            }));

            const { error: upsertError } = await supabase
                .from('budget_items_table')
                .upsert(budgetItemsToUpsert, { onConflict: 'user_id,pattern' }); // Using user_id+pattern as unique key

            if (upsertError) {
                // If the unique constraint isn't set yet (migration might be fresh), fall back to insert
                console.error('Upsert failed, likely missing constraint:', upsertError.message);
                const { error: insertError } = await supabase.from('budget_items_table').insert(budgetItemsToUpsert);
                if (insertError) throw insertError;
            }

            // 5. Update Profile totals
            const highConfidenceItems = items.filter((item: any) => item.confidence >= 0.85);

            // Use absolute values for sums to avoid negative totals in profile
            const monthlyIncome = Math.abs(highConfidenceItems
                .filter((item: any) => item.type === 'income')
                .reduce((sum: number, item: any) => sum + Math.abs(item.monthly_amount), 0));

            const monthlyExpenses = Math.abs(highConfidenceItems
                .filter((item: any) => item.type === 'fixed_expense')
                .reduce((sum: number, item: any) => sum + Math.abs(item.monthly_amount), 0));

            console.log(`📈 Summary for profile update:`);
            console.log(`   - Total Monthly Income: $${monthlyIncome}`);
            console.log(`   - Total Mandatory Expenses: $${monthlyExpenses}`);

            const { error: profileError } = await supabase
                .from('profiles_table') // Note: some migrations might use 'profiles' view or table
                .update({
                    monthly_income: monthlyIncome,
                    monthly_mandatory_expenses: monthlyExpenses,
                })
                .eq('id', user_id);

            if (profileError) {
                console.error('❌ Failed to update profiles_table:', profileError.message);
                // Try 'profiles' just in case
                const { error: profileError2 } = await supabase
                    .from('profiles')
                    .update({
                        monthly_income: monthlyIncome,
                        monthly_mandatory_expenses: monthlyExpenses,
                    })
                    .eq('id', user_id);
                if (profileError2) throw profileError2;
            } else {
                console.log('✅ Successfully updated profile totals');
            }
        }

        return jsonResponse({
            success: true,
            count: items.length,
            items: items.map((i: any) => ({ name: i.name, type: i.type, confidence: i.confidence }))
        });

    } catch (error: any) {
        console.error('❌ Budget analysis failed:', error);
        return jsonResponse({ error: error.message }, 500);
    }
});
