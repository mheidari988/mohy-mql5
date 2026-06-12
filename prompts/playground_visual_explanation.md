# Playground Visual Explanation Prompt

```text
Use the MOHY playground for this explanation.

Question:
<your question here>

Output requirements:
1) Create/update a playground artifact JSON in `playground/artifacts/runs/` with:
   - chart-relevant data from active kernel layers (candles/elements/legs/swings3/potential_impulses/potential_corrections/potential_continuation_signals/trade_setup_plans as needed)
   - `explanation` object: { "title", "format":"markdown", "content" }.
2) If useful, also create a separate note file in `playground/artifacts/runs/` (markdown or html).
3) Keep explanation practical: short summary + step-by-step + key takeaways.
4) Tell me exactly which file(s) you created and how to open them in `playground/viewer/index.html`.
5) Do not put this in `temp/`; use persistent `playground/`.
```

## Example filled version

```text
Use the MOHY playground for this explanation.

Question:
Explain how the active kernel ladder moves from `Swing3` into continuation confirmation and then into `TradeSetupPlan`, using one synthetic bullish and one synthetic bearish case.

Output requirements:
1) Create `playground/artifacts/runs/swing3_to_trade_setup_dual_case.json` including candles, elements, legs, swings3, potential_impulses, potential_corrections, potential_continuation_signals, trade_setup_plans and an `explanation` markdown payload.
2) Highlight in explanation:
  - what Swing3 captures,
  - how continuation confirmation is derived,
  - where the trade setup trigger/stop/target become actionable.
3) Tell me how to load it in `playground/viewer/index.html`.
4) Keep all outputs in `playground/` only.
```
