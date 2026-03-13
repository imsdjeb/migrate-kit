# 🔄 migrate-kit

**Stop dreading framework upgrades.**

Scan your project → Generate a migration plan → Run codemods → Verify the result. Four commands, zero guesswork.

---

## Why migrate-kit?

Framework migrations are the #1 task developers postpone. It's risky, tedious, and every framework has its own upgrade quirks — deprecated APIs that silently break at runtime, peer dependency conflicts, config file changes buried in changelogs.

I got tired of spending a full day reading release notes and manually hunting for breaking changes. migrate-kit does that for you: it detects your stack, knows the breaking changes for each version, generates a step-by-step plan with real code examples, runs the codemods, and verifies everything builds and passes tests.

It migrates one major version at a time with atomic commits, so you can always roll back to a known-good state.

---

## Install

```bash
# Add the marketplace (one-time)
claude plugin marketplace add imsdjeb/migrate-kit

# Install the plugin
claude plugin install migrate-kit@imsdjeb-migrate-kit
```

---

## Commands

| Command | What it does |
|---------|-------------|
| `/migrate-kit:scan` | Detect framework & version, find deprecated APIs, assess complexity |
| `/migrate-kit:plan` | Generate a prioritized migration plan with code examples and risk levels |
| `/migrate-kit:run` | Execute the migration — codemods, dep updates, code fixes, atomic commits |
| `/migrate-kit:verify` | Verify the result — build, tests, remaining deprecated APIs |
| `/migrate-kit:deps` | Analyze all dependencies — versions, compatibility, health, update order |

---

## Quick Start

**1. Scan** — Run `/migrate-kit:scan` (or just say "upgrade my Angular project"). The plugin detects your framework, version, and scans for deprecated API usage.

**2. Plan** — Run `/migrate-kit:plan` to get a step-by-step migration plan. Each step has priority (P0–P3), code examples (before → after), affected files, and risk level. Save it as `MIGRATION_PLAN.md`.

**3. Run** — Run `/migrate-kit:run all` to execute the full plan, or `/migrate-kit:run 3` for a specific step. The plugin creates a migration branch, applies changes, verifies builds between steps, and commits atomically.

**4. Verify** — Run `/migrate-kit:verify` to check build status, test results, and remaining deprecated APIs. Get a clear pass/fail report.

---

## Supported Frameworks

| Framework | Versions | Key Migrations |
|-----------|----------|---------------|
| Angular | 14 → 19 | Standalone, Signals, Control Flow, Zoneless |
| React | 16 → 19 | Hooks, createRoot, Compiler, Server Components |
| Vue | 2 → 3.5 | Composition API, Pinia, script setup |
| Next.js | 12 → 15 | App Router, Server Components, Async APIs |
| Flutter | 3.x + Dart 2→3 | Null Safety, Material 3, Impeller |
| Django | 3.2 → 5.1 | Async views, STORAGES, db_default |
| Svelte | 3 → 5 | Runes, SvelteKit |
| NestJS | 8 → 10 | Module changes |

Also handles lateral migrations: CRA → Vite, Pages Router → App Router, Options API → Composition API, Vuex → Pinia, class components → hooks.

---

## How It Works

```
SCAN ──→ PLAN ──→ RUN ──→ VERIFY
  │        │        │        │
  │        │        │        └─ Build + tests + deprecated API scan
  │        │        └─ Codemods + fixes + atomic commits
  │        └─ Breaking changes matched to YOUR code
  └─ Framework detection + deprecated API grep
```

Each phase builds on the previous one. You can run them independently or let them chain automatically.

For multi-major migrations (e.g., Angular 16 → 19), the plugin migrates one version at a time: 16 → 17 → 18 → 19, verifying the build between each step. This is the safest approach and matches what framework maintainers recommend.

---

## Smart Features

- **Step-by-step migration** — one major version at a time, never skips
- **Atomic commits** — one commit per step, easy to bisect and rollback
- **Build verification** — checks the build after every step, not just at the end
- **Deprecated API detection** — greps for known deprecated patterns in your actual code
- **Codemod integration** — runs `ng update`, `npx @next/codemod`, `npx react-codemod`, `dart fix` when available
- **Dependency health check** — identifies abandoned packages and suggests alternatives
- **Risk assessment** — P0 (blocking) through P3 (optional) for every change
- **Migration branch** — all changes on a dedicated branch, main stays clean
- **Diff preview** — shows changes before applying risky modifications

---

## Natural Language

You don't need slash commands. Just ask:

- *"Upgrade this project to Angular 19"*
- *"What would it take to migrate to React 19?"*
- *"Update all my dependencies"*
- *"Are there any deprecated APIs in my code?"*
- *"Migrate from Pages Router to App Router"*
- *"Upgrade Flutter to the latest version"*

---

## Configuration (Optional)

Create `.migrate-kit.json` at your project root to customize behavior:

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

All fields are optional — defaults work for most projects.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on adding framework support, updating breaking change references, and contributing custom codemods.

---

## License

[MIT](LICENSE)
