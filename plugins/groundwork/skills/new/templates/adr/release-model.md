# NNNN — Release model
Status: proposed <!-- on approval, change it to `approved (YYYY-MM-DD)` -->
Date: YYYY-MM-DD

## Context
A setup where a push to main soon becomes production, deploy workflows that run independently of each other, and destructive migrations applied before the code lead to incidents. Before the first deploy, settle what deploys automatically, what ships as a fixed tag, and what the deploy order is.

## Decision
- **Automatic deploy:** {{auto_deploy}} (recommended: only main → staging deploys automatically).
- **Fixed-tag deploy:** {{tag_deploy}} (recommended: prod ships the same build checked on staging as an immutable tag. Build one image and promote it between environments; environment values are injected at run time).
- Before a deploy, CI's required checks (lint · types · tests) must pass. Deploy workflows do not run independently of CI, and deploys to the same target environment run only one at a time.
- **A person starts prod.** A prod deploy runs only from a tag a person made or from a manual run. Add required approvers on the GitHub deploy environment when the plan supports it (GitHub docs 2026-10-31: Free · Pro · Team for public repos only, private repos need Enterprise — check the docs again when deciding). If it is not supported, put it in ② of `docs/runbooks/security-levels.md` (recommended default).
- **CI → cloud credentials.** CI gets the credentials that reach the cloud as short-lived credentials (OIDC, etc.) instead of long-lived keys, with the trust condition narrowed to this repo · this deploy environment. If the platform cannot, keep the long-lived key only as that environment's secret with minimal permissions, and put "switch to short-lived credentials" in the hardening table (recommended default).
- **(container image) Digest promotion.** prod ships the same image checked on staging, by digest (`@sha256:`) (recommended default). Keep this line only in projects that deploy as container images.
- **Protect main.** Turn on no force push · deletion on the main branch from the start (branch protection: every plan for public repos, Pro · Team or higher for private repos — GitHub docs 2026-10-31). If it cannot be turned on, put it in the people · accounts list and the hardening table. Required PR review is turned on at security checkpoint 5 (when people are added) (recommended default).
- **Migrations go expand → contract.** First ship a change both the old and the new code can read (adding a column, etc.), deploy the code, then remove the old part in the next release. A push alone never applies a destructive migration.
- **Deploy order:** {{deploy_order}} (recommended: DB expand → server → client → contract. The order between services goes on this line).
- Front-end static assets keep the previous build's assets, or use a CDN · asset prefix approach, so old pages do not break while deploys overlap: {{asset_strategy}}.
- Dev DB policy (one of shared staging, branch DB, local container) and forbidden actions (reset · repair, etc.): {{dev_db_policy}}.
- (native app) Old versions live for months. Settle the API backward-compatibility rules, the minimum supported version and forced updates, and the API version rules together with ADR `mobile-release`. Keep this section only in projects with a native app on.
- (webview shell app) Settle the contract between the shell and the web (bridge version). The web goes live at once; the shell takes the store path. Keep this section only in projects with a webview shell on.

## Alternatives
- main = prod, simple continuous deploy: fast, but prod changes without checks.
- A separate build per environment: what was checked and what is deployed can differ.
- Apply migrations together with the code at once: there is a moment that cannot be rolled back.

## Consequences
- Shipping to prod takes one more step: making a tag.
- A schema change is split over two releases.
- The deploy order stays written down and is referred to when a new service is added.

## How to verify
- Confirm that a push to main from a temporary branch does not change prod.
- Confirm from the workflow definitions that contract migrations are not applied before the code deploy.
- (container image) Compare that the image digest checked on staging with the same tag equals the prod image digest. Keep this line only in projects that deploy as container images.
- In the live config check of security checkpoint 1, actually look at the CI trust condition · how prod is started · branch protection (`/groundwork:new` does not make deploy workflows, so there is no gate — the standard is the section 7 checklist of `docs/runbooks/release.md`). Shipping · checking · rolling back follow that runbook.
