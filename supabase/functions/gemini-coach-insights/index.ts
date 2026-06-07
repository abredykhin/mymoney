import { createServiceRoleClient, requireAuth, handleCors, jsonResponse } from '../_shared/auth.ts';
import { GoogleGenerativeAI } from 'npm:@google/generative-ai@0.21.0';

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

    // Fetch accounts to calculate net liquid cash.
    // NOTE: this uses the service-role client, which BYPASSES RLS — so the user_id
    // filter is mandatory. The `accounts` view's RLS-based scoping does not apply here,
    // and without it netCash would sum every user's balances (wrong number + cross-user leak).
    const { data: accounts } = await supabase
      .from('accounts')
      .select('current_balance, type')
      .eq('user_id', user.id)
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

    // Fetch last 14 days of REAL spend from the `transactions` view (is_spend = true)
    // rather than the raw transactions_table. The raw table mixes in income, internal
    // transfers, and credit-card payments, which would skew the "largest overspend" read.
    // is_spend is total spend INCLUDING bills; the is_mandatory flag lets the model tell
    // fixed bills apart from variable/discretionary leaks. This mirrors the Pulse
    // "where it went" layer (see CLAUDE.md spend-classification layers).
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - 14);
    const startDateStr = startDate.toISOString().split('T')[0];

    const { data: txs } = await supabase
      .from('transactions')
      .select('amount, name, merchant_name, spend_date, personal_finance_category, is_mandatory')
      .eq('user_id', user.id)
      .eq('is_spend', true)
      .gte('spend_date', startDateStr);

    // Aggregate the raw rows into compact summaries rather than sending 50+ line items,
    // AND split spend into two buckets the coach must treat very differently:
    //
    //   • OBLIGATIONS — money the user cannot simply "cut". This is is_spend that is
    //     either flagged mandatory (rent/bills), a person-to-person/external transfer
    //     (TRANSFER_OUT — e.g. spousal/child support, wires), or a large one-off lump sum
    //     (e.g. a legal retainer). These are real spend, but coaching someone to "stop
    //     paying support / legal fees" is both useless and tone-deaf, so they are kept
    //     OUT of the discretionary leak analysis and only summarized as fixed context.
    //   • DISCRETIONARY — everything else (dining, coffee, alcohol, shopping, etc.). This
    //     is the only bucket the leak/"pause X" nudges should draw from.
    const round2 = (n: number) => Math.round(n * 100) / 100;
    const ONE_OFF_LUMP_THRESHOLD = 1000; // a single payment this large is not a habit to pace
    const spendRows = txs || [];

    const isObligation = (t: any) =>
      !!t.is_mandatory
      || t.personal_finance_category === 'TRANSFER_OUT'
      || Math.abs(Number(t.amount || 0)) > ONE_OFF_LUMP_THRESHOLD;

    const categoryAgg = new Map<string, { spent: number; count: number }>();
    const merchantAgg = new Map<string, { spent: number; count: number }>();
    let totalSpent = 0;
    let obligationsSpent = 0;

    for (const t of spendRows) {
      const amt = Math.abs(Number(t.amount || 0));
      totalSpent += amt;

      if (isObligation(t)) {
        obligationsSpent += amt;
        continue; // never a discretionary leak — excluded from category/merchant analysis
      }

      const cat = t.personal_finance_category || 'UNKNOWN';
      const c = categoryAgg.get(cat) || { spent: 0, count: 0 };
      c.spent += amt;
      c.count += 1;
      categoryAgg.set(cat, c);

      const m = (t.merchant_name || t.name || 'Unknown').trim();
      const ma = merchantAgg.get(m) || { spent: 0, count: 0 };
      ma.spent += amt;
      ma.count += 1;
      merchantAgg.set(m, ma);
    }

    const discretionaryByCategory = [...categoryAgg.entries()]
      .map(([category, v]) => ({ category, spent: round2(v.spent), count: v.count }))
      .sort((a, b) => b.spent - a.spent);

    const topDiscretionaryMerchants = [...merchantAgg.entries()]
      .map(([merchant, v]) => ({ merchant, spent: round2(v.spent), count: v.count }))
      .sort((a, b) => b.spent - a.spent)
      .slice(0, 8);

    const discretionarySpent = round2(totalSpent - obligationsSpent);
    totalSpent = round2(totalSpent);
    obligationsSpent = round2(obligationsSpent);

    // Rolling coaching memory: a short running summary the model maintains across runs so
    // it can avoid repeating past nudges and acknowledge progress. Bounded to ~1-2
    // sentences, so it never grows the prompt the way storing full history would.
    const priorMemory = (cachedInsight as { coach_memory?: string } | null)?.coach_memory || '';

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

    // The cash-squeeze rule must reason over money that is *about to* leave, not money
    // that already left. Compute the bills genuinely due in the next 10 days so the model
    // can compare that against net cash — instead of misreading past large spend (a legal
    // payment, a support wire) as an imminent crunch.
    const nowMs = Date.now();
    const in10DaysMs = nowMs + 10 * 24 * 60 * 60 * 1000;
    const upcomingBills = (mandatoryStreams || [])
      .filter((s) => {
        if (!s.predicted_next_date) return false;
        const due = new Date(s.predicted_next_date).getTime();
        return due >= nowMs && due <= in10DaysMs;
      })
      .map((s) => ({
        description: s.description,
        amount: round2(Number(s.average_amount ?? s.monthly_amount ?? 0)),
        due: s.predicted_next_date,
      }))
      .sort((a, b) => b.amount - a.amount);
    const upcomingBills10dTotal = round2(
      upcomingBills.reduce((sum, b) => sum + b.amount, 0),
    );

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
        model: "gemini-2.5-flash",
        generationConfig: {
          responseMimeType: "application/json",
          // Disable thinking: this is a short, well-scoped nudge, not a reasoning task.
          // Thinking tokens are billed at the (10x) output rate and add latency for no
          // meaningful quality gain here — cuts per-call cost ~3x and speeds it up.
          thinkingConfig: { thinkingBudget: 0 }
        }
      });

      const prompt = `
        You are Bablo's premium financial coach, styled in a punchy, direct comic-book manga tone — but always supportive, never alarmist or preachy.

        IMPORTANT — read this before analyzing:
        - All "Last 14 Days" spend below is money that has ALREADY been spent (historical). NEVER describe it as upcoming, pending, or a reason to "avoid" a future crunch.
        - The ONLY forward-looking figure is "Upcoming Bills (Next 10 Days)". Use that, and only that, for any cash-squeeze reasoning.
        - Spend has been split for you into OBLIGATIONS (fixed, uncuttable — rent, loans, insurance, taxes, legal fees, and money sent to people such as spousal/child support or wires) and DISCRETIONARY (everything you can actually coach). Obligations are given only as context; you must NEVER suggest reducing, pausing, or "locking down" an obligation.
        - BE REALISTIC. A person can never spend $0 — they still have to buy ESSENTIALS (groceries, fuel/gas, basic household needs, medicine). Never demand a "zero-spend lockdown" or "spend nothing", and ESPECIALLY not when Net Cash is low or negative — that is impossible advice. When cash is tight, coach trimming NON-ESSENTIAL discretionary (dining out, alcohol, coffee, entertainment, shopping, subscriptions) while explicitly allowing essentials to continue. If Net Cash is negative, lead with empathy and a realistic, prioritized plan (cover essentials + obligations first, pause non-essentials), not a guilt trip.

        User Context:
        - Current Net Cash Available (Bank minus Credit Debt): $${round2(netCash)}
        - Monthly Income (Expected): $${round2(Number(profile?.monthly_income ?? 0))}
        - Fixed Expenses (Expected Monthly): $${round2(Number(profile?.monthly_mandatory_expenses ?? 0))}

        Spend Totals — Last 14 Days (historical):
        - Total spent: $${totalSpent} (fixed obligations $${obligationsSpent} / discretionary $${discretionarySpent})

        Discretionary Spend by Category — Last 14 Days (THIS is your leak-hunting ground):
        ${JSON.stringify(discretionaryByCategory)}

        Top Discretionary Merchants — Last 14 Days (use for specific "pause/trim X" nudges):
        ${JSON.stringify(topDiscretionaryMerchants)}

        Upcoming Bills (Next 10 Days) — total $${upcomingBills10dTotal}:
        ${JSON.stringify(upcomingBills)}

        Active Recurring Subscriptions (Optional, possible trims):
        ${JSON.stringify(subs || [])}

        Your Running Coaching Memory (prior nudges + observations; empty if this is the first time):
        ${priorMemory || '(none yet)'}

        Rules:
        1. CASH SQUEEZE RULE (High Priority, but only when REAL): Trigger this ONLY if "Upcoming Bills (Next 10 Days)" total is close to or greater than Current Net Cash Available. If upcoming bills are comfortably below net cash, there is NO squeeze — do not invent one, and use badge "COACH • INSIGHT". When a real squeeze exists, alert the user and suggest easing NON-ESSENTIAL discretionary spend until their next paycheck (never their obligations, and never their essentials like groceries or fuel). Do NOT tell them to "spend nothing".
        2. Otherwise, find the single biggest DISCRETIONARY leak from the category/merchant data and coach it. Ignore obligations entirely when picking the leak.
        3. Give a highly specific, mathematical recommendation grounded in the discretionary numbers (e.g., "Trim dining from $X to $Y and bank ~$Z").
        4. Keep it brief (max ~2 sentences each for nudge_text and alternative_tip) and empathetic.
        5. Use the Running Coaching Memory to AVOID repeating a nudge you already gave — pick a fresh angle, and acknowledge progress if the data shows the user improved on a past nudge.
        6. Update the memory: in "coach_memory", return an updated 1-2 sentence running summary (what you've now nudged about + key patterns/progress). Keep it short; it is fed back to you next time.
        7. Return a valid JSON object matching this structure EXACTLY:
        {
          "badge": "COACH • URGENT" or "COACH • INSIGHT",
          "headline": "headline message here",
          "nudge_text": "nudge text with pacing and exact numbers here",
          "action_label": "action button text",
          "alternative_tip": "alternative option or tip here",
          "coach_memory": "updated 1-2 sentence running summary for next time"
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
            // Persist the rolling memory so the next run can avoid repeating itself.
            // Fall back to the prior memory if the model omitted it this time.
            coach_memory: (typeof json.coach_memory === 'string' && json.coach_memory.trim())
              ? json.coach_memory.trim()
              : (priorMemory || null),
            updated_at: new Date().toISOString()
          });

        if (cacheError) {
          console.error(`Failed to cache generated insight for user ${user.id}:`, cacheError);
        } else {
          console.log(`Successfully cached generated insight for user ${user.id}.`);
        }

        // coach_memory is server-only rolling state; don't ship it to the client.
        delete json.coach_memory;
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
