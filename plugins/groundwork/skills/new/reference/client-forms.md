# Client form — not only the web

At the very start of the stage 2 'Stack' group, ask the **client form**: web · web app (PWA) · native app · webview shell app (the web inside an app) · several. Pick the recommendation from the stage 1 users and scenarios. The answer changes what follows below. The other lessons (baseline · modules) are the same whatever the form.

## A. Differences per form

| Topic | Web · PWA | Native app | Webview shell |
|---|---|---|---|
| Design token source | One platform-neutral `design/tokens.json` → generates CSS variables | The same `tokens.json` → generates the app theme object | The same source as the web; the app shell colors (status bar · splash) come from it too |
| Contrast check | Reads `tokens.json` (the same script whatever the form) | Same | Same |
| Component kit | A dev-only route | A screen only in dev builds | The web kit route |
| Text size | rem · minimum-size rule | Follows system text scaling (Dynamic Type etc.) and keeps the minimum | Web rules + pass the app's text scaling setting through |
| i18n | Path-based URLs · hreflang (P5) | Language resource files + deep-link rules, no URL strategy | The web URL strategy + a rule that passes the app language to the web |
| Release (B7) | Deploy = live at once | **Old versions live on for months** → decide up front the API backward-compatibility and versioning rules, the minimum supported version and forced update, and the store review · OTA path | The web at once, the shell through the store — set the contract between shell and web (bridge version) |
| Security (B2 · P3) | CSP baseline: as static headers `object-src 'none'` · `base-uri 'self'` · `frame-ancestors 'none'` · `form-action 'self'`, scripts only from your own origin and named places (inline that the framework requires is allowed; no host wildcards · `'unsafe-eval'` in prod). External scripts are self-hosted or carry an integrity hash (SRI). Put it on every web app — admin, docs and so on, not just the user app (even with zero external scripts the npm supply-chain path remains). Login session tokens go in httpOnly · Secure · SameSite cookies so JS cannot read them (if the auth provider supports it; if not, the hardening table). A user-money front end uses nonce + `'strict-dynamic'` and takes CSP violation reports (`report-to`) at an app endpoint to alert on hosts never seen before (B11 signal 7; how, per the framework docs of the day) — other web apps put the nonce in the hardening table (checkpoint 2). Values sent to the browser (server component props · values injected at run time included) are public — calls that need a key go through the server, and modules that read secrets are marked `server-only` (`reference/baseline-scaffold.md` 'Config module') | No secret values in the app bundle (every key behind the server); on-device storage uses secure storage. A user-money app cuts the external SDKs it ships to the list in ADR `money-keys` (P9, no CSP) | Bridge allowlist, load only your own origin, file access off, external links open in the system browser |
| Observability (B6) | Client error reporting | Crash reporting + app version · device info | Both |
| e2e | Playwright | Device e2e (e.g. Maestro/Detox — the builder picks) | Playwright + a shell smoke test |

- With a native app, the B7 question gains "minimum supported version · forced update · API version rules", and ADR `release-model` gains that section.
- With a webview shell, P3 gains a "bridge security" question.
- With several forms, apply the column above for each form.

## B. Native app defaults

One row of the stack defaults table: `Native app | Expo · React Native · TypeScript strict · pnpm · Biome · EAS Build/Submit/Update · device e2e`

Start **on the premise of shipping to Google Play · the Apple App Store from day one**. What the store premise makes you decide up front (things that become a migration if changed later):

- **App identifiers** — the iOS bundle id · Android package name cannot change after release. Split the per-environment variants (dev · staging · prod) into distinct identifiers from the start (the same principle as B1: installed side by side on one device, keys · push · deep links per environment too).
- **Signing · credentials** — EAS-managed credentials by default; write down where the Android upload key backup lives and who owns it. Store accounts (Apple Developer · Play Console) are organization-owned if there is a company (a D-U-N-S number is needed). With no company they are personal accounts — a personal Play account (created after 2023-11-13) must run a closed test with 12 testers taking part for 14 days in a row before its first release, so put that period in the plan.
- **Versions** — display version (semver) and auto-incremented build numbers, the OTA (EAS Update) runtime version policy, the minimum supported OS version.
- **Where store policy changes the design** — in-app account deletion (required if accounts can be created), Sign in with Apple if you add third-party social login, in-app purchase rules for digital goods (asked together with P1), a draft privacy label (App Store privacy · Play data safety).
- **Links · notifications** — universal links · app links (need the web domain association file), push (APNs · FCM keys behind the server, per environment).
- **Store assets** — make the icon · screenshots · description from the brand asset set of design stage 3.

