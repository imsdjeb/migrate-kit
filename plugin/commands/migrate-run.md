---
description: "Execute the migration plan — update deps, run codemods, fix code, verify builds, commit atomically."
argument-hint: "[step-number or 'all'] e.g. 1 or all"
---

Run the **RUN** phase from the migrate-kit skill. Create a migration branch, execute the plan step by step (or a specific step), run codemods, fix deprecated APIs, verify builds between steps, and create atomic commits.

If no plan exists yet, generate one first. Show diffs before applying risky changes.
