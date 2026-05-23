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

    // Fetch user profile guidelines
    const { data: profile } = await supabase
      .from('profiles_table')
      .select('monthly_income, monthly_mandatory_expenses')
      .eq('id', user.id)
      .single();

    // Fetch last 14 days of transactions
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - 14);
    const startDateStr = startDate.toISOString().split('T')[0];

    const { data: txs } = await supabase
      .from('transactions_table')
      .select('amount, name, date, personal_finance_category')
      .eq('user_id', user.id)
      .gte('date', startDateStr);

    // Fetch active recurring streams
    const { data: subs } = await supabase
      .from('recurring_streams_table')
      .select('description, monthly_amount, last_date')
      .eq('user_id', user.id)
      .eq('type', 'expense')
      .eq('is_active', true);

    const fallbackResponse = {
      badge: "COACH • INSIGHT",
      headline: "Track your variable pace",
      nudge_text: "Your dining out spend is trending slightly higher than last week. Consider home brewing to save around $45.",
      action_label: "View Pacing",
      alternative_tip: "Swapping one takeout order for a home meal will put you back under your daily allowance."
    };

    const apiKey = Deno.env.get('GEMINI_API_KEY');

    if (!apiKey || apiKey === 'test-gemini-key' || Deno.env.get('TEST_MODE') === 'true') {
      console.log('Using mock AI response (offline or test mode)');
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
        - Monthly Income: $${profile?.monthly_income ?? 0}
        - Fixed Expenses: $${profile?.monthly_mandatory_expenses ?? 0}
        
        Recent Transactions (Last 14 Days):
        ${JSON.stringify(txs || [])}
        
        Active Recurring Subscriptions:
        ${JSON.stringify(subs || [])}
        
        Rules:
        1. Focus on the single largest area of overspending or variable leak (e.g. Dining out, Coffee, Subscriptions).
        2. Give a highly specific, mathematical recommendation (e.g., "Pause coffee for 3 days and bank ~$24").
        3. Keep the output extremely brief (max 2 sentences for notification, 2 for detail).
        4. Return a valid JSON object matching this structure EXACTLY:
        {
          "badge": "COACH • JUST NOW",
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
