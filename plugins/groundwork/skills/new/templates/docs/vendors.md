# {{project_name}} external dependency register
Status: in use
Date: YYYY-MM-DD

One line per external dependency that can change or disappear (payment · auth · chain · data providers · SDKs · hosting). Each dependency also has its own `docs/adr/NNNN-external-<name>.md`. **Never write values in the key location** — write only the secret store path or the environment variable name.

| Dependency | Purpose | Owner | Key location (no values) | Our permissions · data it holds | Expiry | Limits · cost | Terms | Exit |
|---|---|---|---|---|---|---|---|---|
| {{vendor_name}} | {{purpose}} | {{owner}} | {{secret_store_path_or_env_name}} | {{vendor_holds}} | {{key_expiry}} | {{limit_and_cost}} | {{terms_url_and_restrictions}} | `docs/adr/NNNN-external-{{vendor_name}}.md` |

## Checks
- A line whose expiry comes within 30 days goes into 'Scheduled' of the handoff.
- When a key changes, follow `docs/runbooks/secret-rotation.md` and update the expiry in this table.
- A dependency that uses separate credentials per environment gets one line per environment.