These items go into ADR `mobile-release` (with B7, `templates/adr/mobile-release.md`) and `docs/runbooks/store-release.md` (`templates/docs/runbook-store-release.md`).

## C. Scaffold outputs per form (stage 4)

| Form | What gets made |
|---|---|
| Web · PWA | `design/tokens.json` (the values locked in stage 3) → **generate `design/tokens.css`** with `node scripts/build-tokens.mjs design/tokens.json --css design/tokens.css`. A dev-only kit route. CSP header setup + 1 test (the main page response has a CSP header holding the four directives of the section A security row and no `'unsafe-eval'`; for a user-money front end the script directive has a nonce and `'strict-dynamic'` and no `unsafe-inline`). The accessibility check `e2e/a11y.spec.ts` (below). |
| Native app | The same `tokens.json` → **generate `design/theme.ts`** with `node scripts/build-tokens.mjs design/tokens.json --css design/tokens.css --ts design/theme.ts` (colors become hex, fonts the first name of the stack, times ms numbers, so RN can read them). `app.config.ts`, `eas.json`, the slot for the EAS build job in CI, a kit screen only in dev builds. |
| Webview shell | All the web outputs + of the native outputs above `app.config.ts` · `eas.json` · `theme.ts` (status bar · splash colors) · the EAS build job slot in CI · ADR `mobile-release` · `docs/runbooks/store-release.md`. A bridge allowlist file. |

- **`app.config.ts`** — picks the per-environment identifier by `APP_ENV` (`development` · `staging` · `production`). Identifier rule: `com.<org>.<app>.dev` · `com.<org>.<app>.staging` · no suffix = prod (both the iOS bundle id and the Android package name). App name · scheme · push key slots are split per environment too.
- **`eas.json`** — three build profiles: `development` (dev client, internal distribution) · `preview` (staging identifier, internal distribution) · `production` (prod identifier, store submission, auto-incremented build number). Each profile sets `APP_ENV`.
- **`e2e/a11y.spec.ts`** (web · PWA · webview shell) — checks axe's WCAG rules and the Tab focus ring on every screen. Native keeps only the written rules (`DESIGN.md` accessibility).
  - Install: `@playwright/test` · `@axe-core/playwright` as exact-version devDependencies, the browser with `pnpm exec playwright install chromium`.
  - Copy `templates/gates/a11y.spec.ts` and fit it to the project line width with `pnpm exec biome check --write e2e/`. `ROUTES` starts with `/` and grows with every screen you build. The kit screen may be left out of builds, so it is not listed.
  - `playwright.config.ts`: `testDir: "e2e"`, start the built app with `webServer`. Script `pnpm e2e` = build, then `playwright test`. CI has no secrets either, so put local values for the env values it needs in the script.
  - Port: set the `webServer` and `baseURL` port from `E2E_PORT` (if unset, an e2e-only port different from the dev port, e.g. 3100 when dev is 3000), and give `webServer` `reuseExistingServer: !process.env.CI` and an `env` that turns test mode on (the test guard of `reference/baseline-scaffold.md` 'Config module'). The only server a local `pnpm e2e` reuses is one e2e started — the dev server can point at the staging DB and register jobs. The merge check (`trunk.sh merge`) calls it with `CI=1` and `E2E_PORT` set to a free port, so it does not reuse a running dev server (old code from the main checkout).
  - Not tied into `{{cmd_check}}` (it needs a browser). Keep the unit test runner from picking up `e2e/` — Vitest's default config runs `*.spec.ts` too and fails.
  - The stage 4 step 9 output shows `pnpm e2e` passing too. Commit `test(e2e): add the accessibility checks`.
- No components before the token lock. Leave the kit screen empty and register each component as it is built.
