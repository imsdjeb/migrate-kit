# Angular Migration Reference

## Angular 14 → 15

### Breaking Changes
- **Standalone components** introduced (opt-in). Not breaking, but the new recommended pattern.
- **`@angular/material`** MDC-based components become the default. Old components moved to `@angular/material/legacy-*`.
  ```typescript
  // Before
  import { MatButtonModule } from '@angular/material/button';
  // After (if using legacy)
  import { MatLegacyButtonModule as MatButtonModule } from '@angular/material/legacy-button';
  ```
- **Router** — `RouterModule.forRoot()` now uses `withHashLocation()` instead of `useHash: true`
- **`providedIn: NgModule`** deprecated. Use `providedIn: 'root'` or component-level providers.

### Codemods
```bash
ng update @angular/core@15 @angular/cli@15
```

### Deps to Update
- TypeScript: 4.8.x → 4.9.x
- rxjs: 7.5+ (no change)
- zone.js: 0.12.x → 0.13.x

---

## Angular 15 → 16

### Breaking Changes
- **Signals** introduced (developer preview). Not breaking yet, but start planning.
- **`DestroyRef`** and `takeUntilDestroyed()` replace manual subscription management.
  ```typescript
  // Before
  private destroy$ = new Subject<void>();
  ngOnDestroy() { this.destroy$.next(); }
  this.obs$.pipe(takeUntil(this.destroy$)).subscribe();

  // After
  private destroyRef = inject(DestroyRef);
  this.obs$.pipe(takeUntilDestroyed(this.destroyRef)).subscribe();
  ```
- **Required inputs:**
  ```typescript
  @Input({ required: true }) title!: string;
  ```
- **`ngOnDestroy`** — now available as an injectable `DestroyRef`.
- **Self-closing tags** in templates now supported: `<my-comp />`
- **CSP** — nonce support for inline styles.

### Codemods
```bash
ng update @angular/core@16 @angular/cli@16
```

### Deps to Update
- TypeScript: 4.9.x → 5.0.x or 5.1.x
- zone.js: 0.13.x → 0.14.x

---

## Angular 16 → 17

### Breaking Changes
- **New control flow syntax** (developer preview → stable):
  ```html
  <!-- Before -->
  <div *ngIf="condition">Content</div>
  <div *ngFor="let item of items">{{ item }}</div>
  <div [ngSwitch]="value">
    <span *ngSwitchCase="'a'">A</span>
  </div>

  <!-- After -->
  @if (condition) { <div>Content</div> }
  @for (item of items; track item.id) { <div>{{ item }}</div> }
  @switch (value) {
    @case ('a') { <span>A</span> }
  }
  ```
- **`@defer` blocks** for lazy loading:
  ```html
  @defer (on viewport) {
    <heavy-component />
  } @placeholder {
    <p>Loading...</p>
  }
  ```
- **View Transitions API** support via `withViewTransitions()`.
- **Signals** become stable.
- **`ApplicationConfig`** replaces `AppModule` for standalone bootstrap.
  ```typescript
  // Before
  @NgModule({ bootstrap: [AppComponent] })
  export class AppModule {}

  // After
  export const appConfig: ApplicationConfig = {
    providers: [provideRouter(routes), provideHttpClient()]
  };
  bootstrapApplication(AppComponent, appConfig);
  ```

### Codemods
```bash
ng update @angular/core@17 @angular/cli@17
# Migrate control flow
ng generate @angular/core:control-flow
```

### Deps to Update
- TypeScript: 5.1.x → 5.2.x
- Node.js: 16 → 18+ (v16 dropped)

---

## Angular 17 → 18

### Breaking Changes
- **Zoneless change detection** (experimental):
  ```typescript
  bootstrapApplication(AppComponent, {
    providers: [provideExperimentalZonelessChangeDetection()]
  });
  ```
- **Signal-based inputs:**
  ```typescript
  // Before
  @Input() name: string = '';

  // After
  name = input<string>('');
  name = input.required<string>();
  ```
- **Signal-based outputs:**
  ```typescript
  // Before
  @Output() clicked = new EventEmitter<void>();

  // After
  clicked = output<void>();
  ```
- **Signal-based queries:**
  ```typescript
  // Before
  @ViewChild('ref') el!: ElementRef;

  // After
  el = viewChild<ElementRef>('ref');
  ```
- **`@angular/material`** — legacy components fully removed. Must use MDC versions.
- **`HttpClientModule`** deprecated → use `provideHttpClient()`.
  ```typescript
  // Before
  imports: [HttpClientModule]

  // After
  providers: [provideHttpClient(withInterceptorsFromDi())]
  ```

### Codemods
```bash
ng update @angular/core@18 @angular/cli@18
```

### Deps to Update
- TypeScript: 5.2.x → 5.4.x
- Node.js: 18.13+ required

