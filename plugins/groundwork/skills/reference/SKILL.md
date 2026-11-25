---
name: reference
user-invocable: false
description: Use when a project's CLAUDE.md or spec tells you to read a groundwork module (P1–P9) or groundwork's spec sections. Gives the absolute paths of those files.
---

Read a groundwork module with the Read tool at `${CLAUDE_PLUGIN_ROOT}/skills/new/reference/modules/P<n>.md` (n = 1–9).
Read groundwork's spec sections with the Read tool at `${CLAUDE_PLUGIN_ROOT}/skills/new/templates/spec-sections.md`.
Inside those files, `reference/…`, `templates/…` and `<skill-dir>/…` are under `${CLAUDE_PLUGIN_ROOT}/skills/new/`. Read or copy files from there, but never write that path into a project file: it changes with every plugin update.
