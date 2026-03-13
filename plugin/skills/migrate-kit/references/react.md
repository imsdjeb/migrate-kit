# React Migration Reference

## React 16 → 17

### Breaking Changes
- **Event delegation** moved from `document` to root DOM container. Mostly transparent, but can affect:
  - Manual `document.addEventListener` that relied on React event order
  - Multiple React roots on the same page
- **New JSX Transform** — no need to `import React from 'react'` in every file.
  ```tsx
  // Before (required)
  import React from 'react';
  const App = () => <div />;

  // After (optional)
  const App = () => <div />;
  ```
- **`forwardRef`** behavior unchanged but some edge cases with `React.lazy` fixed.
- **No new features** — v17 is a "stepping stone" release for gradual upgrades.

### Codemods
```bash
# Remove unnecessary React imports (if using new JSX transform)
npx react-codemod update-react-imports
```

### Config Changes
For the new JSX transform, update tsconfig/babel:
```json
// tsconfig.json
{ "compilerOptions": { "jsx": "react-jsx" } }
```

---

## React 17 → 18

### Breaking Changes
- **`ReactDOM.render` → `createRoot`:**
  ```tsx
  // Before
  import ReactDOM from 'react-dom';
  ReactDOM.render(<App />, document.getElementById('root'));

  // After
  import { createRoot } from 'react-dom/client';
  const root = createRoot(document.getElementById('root')!);
  root.render(<App />);
  ```
- **`ReactDOM.hydrate` → `hydrateRoot`:**
  ```tsx
  // Before
  ReactDOM.hydrate(<App />, document.getElementById('root'));

  // After
  import { hydrateRoot } from 'react-dom/client';
  hydrateRoot(document.getElementById('root')!, <App />);
  ```
- **Automatic batching** — state updates in promises, timeouts, and event handlers are now batched. Can cause unexpected behavior if code relied on intermediate renders.
  ```tsx
  // Before React 18: two renders
  setTimeout(() => {
    setCount(c => c + 1);  // render
    setFlag(f => !f);       // render
  }, 0);

  // React 18: one render (batched)
  // Use flushSync() if you need intermediate renders
  ```
- **`useId`** — new hook for generating unique IDs (SSR-safe).
- **Strict Mode** now double-invokes effects in development (mount → unmount → mount) to catch cleanup bugs.
- **`Suspense`** — now works on the server for streaming SSR.

### Codemods
```bash
npx react-codemod update-react-imports    # remove unused React imports
npx react-codemod rename-unsafe-lifecycles # prefix unsafe lifecycle methods
```

### Deps to Update
- `react-dom`: must match `react` version
- `@types/react`: 18.x
- `@types/react-dom`: 18.x
- `react-router-dom`: v6 recommended (v5 still works)
- `react-redux`: 8.x for React 18 support
- Testing: `@testing-library/react` 13+ for `createRoot` support

### Gotchas
- If using enzyme: it does NOT support React 18. Migrate to `@testing-library/react`
- If using react-router v5: it works but `<Suspense>` integration is limited
- Redux: `react-redux` 7.x works but 8.x is recommended for batching

---

## React 18 → 19

### Breaking Changes
- **React Compiler** (formerly React Forget) — auto-memoization, making `useMemo`, `useCallback`, `React.memo` mostly unnecessary.
- **`use()` hook** — read promises and context in render:
  ```tsx
  // Before
  const [data, setData] = useState(null);
  useEffect(() => {
    fetchData().then(setData);
  }, []);

  // After
  const data = use(fetchDataPromise);
  ```
- **`ref` as a prop** — no more `forwardRef`:
  ```tsx
  // Before
  const Input = forwardRef((props, ref) => <input ref={ref} {...props} />);

  // After
  const Input = ({ ref, ...props }) => <input ref={ref} {...props} />;
  ```
- **`ref` cleanup functions:**
  ```tsx
  <div ref={(node) => {
    // setup
    return () => {
      // cleanup (new in v19)
    };
  }} />
  ```
- **Actions** — `useActionState` replaces `useFormState`:
  ```tsx
  // Before (React 18 / react-dom)
  const [state, formAction] = useFormState(action, initialState);

  // After (React 19)
  const [state, formAction, isPending] = useActionState(action, initialState);
  ```
- **`useFormStatus`** — read parent `<form>` status.
- **Server Components** — stable in frameworks that support them (Next.js).
- **`<Context>` as a provider** — no more `<Context.Provider>`:
  ```tsx
  // Before
  <ThemeContext.Provider value={theme}>

  // After
  <ThemeContext value={theme}>
  ```
- **Removed:** `propTypes`, `defaultProps` on function components, `createFactory`, `render` (use `createRoot`), string refs, legacy context.

### Codemods
```bash
npx types-react-codemod preset-19 .  # update @types/react
```

### Deps to Update
- `react-dom`: 19.x
- `@types/react`: 19.x
- `@types/react-dom`: 19.x
- `react-router-dom`: v7 for full v19 support
- `react-redux`: 9.x
- `next`: 15+ for React 19 support

### Gotchas
- `forwardRef` still works but is deprecated — migrate gradually
- Class components still work but don't get Compiler optimizations
- `useMemo`/`useCallback` still work — Compiler just makes them optional
- Third-party libraries may not support v19 immediately — check compatibility
- If using `react-helmet`: switch to `<title>`, `<meta>` in JSX (React 19 hoists them to `<head>`)

---

## CRA → Vite Migration

### Steps
1. Remove `react-scripts` from dependencies
2. Install Vite: `npm install -D vite @vitejs/plugin-react`
3. Create `vite.config.ts`:
   ```typescript
   import { defineConfig } from 'vite';
   import react from '@vitejs/plugin-react';
   export default defineConfig({ plugins: [react()] });
   ```
4. Move `public/index.html` → `index.html` (project root)
5. Add entry point script tag: `<script type="module" src="/src/index.tsx"></script>`
6. Remove `%PUBLIC_URL%` prefixes in index.html
7. Rename `.env` variables: `REACT_APP_*` → `VITE_*`
8. Update code: `process.env.REACT_APP_*` → `import.meta.env.VITE_*`
9. Update `package.json` scripts: `"dev": "vite"`, `"build": "vite build"`
10. Remove `react-app-env.d.ts`, add `vite-env.d.ts`:
    ```typescript
    /// <reference types="vite/client" />
    ```

---

## Class Components → Hooks Migration

### Common Patterns
```tsx
// State
// Before
this.state = { count: 0 };
this.setState({ count: 1 });
// After
const [count, setCount] = useState(0);
setCount(1);

// Lifecycle
// Before
componentDidMount() { fetchData(); }
componentDidUpdate(prevProps) { if (prevProps.id !== this.props.id) fetchData(); }
componentWillUnmount() { cleanup(); }
// After
useEffect(() => { fetchData(); return () => cleanup(); }, [id]);

// Context
// Before
static contextType = MyContext;
render() { const value = this.context; }
// After
const value = useContext(MyContext);

// Refs
// Before
this.inputRef = React.createRef();
// After
const inputRef = useRef(null);
```