---

## Angular 18 → 19

### Breaking Changes
- **Signals** become the primary reactivity model. Most RxJS-based patterns have signal equivalents.
- **`linkedSignal`** for derived state with write-back.
- **`resource()` API** for async data loading with signals.
  ```typescript
  const userId = signal(1);
  const user = resource({
    request: userId,
    loader: ({ request: id }) => fetch(`/api/users/${id}`).then(r => r.json())
  });
  ```
- **Standalone defaults** — `ng generate component` creates standalone by default. `standalone: false` needed for module-based.
- **`@angular/ssr`** — improved SSR with hydration enhancements.
- **Incremental hydration** with `@defer` blocks.
- **Strict standalone enforcement** in some contexts.

### Codemods
```bash
ng update @angular/core@19 @angular/cli@19
```

### Deps to Update
- TypeScript: 5.4.x → 5.5.x+
- Node.js: 18.19+ or 20+
- rxjs: 7.8+ (still supported, but signals are preferred)

### Gotchas
- If using NgModules, `standalone: false` must be explicit in v19
- `@ngrx/store` users: check compatibility with signal-based state
- Zone.js is now optional — test thoroughly if removing it
- Material components may have subtle styling changes between 18 and 19

---

## Angular 19 → 20

### Breaking Changes
- **Build system change** — Default build package changes from `@angular-devkit/build-angular` to `@angular/build`, which does NOT include Karma.
- **Karma deprecated** — `ng test` will fail out of the box. Migrate to Web Test Runner or Vitest:
  ```bash
  ng update @angular/cli@20 --migrate-only
  # Follow prompts to switch test runner
  ```
- **Structural directives deprecated** — `*ngIf`, `*ngFor`, `*ngSwitch` are officially deprecated (still work, but warnings). Migrate to `@if`, `@for`, `@switch`:
  ```bash
  ng generate @angular/core:control-flow
  ```
- **Self-closing tags auto-migration** — `<app-comp></app-comp>` → `<app-comp />` via schematic.
- **`InjectFlags` API removed** — Migration schematic available.
- **Standalone by default** — `ng generate component` creates standalone components. Use `--standalone=false` for NgModule-based.
- **Node.js 18 dropped** — Requires Node.js 20+.
- **TypeScript 5.8** required.
- **Opera browser** no longer officially supported in `browserslist`.

### Codemods
```bash
ng update @angular/core@20 @angular/cli@20
ng generate @angular/core:control-flow  # migrate structural directives
```

### Deps to Update
- TypeScript: 5.5.x → 5.8.x
- Node.js: 20+ (18 dropped)
- Karma → Vitest or Web Test Runner

---

## Angular 20 → 21

### Breaking Changes
- **Zoneless change detection is now the default** — New applications use zoneless change detection automatically. Zone.js is no longer included by default:
  ```typescript
  // If your app still needs Zone.js, explicitly add it:
  bootstrapApplication(AppComponent, {
    providers: [provideZoneChangeDetection()]
  });

  // New default (zoneless):
  bootstrapApplication(AppComponent, {
    providers: [provideExperimentalZonelessChangeDetection()]
  });
  ```
  This is the biggest breaking change — if your app relies on Zone.js side effects (auto change detection on setTimeout, Promise, HTTP calls), you need to either add Zone.js explicitly or migrate to signals.
- **Vitest replaces Karma as default test runner** — Vitest is now stable and the default. Web Test Runner and Jest support planned for removal in v22.
- **`HttpClient` auto-injection** — `HttpClient` is now injected by default in the root injector. No need for `provideHttpClient()` in most cases.
- **`SimpleChanges` generic type** — `SimpleChanges` is now generic, allowing typed `@Input()` change tracking:
  ```typescript
  ngOnChanges(changes: SimpleChanges<MyComponent>) {
    // changes.myInput is now typed
  }
  ```
- **Signal Forms (experimental)** — New reactive forms API based on signals. API may change before stable.

### New Features (non-breaking)
- **Angular Aria** — New UI library for accessible interfaces (alongside Material and CDK).
- **MCP integration** — Official Model Context Protocol support for tooling.

### Codemods
```bash
ng update @angular/core@21 @angular/cli@21
```

### Deps to Update
- TypeScript: 5.8.x → 5.9.x+
- Node.js: 20+
- Zone.js: now optional (remove from polyfills if going zoneless)
- Vitest: included by default for testing

### Gotchas
- The zoneless default is the biggest migration hurdle — test EVERYTHING after removing Zone.js
- If using `@ngrx/store` or other RxJS-heavy state management, verify compatibility with zoneless
- Signal Forms are experimental — don't migrate production forms yet
- If you were on Web Test Runner (from v20 migration), plan to move to Vitest before v22
