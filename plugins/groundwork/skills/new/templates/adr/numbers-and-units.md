# NNNN — Numbers and units
Status: proposed <!-- on approval, change it to `approved (YYYY-MM-DD)` -->
Date: YYYY-MM-DD

## Context
Quantities that must not be wrong, like money · assets · points, silently drift apart when representation, rounding, scale and action results differ from layer to layer. Settle them once, with one library and one authority.

## Decision
1. **Amount representation.** Store and compute as integers in the minor unit. Transfer as strings or bigint. No floats. Minor unit: {{minor_unit}}, decimal places: {{decimals}}.
2. **Rounding.** One function per direction lives in the boundary module, and every calculation uses it. The default direction is never unfavorable to the user. Rounding happens at {{rounding_points}}. UI · API · DB do not each recompute the same value.
3. **Ratio scale.** Ratios · probabilities · prices are stored and transferred as {{ratio_scale}} (recommended: a single 0..1 fraction). Only the screen shows them converted. Exceptions go on this line with the field name: {{scale_exceptions}}.
4. **Results of actions that move money.** Model them as three states: not sent / sent · unconfirmed / confirmed. Once anything has been sent, lock resending, and tie retries together with an idempotency key. Both the screen and the API show these three states apart.
- Balances · profit and loss · points shown to the user come from {{balance_source}} (recommended: the server computes them once from a single append-only event ledger).

## Alternatives
- A decimal type in every layer: precision drifts in the conversions between layers.
- The caller decides rounding: the same value differs from screen to screen.
- Two states, success · failure: an action whose response is late or cut off looks failed and invites duplicate sends.

## Consequences
- Maintain the boundary module and the property tests (an independent oracle).
- If an external system uses different units, convert once at the boundary.

## How to verify
- Property tests of the amount boundary module: on random input the results equal an independent oracle, and rounded sums are preserved or not unfavorable to the user.
- Search for float use with rg and check that there is none in money code.
- Check on screen that the resend button is locked in the "sent · unconfirmed" state.
