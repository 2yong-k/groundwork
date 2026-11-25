# Design interview and deriving directions — reference for `/groundwork:new` stage 3

If you came into this stage by resuming, the stage 0 five-line report must come first in the same message, above the first question. If you have not written the report yet, write it now, then ask.

## A. Eight interview questions (one per message, each with a recommended answer + reason)

1. **Tone in 3 words** — if this product were a person, what impression would it give? E.g. "precise · quiet · solid". Draw the recommendation from the stage 1 users and scenarios.
2. **References** — 2–3 sites or apps that look good and *what* about them is good, 1–2 disliked ones and why. If there is a URL, look at it yourself with WebFetch and summarize.
3. **Type** — the typeface character for headings, body and numbers each (serif/grotesque/humanist/mono). If there is Korean body text, settle the Korean typeface first (Pretendard · Noto Sans KR · Spoqa, etc.). Recommendation: give heading and body one strong contrast.
4. **Color** — one brand color (hex if there is one), the temperature of the neutrals (warm/cool/true gray), whether dark mode is needed. Recommendation: 1 accent color + 5 status tones (neutral · info · positive · warn · danger), everything else neutral. Set both light and dark values.
5. **Density** — how much information fits on one screen (the default is medium-high). Products heavy on tables and lists: high.
6. **Shape** — corners (0/2/4/8px), border-led vs shadow-led, how surfaces are separated. Recommendation: a radius scale of 2 steps at most, shadows only on floating elements (menus · modals).
7. **Motion** — none/restrained/expressive. Recommendation: restrained — 120–200ms, ease-out, respect `prefers-reduced-motion` (both CSS and JS animation).
8. **Ban list** — what the user never wants to see. Show the B checklist below and ask what to add. If an addition is a taste that fits any project, write it in the token-lock commit report as one line the user could add to their global `~/.claude/CLAUDE.md`. Do not ask about it (that message's question is the one next-step question). The user decides whether to add it (`DESIGN.md` is read only in this project).

## B. AI-default aesthetics ban checklist (applies to both the sheet and the code)

- Purple-blue · purple-pink palettes, gradients on buttons · titles, blob · mesh gradient backgrounds
- A default stack of `font-family: system-ui` · `Inter` alone, every element the same weight · same size
- `transition: all`, hover zoom anywhere (`scale(1.05)`), shadows floating everywhere
- Glassmorphism (cards on blurred backgrounds), a 3-column "features" grid with icons in circles, emoji icons
- Big rounded corners (16px+) combined with pastel cards, every card the same size
- lorem ipsum, "Welcome to …", fake stat numbers, stock illustrations
- A landing that is nothing but a centered hero + two rounded CTA buttons
- Hardcoded colors · spacing outside the tokens (`#fff`, `12px` typed in directly)

## C. Rules for deriving the three directions

- The three must differ from one another on **at least two axes**. Axes: ① type pairing (serif headings + grotesque body / grotesque only / mono accent), ② neutral temperature (warm/cool/true), ③ density (medium/high), ④ shape (sharp borders / soft surfaces / lineless whitespace).
- One follows the user's answers to the recommended options most faithfully, one is more conservative, one is bolder. "Bold" means decisiveness in type contrast · whitespace · color use, not decoration.
- Give each a name (two words) and a one-line intent. The sheet's color variables map 1:1 to the `color` keys of `templates/design/tokens.json` (`--on-accent`, `--link`, `--focus`, `--tone-*-fg/bg`, etc.) — the chosen direction's values must carry over to `design/tokens.json` as they are.
- Fill the sample screen content with real copy from the stage 1 summary (product name · scenario sentences · real data shapes).

## D. Self-check before showing

1. Open the sheet in a browser and screenshot both light and dark (inside Weft with the weft-browser skill available: `weft browser open file://<abs>` → `weft browser screenshot`; otherwise `open` (macOS) or `xdg-open` (Linux)).
2. Go through the B checklist line by line. If anything trips, fix it.
3. Contrast: for each direction, fill a copy of `templates/design/tokens.json` (in a temp folder) with the sheet's light and dark values and run `node <skill-dir>/templates/gates/check-contrast.mjs <copy> <skill-dir>/templates/design/contrast-pairs.json`. Both themes must pass; for a failing pair, fix the value and carry it into the sheet too. Check in the screenshots too that the focus ring is visible.
4. Are the three really different (2+ axes) — not clones with only the colors changed?

## E. Lock outputs

Once locked, make the following. The one source is `tokens.json`; `tokens.css` · `theme.ts` are generated from it.

- `DESIGN.md` (`templates/DESIGN.md.tmpl`): the chosen direction's name · intent, principles (do), bans (don't = B + the user's additions), the token contract, the role token table, the state → tone table, the text-size minimum, focus, skeletons, motion, component conventions and the kit registration rule, the brand asset list, accessibility. If P5 is on, put the CJK font rules (per-language font stacks `--font-body-ko|zh|ja`, extra line height, a 12px minimum) in the `{{cjk_rules}}` slot; if it is off, delete that line.
- `design/tokens.json`: the chosen direction's values (fill the empty cells of `templates/design/tokens.json`). Light · dark colors, type · spacing · corners · shadows · motion · focus · layout. This is the only file edited by hand.
- Generator: `node <skill-dir>/templates/gates/build-tokens.mjs design/tokens.json --css design/tokens.css [--ts design/theme.ts]` (once stage 4 has copied it to `scripts/`, `node scripts/build-tokens.mjs …`) — `tokens.css` for the web, `theme.ts` for native (Expo) (colors in hex). Components reference only the generated variables · objects.
- Lock gate: run the generator (if even one empty value is left it lists the paths and exits 1 — delete keys you do not use, e.g. `font.body-*` of an unsupported language), and `node <skill-dir>/templates/gates/check-contrast.mjs design/tokens.json design/contrast-pairs.json` green in both themes. Show the output, then ask "Lock these tokens?".
- Contrast · ban checks: copy `design/contrast-pairs.json` (text · background pairs) and `check-contrast.mjs`, the banned-pattern file and `check-banned.sh` into the project and tie them into `{{cmd_check}}` together with the generator's `--check` (`reference/baseline-scaffold.md` gate table).
- Empty kit screen: make only a dev-only screen showing token swatches (color roles · type sizes · motion · focus ring) in both themes. Register each component in the kit as it is built.
- Framework mapping: with Tailwind (v4), reference only the generated variables in the global CSS `@theme inline`, like `--color-<role>: var(--<role>)` (v4 builds opacity modifiers with `color-mix()`). `theme.extend` · `<alpha-value>` in a JS config are the v3 way, and v4 does not read that file without `@config`. CSS-in-JS · vanilla-extract etc. also only reference the variables.

### Filling `DESIGN.md` (`templates/DESIGN.md.tmpl`)

| Placeholder | Value |
|---|---|
| `{{project}}` | Project name |
| `{{direction_name}}` · `{{direction_intent}}` | The chosen direction's name (two words) and one-line intent. If directions were mixed, a new name for the mix |
| `{{tone_3_words}}` | The A-1 answer |
| `{{references_with_why}}` | The A-2 answer (one phrase per site on what is good about it) |
| `{{type_pairing}}` | The A-3 answer (heading · body · number typefaces) |
| `{{neutral_temperature}}` | The A-4 neutral temperature (warm / cool / true gray) |
| `{{density}}` · `{{density_rule}}` | The A-5 answer, and a sentence stating it as a one-screen rule (e.g. "20 table rows and one filter line show without scrolling") |
| `{{button_height}}` · `{{row_height}}` | From density: medium 40px · 48px, medium-high (the default) 36px · 40px, high 32px · 36px. If touch screens are the main use, both 44px or more. Put the same values in `control-h` · `row-h` of `tokens.json` `layout` |
| `{{framework_mapping}}` | From the stack (e.g. Tailwind v4 `@theme inline`; native passes the `theme.ts` object to the theme provider) |
| `{{user_additional_bans}}` | What the user added in A-8. If none, delete that line |
| `{{cjk_rules}}` | The CJK rules of the `DESIGN.md` item above (delete the line if P5 is off) |
