# The Cushion — Phase 5 Proposal (framing redesign)

Status: **proposal / not yet implemented.** Phases 1–4 (data-layer unification, hero clarity,
driver reconciliation, pace fixes) have shipped; see `AGENTS.md` → *Review Findings And Risks*.

## Why a Phase 5 is needed

After Phases 1–4 the Cushion sheet is **internally consistent** (every card reads the discretionary
`variable_transactions` layer over MTD-aligned windows, and the drivers reconcile to the hero's
`roomDelta`). But two framing problems survive that no amount of plumbing fixes:

1. **`previousRoom` is fabricated.** `HeroCushionSnapshot.previousRoom = currentRoom − roomDelta`
   ([HeroBudgetCalculator.swift](../ios/Bablo/Bablo/Services/HeroBudgetCalculator.swift)). It is
   *this* month's cushion minus the spend delta — i.e. it silently assumes last month's income and
   fixed costs were identical to this month's. We never compute last month's *actual* cushion, so
   "LAST MO LEFT $6,237" is an inference, not a fact.

2. **A partial period vs. a partial period is a thin signal.** On June 1, "this month" is one day
   old. June 1 ($562) vs May 1 ($482) is a real comparison, but a single day swings wildly and the
   headline ("$80 less to spend") over-reads one day of noise. The pace chart has essentially one
   point. Users intuitively want "am I on track for the month?", not "how did day 1 compare?".

## Proposed reframing: lead with the projection

Shift the hero from a **delta-of-a-delta** to a **cushion + projection**:

- **Primary number:** the cushion itself — "$6,157 safe to spend" (current `currentRoom`).
- **Secondary line:** a pace projection — "On pace to end June with ~$X left, vs $Y left last month."
  - `projectedEndRoom = currentRoom − (currentDailyPace × daysRemaining)`, where
    `currentDailyPace = currentSpend / daysElapsed`.
  - `lastMonthEndRoom` = last month's **actual** end-of-month cushion (see data work below), so the
    comparison is fact vs. projection, not fabricated-vs-actual.
- **Bars/visual:** keep the two-bar cushion comparison, but label the previous bar honestly — either
  "last month, same day" (the aligned MTD cushion we can actually compute) or "last month, final"
  (actual end-of-month cushion). Drop any bar we can only fabricate.

Drivers and pace cards stay as they are post-Phase-1 (already discretionary + reconciling); the pace
card becomes the natural "projection" visual once it has more than one day of data.

## Data work required

1. **Last month's actual cushion.** Compute `monthlyDiscretionary_lastMonth − lastMonthVariableSpend`
   using last month's income/mandatory snapshot, not this month's. Two options:
   - Persist a monthly cushion snapshot at month rollover (cleanest, enables true history), or
   - Recompute from `profiles` history + full prior-month `variable_transactions` on demand.
   Prefer the snapshot table — it also unlocks multi-month trends later.
2. **Daily pace series** already exists (`cushionDailySeries`); reuse for the projection slope.
3. **Guardrails:** suppress the projection (or widen it to a range) until `daysElapsed >= N` (e.g. 3)
   so day-1 noise doesn't produce a scary headline. Before the threshold, lead with the plain
   cushion and "too early to call the pace."

## Copy implications

- Headline becomes a statement of fact ("$6,157 safe to spend") + a hedged projection, instead of a
  delta that demands mental math.
- `CushionVerdictCopy` headlines/eyebrows shift from "you're $80 tighter than last month" to
  pace-oriented ("trending $X under/over last month's finish").

## Scope / sequencing

- Backend: monthly cushion snapshot table + writer at rollover (or on-demand recompute). ~1 migration
  + a small writer in the recurring/sync path.
- iOS: extend `HeroCushionSnapshot` with `projectedEndRoom` / `lastMonthEndRoom`; rework
  `CushionHeroComparisonCard` + `CushionVerdictCopy`; add the day-threshold guardrail.
- Risk: the projection slope is naive (linear). Acceptable for v1; refine with weekday weighting
  later if needed.

This is a deliberate redesign, not a bug fix — schedule it on its own once Phases 1–4 have been
validated against real usage.
