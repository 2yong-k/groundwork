# Store release runbook
Status: draft
Date: YYYY-MM-DD

The procedure for shipping a native app to Google Play and the App Store. The app identifier · signing · version rules are set by ADR `mobile-release`. This document is the order that carries out that decision. **Never write credential values.**

- Steps are split into `[you]` · `[agent]` (the agent does no push · prod commands · secret writes, only read checks, in-repo edits and gates) and written as "command → expected output". If the output differs, stop instead of going to the next step. An irreversible step says so and carries 'when not to use it', and the end has a rollback table and 'do not do'.

## Environments and identifiers
| Environment | iOS bundle id | Android package | EAS profile | Distribution target |
|---|---|---|---|---|
| dev | {{bundle_id_dev}} | {{package_dev}} | development | Internal devices |
| staging | {{bundle_id_stg}} | {{package_stg}} | preview | Internal distribution (EAS install link, registered devices only on iOS) |
| production | {{bundle_id_prod}} | {{package_prod}} | production | Public in the stores |

## Pre-release checks
1. Confirm the minimum supported version and the server API compatibility: {{min_supported_version_rule}}.
2. Bump the display version (semver). EAS bumps the build number automatically.
3. Store policy check: in-app account deletion · Sign in with Apple if there is external social login · in-app purchase for digital goods payments · privacy labels (App Store privacy, Play data safety) up to date.
4. Store asset check: icons · screenshots · descriptions · release notes.
5. Confirm that no secret value went into the app bundle.
6. (user-money actions) If the build opens real money, finish turning OTA off or code signing in 'OTA updates' below, and change the OTA line of ② in `docs/runbooks/security-levels.md` to `done`. Keep this line only in apps with user-money actions.
7. Before the first Play release, finish a closed test in which 12 testers took part continuously for 14 days, then apply for production access. Keep this line only in personal Play accounts created after 2023-11-13.

## Build and submit
1. Build with `pnpm exec eas build --profile production --platform all` (the CI `eas-build` job makes preview only).
2. Upload with `pnpm exec eas submit --platform all --latest`. iOS goes into TestFlight, Android into the submit profile's track (default: internal testing), and neither is sent to review yet.
3. Pass device e2e and a manual smoke test in TestFlight internal testing · Play internal testing.
4. In App Store Connect, send that build to review (with a test account and how to check it in the review notes), and on Play promote the same build to the production track. Wait for the review result. If it is rejected, write the reason in the ledger as `DEF-n` or `REQ-n`.
5. After approval, roll out in stages (Play staged rollout · App Store phased release) and watch the crash reports.

## OTA updates (EAS Update)
- Use them only for fixes that change JavaScript · assets alone. A change to native code or permissions needs a store build.
- Runtime version policy: {{runtime_version_policy}}. OTA does not go to an incompatible runtime.
- If something goes wrong, roll back to the previous update: {{ota_rollback_method}}.
- (user-money actions) Before the production build that opens real money (required before checkpoint 3), do one of the two. Keep this line only in apps with user-money actions.
  - Off: `updates.enabled: false` for production only, in `app.config.ts`. That build has no rollback above, so it is fixed with an emergency store build.
  - Code signing (EAS Production plan or higher):
    1. Make the key: `pnpm exec expo-updates codesigning:generate --key-output-directory <path outside the repo> --certificate-output-directory certs --certificate-validity-duration-years 10 --certificate-common-name "<organization name>"`. Commit only the certificate (`certs/certificate.pem`), and keep the private key outside CI.
    2. Put `codeSigningCertificate: "./certs/certificate.pem"` and `codeSigningMetadata: { keyid: "main", alg: "rsa-v1_5-sha256" }` in the production `updates` of `app.config.ts`. Without these values the app does not check signatures.
    3. A person publishes with `pnpm exec eas update --private-key-path <path>`.
    4. Confirm that an internal distribution build with the certificate in it does not apply an update published with the certificate settings removed.
  - Either way, the setting goes into the binary and takes effect from the next store build. Builds shipped before that are pushed out by raising the minimum supported version.

## Forced updates and old versions
Old versions live for months. The server accepts the old API for {{api_compat_window}}. Apps below the minimum supported version show an update notice.

## Incident response
- A serious defect: first use the switch that turns the feature off on the server. Then ship an OTA rollback (none if OTA is off) or an emergency build.
- Old binaries already installed stay on devices. If a staged rollout is in progress, halt it, and ship the fixed version as fast as possible.
- (user-money actions) For an app SDK compromise, turn money actions back on only after the fixed build is out in the stores, the minimum supported version is raised to that build, and the sessions of the affected users are invalidated. Keep this line only in apps with user-money actions.

## Accounts and key storage
- The owner and admin of the Apple Developer · Play Console accounts: {{store_account_owner}}.
- The Android upload key backup location and owner: {{upload_key_backup_location}}.
- Push keys (APNs · FCM) sit behind the server, split per environment.
