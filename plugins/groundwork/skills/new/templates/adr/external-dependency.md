# NNNN — External dependency: {{dependency_name}}
Status: proposed <!-- on approval, change it to `approved (YYYY-MM-DD)` -->
Date: YYYY-MM-DD

## Context
{{dependency_name}} is an external dependency that can change or disappear, like a payment · chain · auth SDK · data provider. Make one of these documents per dependency (file name `external-<name>`). Put what can change behind one boundary layer and write the exit down in advance.

## Decision
- **Role.** {{dependency_role}}.
- **Boundary.** One port/adapter layer lives in `{{adapter_dir}}`. App code calls only the adapter's neutral interface, and the provider's name does not go into identifiers. Provider-specific values live in one config module.
- **Register.** Add one line to `docs/vendors.md`: key location · expiry · limits · cost · terms and legal restrictions · regional restrictions · end-of-life date · owner. Use separate credentials per environment, and when a key changes, change the local env file and the secret store too.
- **Management.** Provider SDKs and versions are a managed risk. Before writing workaround code, read the provider's source and changelog, and put audits and an update cycle in CI. Include maintenance status in stack decisions.
- **Fallback · kill switch.** {{fallback_and_kill_switch}}.
- **Payment provider key.** Use a restricted key with only the permissions needed, and verify webhook signatures (recommended default). Keep this line only in payment provider dependencies.
- **(auth SDK) Id brand.** The provider subject is a branded type different from the internal user id (even with the same string shape, passing one in the other's place fails to compile), and one place, the adapter, converts between them. What services pass to each other (workers · other repos) is the internal user id. Keep this line only in auth dependencies.

## Alternatives
- Call the SDK directly from app code: replacing it changes every call site.
- Keep only the register, with no adapter: alerts are possible, but the replacement cost stays the same.

## Consequences
- One adapter layer costs upkeep.
- Replacing one provider shrinks to an adapter implementation and a config change.

## How to verify
- Swap the adapter for a fake implementation and check that the app works.
- Check in the periodic review that no register entry is past its expiry date.
- Search for the provider's name with rg and check that it appears nowhere outside the adapter folder.
- Confirm the meaning of the fields the provider gives (closing price · confirmation time, etc.) with real data at boundary times, and add the confirmed meaning to the 'Purpose' cell of that line in the register.

## Exit plan
- Replacement candidate when removing this dependency: {{exit_candidate}}.
- Switch order and data migration method: {{exit_steps}}.
- Signals that start the switch (terms change, cost limit, end-of-life notice): {{exit_triggers}}.
