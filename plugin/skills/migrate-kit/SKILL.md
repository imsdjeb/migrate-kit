---
name: migrate-kit
description: "Automated framework migration assistant. Use this skill whenever the user mentions: upgrading a framework, migrating versions, updating dependencies, breaking changes, deprecation warnings, codemods, version bump, Angular upgrade, React upgrade, Vue migration, Flutter upgrade, Next.js migration, Django upgrade, dependency update, or any task related to moving a project from one version of a framework/library to another. Also triggers on /migrate-kit:* commands."
---

# migrate-kit

Automated framework migration assistant. Works in 4 phases: **SCAN → PLAN → RUN → VERIFY**.

Before any workflow, run `skills/migrate-kit/scripts/detect-stack.sh` from the plugin root to detect the project's stack. Load reference docs from `skills/migrate-kit/references/` as needed — each framework has its own file with real breaking changes and codemods.

## Config: .migrate-kit.json (optional)

```json
{
  "framework": "auto",
  "targetVersion": "latest",
  "stepByStep": true,
  "autoCommit": true,
  "branchPrefix": "migrate/",
  "runTests": true,
  "runBuild": true,
  "exclude": ["**/legacy/**"],
  "customCodemods": []
}
```

If `.migrate-kit.json` exists, load it. Otherwise, use auto-detected defaults.

---

## Phase 1: SCAN

**Trigger:** `/migrate-kit:scan [target-version]` or user asks to upgrade/migrate a framework.

Steps:

1. Run `detect-stack.sh` to identify: framework, current version, related deps, Node/Python/Dart version, package manager.
2. Determine the target version:
   - If the user specified one, use it
   - Otherwise, look up the latest stable via `npm view <pkg> version`, `pip index versions`, `pub outdated`, or web search
3. Calculate the migration gap:
   - Number of major versions to cross
   - List intermediate versions if multi-step is needed (e.g., Angular 16 → 17 → 18 → 19)
   - Load `references/migration-patterns.md` to check if step-by-step is required
4. Scan the codebase for an inventory:
   - Count files by type (components, services, modules, tests, configs)
   - Grep for deprecated API patterns from the framework's reference file
   - Measure project size (files, lines of code)
5. Assess complexity: **Low** (minor version, no breaking changes), **Medium** (1 major, known codemods), **High** (2+ majors or heavy deprecated API usage), **Critical** (fundamental architecture change like Vue 2→3)

Output format:
```
🔍 Migration Scan Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 Current: {framework} {currentVersion}
🎯 Target:  {framework} {targetVersion}
📊 Gap:     {N} major version(s) ({path})

📁 Project Size:
   Components: X  |  Services: Y  |  Modules: Z
   Tests: T       |  Total files: F

⚠️  Deprecated APIs Found:
   • {api_name} ({status}) — {count} usages
   ...

{emoji} Complexity: {level}
   Recommended: {strategy}
   Estimated effort: {estimate}
```

---

## Phase 2: PLAN

**Trigger:** `/migrate-kit:plan [target-version]` or user asks for a migration plan.

Steps:

1. If SCAN hasn't been run yet, run it first.
2. For each intermediate version, load the framework's reference file and identify:
   - **P0 – Blocking:** breaking changes that prevent the build (removed APIs, changed signatures)
   - **P1 – Required:** deprecated APIs that still work but will be removed next version
   - **P2 – Recommended:** new patterns, performance improvements, recommended migrations
   - **P3 – Optional:** nice-to-have refactoring, cosmetic improvements
3. For each migration step, generate:
   - What changes (before → after code examples)
   - Files impacted (list or glob pattern)
   - Whether an automated codemod exists or if it's manual
   - Regression risk (Low/Medium/High)
   - Commands to run (e.g., `ng update @angular/core@18`, `npx react-codemod`)
4. Order steps: config changes first, then deps update, then code changes, then tests.

