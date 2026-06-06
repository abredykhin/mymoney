import { createServiceRoleClient, requireAuth, handleCors, jsonResponse } from '../_shared/auth.ts';
import { GoogleGenerativeAI } from 'npm:@google/generative-ai@0.2.0';

Deno.serve(async (req: Request) => {
  // Handle CORS
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  try {
    // Authenticate user
    const authResult = await requireAuth(req);
    if (authResult instanceof Response) {
      return authResult;
    }
    const user = authResult;
    if (!user) {
      return jsonResponse({ error: 'Unauthorized', message: 'User not found' }, 401);
    }

    const supabase = createServiceRoleClient();

    // 1. Parse optional force refresh flag from JSON body
    let force = false;
    const contentType = req.headers.get('content-type') || '';
    if (contentType.includes('application/json')) {
      try {
        const body = await req.json();
        if (body && typeof body.force === 'boolean') {
          force = body.force;
        }
      } catch (_) {
        // Safe to ignore: empty or invalid request body
      }
    }

    // 2. Check coach_insights table for existing cache
    const { data: cachedInsight } = await supabase
      .from('coach_insights')
      .select('*')
      .eq('user_id', user.id)
      .maybeSingle();

    if (cachedInsight && !force) {
      // Check for transactions and profile updates since last cache generation
      const { data: latestTx } = await supabase
        .from('transactions_table')
        .select('created_at')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();

      const { data: profileData } = await supabase
        .from('profiles_table')
        .select('updated_at')
        .eq('id', user.id)
        .maybeSingle();

      const cachedTime = new Date(cachedInsight.updated_at).getTime();
      const latestTxTime = latestTx?.created_at ? new Date(latestTx.created_at).getTime() : 0;
      const profileUpdateTime = profileData?.updated_at ? new Date(profileData.updated_at).getTime() : 0;

      const oneDayMs = 24 * 60 * 60 * 1000;
      const isFresh = (Date.now() - cachedTime) < oneDayMs;
      
      const hasNewTx = latestTxTime > cachedTime;
      const hasProfileUpdate = profileUpdateTime > cachedTime;

      // Early exit if the cache is fresh and no updates occurred, or if no new data was added at all
      if (isFresh && !hasNewTx && !hasProfileUpdate) {
        console.log(`[Cache Hit] Using cached Coach insight for user ${user.id} (insight is fresh, no new transactions or profile updates).`);
        return jsonResponse(cachedInsight);
      }

      if (isFresh) {
        console.log(`[Cache Hit] Using cached Coach insight for user ${user.id} (within 24h cooldown period).`);
        return jsonResponse(cachedInsight);
      }

      if (!hasNewTx && !hasProfileUpdate) {
        console.log(`[Cache Hit] Using cached Coach insight for user ${user.id} (older than 24h, but no new transactions or profile updates detected).`);
        return jsonResponse(cachedInsight);
      }
      
      console.log(`[Cache Stale] Cache is stale (>24h) and updates detected for user ${user.id}. Regenerating.`);
    } else if (cachedInsight && force) {
      console.log(`[Cache Bypass] Force refresh requested for user ${user.id}. Regenerating.`);
    } else {
      console.log(`[Cache Miss] No cached insight found for user ${user.id}. Generating.`);
    }

    // Fetch user profile guidelines
    const { data: profile } = await supabase
      .from('profiles_table')
      .select('monthly_income, monthly_mandatory_expenses')
      .eq('id', user.id)
      .single();

    // Fetch accounts to calculate net liquid cash
    const { data: accounts } = await supabase
      .from('accounts')
      .select('current_balance, type')
      .eq('hidden', false);

    const netCash = (accounts || []).reduce((sum, acc) => {
      const type = (acc.type || '').toLowerCase();
      if (type === 'depository') {
        return sum + Number(acc.current_balance || 0);
      } else if (type === 'credit') {
        return sum - Number(acc.current_balance || 0);
      }
      return sum;
    }, 0);

    // Fetch last 14 days of transactions
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - 14);
    const startDateStr = startDate.toISOString().split('T')[0];

    const { data: txs } = await supabase
      .from('transactions_table')
      .select('amount, name, date, personal_finance_category')
      .eq('user_id', user.id)
      .gte('date', startDateStr);

    // Fetch active subscription streams. The view intentionally excludes rent/mortgage
    // so fixed housing costs don't get framed as subscription leaks.
    const { data: subs } = await supabase
      .from('active_subscription_streams')
      .select('description, monthly_amount, last_date')
      .eq('user_id', user.id)
      .order('monthly_amount', { ascending: false });

    // Fetch active mandatory expense streams (including rent/mortgage) for upcoming bill alerts
    const { data: mandatoryStreams } = await supabase
      .from('active_mandatory_expense_streams')
      .select('description, average_amount, monthly_amount, predicted_next_date, personal_finance_category')
      .eq('user_id', user.id);

    const fallbackResponse = {
      badge: "COACH • INSIGHT",
      headline: "Track your variable pace",
      nudge_text: "Your dining out spend is trending slightly higher than last week. Consider home brewing to save around $45.",
      action_label: "View Pacing",
      alternative_tip: "Swapping one takeout order for a home meal will put you back under your daily allowance."
    };

    const apiKey = Deno.env.get('GEMINI_API_KEY');

    if (!apiKey || apiKey === 'test-gemini-key' || Deno.env.get('TEST_MODE') === 'true') {
      console.warn(`[Fallback] Using mock AI response (missing GEMINI_API_KEY, test mode, or test key). API Key status: ${apiKey ? 'Present' : 'Missing'}`);
      
      // Cache the fallback response to allow integration testing of caching
      const { error: cacheError } = await supabase
        .from('coach_insights')
        .upsert({
          user_id: user.id,
          badge: fallbackResponse.badge,
          headline: fallbackResponse.headline,
          nudge_text: fallbackResponse.nudge_text,
          action_label: fallbackResponse.action_label,
          alternative_tip: fallbackResponse.alternative_tip,
          updated_at: new Date().toISOString()
        });

      if (cacheError) {
        console.error(`Failed to cache fallback insight for user ${user.id}:`, cacheError);
      } else {
        console.log(`Successfully cached fallback insight for user ${user.id}.`);
      }

      return jsonResponse(fallbackResponse);
    }

    try {
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({
        model: "gemini-2.0-flash",
        generationConfig: {
          responseMimeType: "application/json"
        }
      });

      const prompt = `
        You are Bablo's premium financial coach, styled in a punchy, direct comic-book manga tone.
        Analyze the following financial data and write a short, highly-contextual spending nudge.
        
        User Context:
        - Current Net Cash Available (Bank minus Credit Debt): $${netCash}
        - Monthly Income (Expected): $${profile?.monthly_income ?? 0}
        - Fixed Expenses (Expected Monthly): $${profile?.monthly_mandatory_expenses ?? 0}
        
        Upcoming/Active Bills (Mandatory Recurring Streams):
        ${JSON.stringify(mandatoryStreams || [])}
        
        Recent Transactions (Last 14 Days):
        ${JSON.stringify(txs || [])}
        
        Active Recurring Subscriptions (Optional):
        ${JSON.stringify(subs || [])}
        
        Rules:
        1. CASH SQUEEZE RULE (High Priority): If the user's Current Net Cash Available is low (e.g. under $1,000) and they have a large mandatory bill (like rent, mortgage, or credit payment) due in the next 10 days that exceeds their cash available, prioritize alerting them about this squeeze. Challenge them to a "zero-spend lockdown" until the next paycheck hits.
        2. Otherwise, focus on the single largest area of overspending or variable leak (e.g. Dining out, Coffee, Subscriptions).
        3. Give a highly specific, mathematical recommendation (e.g., "Pause coffee for 3 days and bank ~$24").
        4. Keep the output extremely brief (max 2 sentences for notification, 2 for detail).
        5. Return a valid JSON object matching this structure EXACTLY:
        {
          "badge": "COACH • URGENT" or "COACH • INSIGHT",
          "headline": "headline message here",
          "nudge_text": "nudge text with pacing and exact numbers here",
          "action_label": "action button text",
          "alternative_tip": "alternative option or tip here"
        }
      `;

      const result = await model.generateContent(prompt);
      const text = result.response.text();
      try {
        const json = JSON.parse(text);

        // Cache the successfully generated insight
        const { error: cacheError } = await supabase
          .from('coach_insights')
          .upsert({
            user_id: user.id,
            badge: json.badge,
            headline: json.headline,
            nudge_text: json.nudge_text,
            action_label: json.action_label,
            alternative_tip: json.alternative_tip,
            updated_at: new Date().toISOString()
          });

        if (cacheError) {
          console.error(`Failed to cache generated insight for user ${user.id}:`, cacheError);
        } else {
          console.log(`Successfully cached generated insight for user ${user.id}.`);
        }

        return jsonResponse(json);
      } catch (parseError) {
        console.error('Failed to parse Gemini response as JSON. Raw response:', text);
        return jsonResponse(fallbackResponse);
      }
    } catch (geminiError) {
      console.error('Error invoking Gemini:', geminiError);
      return jsonResponse(fallbackResponse);
    }

  } catch (error: any) {
    console.error('Coach insights failed:', error);
    return jsonResponse({ error: error.message }, 500);
  }
});
