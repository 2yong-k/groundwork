# NNNN — Mobile app release and store premises
Status: proposed <!-- on approval, change it to `approved (YYYY-MM-DD)` -->
Date: YYYY-MM-DD

## Context
A native app starts on the premise that it ships to Google Play and the Apple App Store from the start. Settle up front what cannot change after release (like app identifiers), what is hard to move later (like account ownership), and where store policy changes the design. This ADR is used together with `release-model`.

## Decision
- **App identifiers:** iOS bundle id `{{ios_bundle_id}}`, Android package name `{{android_package}}`. They cannot change after release. Split the per-environment variants dev · staging · prod into different identifiers from the start. They install side by side on the same device, and keys · push · deep links are per environment too.
- **Signing · credentials:** EAS-managed credentials by default. The Android upload key's backup location is {{upload_key_backup}}, its owner {{credential_owner}}. The owner and admin of the store accounts (Apple Developer · Play Console) is {{store_account_owner}} (recommended: **organization-owned** if there is a company).
- **Versions:** the display version is semver, the build number auto-increments. The OTA (EAS Update) runtime version policy is {{runtime_version_policy}} (recommended: bump it when native code changes). The minimum supported OS version is {{min_os}}.
- **(user-money actions) OTA.** Before the production build that opens real money, turn OTA off or put code signing on (ADR `money-keys`). With it off, rollbacks and urgent fixes are store builds. Keep this line only in apps with user-money actions.
- **Minimum supported app version and forced update:** the server sends down the minimum supported version, and below it the app shows an update screen. The API follows {{api_version_rule}} (recommended: keep backward compatibility, since old apps live for months).
- **Where store policy changes the design:**
  - If accounts can be created in the app, in-app **account deletion** is required.
  - If external social login is added, add **Sign in with Apple** too.
  - Payments for digital goods follow the in-app purchase rules (if money changes hands, settle it together with `numbers-and-units`): {{iap_policy}}.
  - Draft the privacy labels (App Store privacy · Play data safety).
- **Device security:** no secret values in the app bundle (every key sits behind the server). Sensitive values such as tokens are stored only in the platform's secure storage (iOS Keychain · Android Keystore, SecureStore in Expo).
- **Links · notifications:** the domains · key locations of universal links · app links (they need an association file on the web domain) and push (APNs · FCM keys behind the server, per environment): {{links_and_push}}.
- **Store assets:** icons · screenshots · descriptions are made from the brand asset set of design stage 3.
- Outputs: `app.config.ts` (per-environment identifiers) · `eas.json` (build profiles dev / preview / production) · the EAS build job in CI · `docs/runbooks/store-release.md`.

## Alternatives
- Ship only a web app (PWA) first and the stores later: the store premises are not reflected in the design, so late identifier · policy changes turn into migration work.
- Start with personal accounts: fast, but the seller name is your own real name, and a personal Play account goes through a closed test before its first release. Moving to an organization goes through an account transfer (D-U-N-S). Keep this line only in projects with organization-owned accounts.

## Consequences
- More items to settle before release, but decisions that are hard to undo after release come earlier.
- Supporting old app versions (API backward compatibility) keeps costing.

## How to verify
- Check that dev · staging · prod builds install side by side on one device.
- Raise the minimum supported version and check that an old build shows the update screen.
- Search the bundle for secret values and confirm there are none.
- Walk through the steps of `docs/runbooks/store-release.md` once and fill in what is missing.

## Exit plan
- When the store accounts or tools (EAS, etc.) must change: {{store_exit_plan}} (recommended: write the ownership transfer procedure and the upload key recovery procedure in `store-release.md`).
- A bad build gets an OTA rollback (an emergency build if OTA is off) or a promotion of the previous build, and if it is serious, raise the minimum supported version.
