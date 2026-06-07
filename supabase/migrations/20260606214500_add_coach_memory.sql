-- Add a rolling "coaching memory" to coach_insights.
--
-- The gemini-coach-insights function maintains a short (1-2 sentence) running summary
-- of past nudges + observed patterns. It is fed back into each generation so the coach
-- avoids repeating itself and can acknowledge progress. This is deliberately a single
-- evolving string (not a history table) so it never grows the prompt unbounded.
--
-- Server-only state: it is written by the Edge Function (service role) and stripped from
-- the client response, so no new RLS policy is required (the existing SELECT-own policy
-- stays as-is; the function uses the service role which bypasses RLS).
ALTER TABLE public.coach_insights
  ADD COLUMN IF NOT EXISTS coach_memory text;
