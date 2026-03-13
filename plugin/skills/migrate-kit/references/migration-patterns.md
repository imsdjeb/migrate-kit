# Migration Patterns & Best Practices

## Core Principles

### 1. One Major Version at a Time
Never skip major versions unless the framework explicitly supports it. Each major version may have codemods or migration tools that only work from the previous version.

```
❌ Angular 15 → 19 (skip 3 majors)
✅ Angular 15 → 16 → 17 → 18 → 19 (step by step)
```

Exception: React 16 → 18 is safe because React 17 had no breaking changes (it was a stepping stone release).

### 2. Tests First
Before starting ANY migration:
1. Run the full test suite
2. Record the baseline: X tests passing, Y failing, Z skipped
3. If tests are already failing, document them — don't let migration get blamed for pre-existing issues
4. If no tests exist, consider adding smoke tests for critical paths first

### 3. Branch Strategy
- Create a dedicated migration branch: `migrate/{framework}-{from}-to-{to}`
- One commit per migration step for easy bisection and rollback
- Keep the branch up to date with main to avoid merge hell later
- Don't mix migration changes with feature work

### 4. Config Files First
Always update configuration files before source code:
1. `tsconfig.json` / compiler config
2. `package.json` / `pubspec.yaml` / manifest (dependency versions)
3. Framework config (`angular.json`, `next.config.js`, `vite.config.ts`)
4. Linter/formatter config (`.eslintrc`, `.prettierrc`)
5. CI/CD pipeline config
6. Source code changes last

### 5. Dependency Compatibility Matrix
Before upgrading a framework, check that key dependencies support the target version:
- UI libraries (Material UI, Vuetify, PrimeNG)
- State management (Redux, NgRx, Pinia, Riverpod)
- Testing libraries (Jest, Vitest, Testing Library)
- Auth libraries (NextAuth, Firebase, Auth0 SDK)
- Form libraries (React Hook Form, Formik, Angular Forms)

If a critical dependency doesn't support the target version yet, either:
- Wait for support
- Find an alternative
- Pin the dependency and migrate it separately after

### 6. Rollback Strategy
Always maintain the ability to revert:
- Atomic commits make `git revert` straightforward
- Keep the old code working until the new code is verified
- Don't delete deprecated code paths until the migration is fully validated
- Consider feature flags for gradual rollout in production

---

## Migration Execution Flow

```
┌─────────────────────────────────────┐
│ 1. SCAN                             │
│    Detect framework & version       │
│    Count deprecated APIs            │
│    Assess complexity                │
├─────────────────────────────────────┤
│ 2. PLAN                             │
│    Load breaking changes            │
│    Match to actual codebase usage   │
│    Prioritize (P0 → P3)            │
│    Generate step-by-step plan       │
├─────────────────────────────────────┤
│ 3. RUN (per major version)          │
│    ┌──────────────────────────────┐ │
│    │ a. Create branch             │ │
│    │ b. Update configs            │ │
│    │ c. Update dependencies       │ │
│    │ d. Run codemods              │ │
│    │ e. Manual code fixes         │ │
│    │ f. Build → fix → repeat      │ │
│    │ g. Run tests                 │ │
│    │ h. Commit                    │ │
│    └──────────────────────────────┘ │
│    Repeat for each major version    │
├─────────────────────────────────────┤
│ 4. VERIFY                           │
│    Full build                       │
│    Full test suite                  │
│    Deprecated API scan              │
│    Before/after comparison          │
└─────────────────────────────────────┘
```

---

## Common Pitfalls

### TypeScript Version Coupling
Most frontend frameworks are tightly coupled to specific TypeScript versions:
- Angular 17 requires TS 5.2.x
- Angular 18 requires TS 5.4.x
- Always update TypeScript as part of the framework migration, not separately

### Peer Dependency Conflicts
After updating the framework, `npm install` may fail due to peer dependency conflicts. Resolution:
1. Try `npm install --legacy-peer-deps` to identify which packages conflict
2. Update conflicting packages first
3. As a last resort, use `overrides` in package.json (npm) or `resolutions` (yarn)

### CSS/Styling Breakage
Framework upgrades (especially Material/component libraries) often change styling:
- Run the app visually, not just the tests
- Check spacing, colors, fonts, shadows
- Material 2 → Material 3 changes are significant (Angular, Flutter)

### Runtime vs Build-time Errors
Some deprecations only manifest at runtime:
- Build passes but the app crashes or behaves differently
- Especially true for: routing changes, state management, API changes
- Always do manual smoke testing after migration

### Lock File Conflicts
- Delete `node_modules` and lock file, then reinstall after updating package.json
- Or use `npm install` / `yarn install` to update the lock file
- Don't manually edit lock files

---

## CI/CD Considerations

When migrating, also update:
- **Node.js version** in CI config (if the framework requires a newer version)
- **Docker base images** (if applicable)
- **Build commands** (may change between framework versions)
- **Environment variables** (some frameworks rename them, e.g., `REACT_APP_*` → `VITE_*`)
- **Deployment config** (Vercel, Netlify, AWS — may need framework version hints)
- **Browser targets** in browserslist (if the framework dropped old browser support)
