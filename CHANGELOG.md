# Changelog

## [1.0.0] - 2026-03-13

### Added

- **SCAN phase** — Auto-detect framework and version, find deprecated APIs, assess migration complexity
- **PLAN phase** — Generate prioritized migration plan with code examples, risk levels, and codemods
- **RUN phase** — Execute migrations with atomic commits, build verification, and codemod integration
- **VERIFY phase** — Post-migration verification with build, test, and deprecated API checks
- **DEPS workflow** — Dependency health analysis with version checks, compatibility, and update ordering
- **Stack detection script** for Angular, React, Vue, Next.js, Flutter, Django, Rails, Svelte, NestJS, Express
- **Post-write hook** that warns when framework dependency files are modified
- **Framework references** with real breaking changes:
  - Angular 14 → 19 (standalone, signals, control flow, zoneless)
  - React 16 → 19 (hooks, createRoot, compiler, server components)
  - Vue 2 → 3.5 (composition API, pinia, script setup)
  - Next.js 12 → 15 (app router, server components, async APIs)
  - Flutter 3.x + Dart 2 → 3 (null safety, material 3, impeller)
  - Django 3.2 → 5.1, Flask 2 → 3, FastAPI + Pydantic v2
- **Migration patterns guide** — best practices for safe framework upgrades
- **Lateral migration support** — CRA → Vite, Pages → App Router, Options → Composition API, Vuex → Pinia