**Always offer to save the plan as `MIGRATION_PLAN.md` at the project root.**

Output: numbered, step-by-step migration plan with code examples and risk levels.

---

## Phase 3: RUN

**Trigger:** `/migrate-kit:run [step-number or "all"]` or user asks to execute the migration.

Steps:

1. If no plan exists, run PLAN first.
2. Create a git branch: `{branchPrefix}{framework}-{from}-to-{to}` (e.g., `migrate/angular-17-to-18`)
3. For each step in the plan (or the specified step):
   a. Announce the step
   b. Apply changes:
      - Run official codemods if available (`ng update`, `npx @next/codemod`, `npx react-codemod`, `dart fix --apply`)
      - Update dependency versions in package.json/pubspec.yaml/requirements.txt
      - Modify config files (tsconfig, angular.json, next.config, vite.config, etc.)
      - Replace deprecated patterns in source code
      - Update imports
   c. After each step, attempt a build
   d. If build fails → analyze the error, attempt automatic fix, alert user if can't resolve
   e. Atomic commit: `migrate: [step N] {description}`
4. For multi-major migrations (e.g., Angular 17 → 18 → 19):
   - Complete each major version fully before starting the next
   - Verify build between each major version
   - Separate commits per major version

**Rules:**
- Never force a change without showing the diff first if it's P0 or High risk
- If `runTests` is enabled in config, run tests after each major version step
- If a codemod fails, fall back to manual replacement and explain what happened
- Preserve the user's code style (indentation, quotes, semicolons)

---

## Phase 4: VERIFY

**Trigger:** `/migrate-kit:verify` or user asks to verify/check the migration.

Steps:

1. Run the full build command for the framework
2. Run the test suite if available
3. Scan for remaining deprecated APIs (same grep patterns as SCAN)
4. Compare before/after:
   - Build warnings count
   - Test pass/fail count
   - Remaining deprecated API usages
5. Check for common post-migration issues:
   - Peer dependency warnings
   - TypeScript strict mode issues (if TS version changed)
   - CSS/styling breakage indicators
   - Runtime-only deprecations not catchable at build time

Output:
```
✅ Migration Verification
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 {framework} {from} → {to}

Build:      {status} ({errors} errors, {warnings} warnings)
Tests:      {status} ({passed}/{total} passing)
Deprecated: {status} ({remaining} remaining)

📋 Remaining items:
   {list of P2/P3 items still applicable}

{final_emoji} {summary_message}
```

---

## Workflow: DEPS

**Trigger:** `/migrate-kit:deps` or user asks about dependency updates/health.

Steps:

1. Read all dependencies from the project manifest
2. For each dependency, check:
   - Current version vs latest version (via `npm outdated`, `pub outdated`, `pip list --outdated`)
   - Compatibility with the target framework version
   - Whether it has breaking changes (major version bump)
3. Categorize:
   - 🟢 **Safe** — patch/minor update, no breaking changes
   - 🟡 **Review** — minor with notable changelog, or approaching EOL
   - 🔴 **Breaking** — major version bump, requires code changes
   - ⚫ **Abandoned** — no update in 1+ year, look for alternatives
4. Propose an ordered update plan: safe first, then review, then breaking
5. For abandoned packages, suggest actively maintained alternatives

---

## Important Rules

1. **Always migrate one major version at a time.** Never skip majors unless the framework explicitly supports it.
2. **Run detection before anything else.** Never assume the framework or version.
3. **Atomic commits.** One commit per migration step for easy rollback.
4. **Build verification between steps.** Catch issues early, not at the end.
5. **Show diffs for risky changes.** Always preview P0 and High-risk changes before applying.
6. **Preserve existing code style.** Match indentation, quotes, semicolons, trailing commas.
7. **Don't touch what doesn't need to change.** Only modify files affected by the migration.
8. **Test before you start.** If tests fail before migration, flag it — don't blame the migration for pre-existing failures.
