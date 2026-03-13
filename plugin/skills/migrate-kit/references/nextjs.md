# Next.js Migration Reference

## Next.js 12 → 13

### Breaking Changes
- **App Router** introduced alongside Pages Router. Not required to adopt immediately.
- **`next/image`** — the old `next/image` moved to `next/legacy/image`. The new `next/image` has:
  ```tsx
  // Before (v12)
  <Image src="/img.png" width={200} height={200} layout="responsive" />

  // After (v13)
  <Image src="/img.png" width={200} height={200} style={{ width: '100%', height: 'auto' }} />
  ```
  - `layout` prop removed — use `style` or `className`
  - `objectFit` prop removed — use `style={{ objectFit: 'cover' }}`
  - Wrapper `<span>` removed — `<img>` is rendered directly
- **`next/link`** — no longer requires a child `<a>` tag:
  ```tsx
  // Before
  <Link href="/about"><a>About</a></Link>

  // After
  <Link href="/about">About</Link>
  ```
- **Minimum Node.js: 14.18** (v12 dropped)
- **SWC** replaces Babel by default for compilation.
- **Turbopack** introduced (alpha) as a webpack replacement.

### Codemods
```bash
npx @next/codemod new-link .       # remove <a> from Link
npx @next/codemod next-image-to-legacy-image .  # rename old image imports
npx @next/codemod next-image-experimental .      # adopt new image
```

---

## Next.js 13 → 14

### Breaking Changes
- **Node.js 16 dropped** — minimum is now 18.17.
- **Server Actions** become stable (were alpha in 13.4).
  ```tsx
  // app/page.tsx
  async function submitForm(formData: FormData) {
    'use server';
    const name = formData.get('name');
    await saveToDb(name);
  }
  ```
- **`next export`** removed — use `output: 'export'` in `next.config.js`.
- **Partial Prerendering** introduced (experimental).
- **Metadata API** improvements — `viewport` and `generateViewport` separated from `metadata`.
  ```tsx
  // Before (v13)
  export const metadata = {
    title: 'My App',
    viewport: { width: 'device-width', initialScale: 1 }
  };

  // After (v14)
  export const metadata = { title: 'My App' };
  export const viewport = { width: 'device-width', initialScale: 1 };
  ```
- **`cookies()`** and **`headers()`** — now async in some contexts.

### Codemods
```bash
npx @next/codemod@latest upgrade 14
```

---

## Next.js 14 → 15

### Breaking Changes
- **React 19** support (and required for some features).
- **Async Request APIs** — `cookies()`, `headers()`, `params`, `searchParams` are now async:
  ```tsx
  // Before (v14)
  export default function Page({ params }: { params: { id: string } }) {
    const id = params.id;
  }

  // After (v15)
  export default async function Page({ params }: { params: Promise<{ id: string }> }) {
    const { id } = await params;
  }
  ```
  Same for `cookies()` and `headers()`:
  ```tsx
  // Before
  const cookieStore = cookies();
  const theme = cookieStore.get('theme');

  // After
  const cookieStore = await cookies();
  const theme = cookieStore.get('theme');
  ```
- **Caching behavior changed:**
  - `fetch` requests are no longer cached by default (were cached in v14)
  - Route Handlers (`GET`) are no longer cached by default
  - Client Router Cache no longer caches page components by default
  - Use `force-cache` or `revalidate` explicitly if you want caching
- **Turbopack** stable for dev (`next dev --turbopack`).
- **`next/form`** — new `<Form>` component for progressive enhancement.
- **`instrumentation.ts`** — stable (was experimental).
- **`next.config.ts`** — TypeScript config supported natively.
- **Static Indicator** — visual indicator in dev for static routes.

### Codemods
```bash
npx @next/codemod@latest upgrade 15
```

### Deps to Update
- `react`: 19.x
- `react-dom`: 19.x
- `@types/react`: 19.x
- `@types/react-dom`: 19.x
- `eslint-config-next`: 15.x

### Gotchas
- The async request APIs change is the most impactful — every page/layout using `params`, `searchParams`, `cookies()`, or `headers()` needs updating
- Caching default change can cause performance regression if you relied on implicit caching — audit your `fetch` calls
- Third-party middleware may not support the async APIs yet
- If using `next-auth`: v5 (Auth.js) recommended for Next.js 15

---

## Next.js 15 → 16

### Breaking Changes
- **Async Request APIs fully enforced** — Synchronous access to `cookies()`, `headers()`, `params`, `searchParams` is completely removed (was deprecated in v15, now errors). Every usage must be `await`-ed.
- **Turbopack is the default bundler** — Webpack is no longer the default. If you have custom Webpack config in `next.config.js`, Turbopack will **ignore it entirely**. You must either:
  - Migrate webpack config to Turbopack equivalents
  - Or explicitly opt out: `next dev --bundler webpack`
- **Middleware renamed to Proxy** — The `middleware.ts` file is deprecated. Rename to `proxy.ts` and the `middleware` export to `proxy`:
  ```typescript
  // Before (v15): middleware.ts
  export function middleware(request: NextRequest) { ... }

  // After (v16): proxy.ts
  export function proxy(request: NextRequest) { ... }
  ```
- **Caching is fully opt-in** — All dynamic code executes at request time by default. Use Cache Components for explicit caching:
  ```tsx
  import { cache } from 'react';
  const getData = cache(async () => {
    return await db.query('...');
  });
  ```
- **`next/image` improvements** — No longer requires `width` and `height` for remote images. Better defaults.
- **Parallel Routes** — All slots now require explicit `default.js` files.
- **Removed features:**
  - AMP support (fully removed)
  - `next lint` command (use ESLint directly)
  - Runtime configs (use `.env` files instead)
- **Node.js 18 dropped** — Minimum Node.js 20.9+.

### Codemods
```bash
npx @next/codemod@canary upgrade latest
```

### Deps to Update
- Node.js: 20.9+ (18 dropped)
- `react`: 19.x
- `eslint-config-next`: 16.x
- TypeScript: 5.1.0+

### Gotchas
- Turbopack as default is the most disruptive change — audit any custom webpack config
- The middleware→proxy rename affects every project with middleware
- If you relied on implicit caching from v14, v16 makes the explicit-only model from v15 even stricter
- Check all parallel route directories for `default.js` files

---

## Pages Router → App Router Migration

This is a gradual migration. Both routers work simultaneously.

### Key Differences

| Feature | Pages Router | App Router |
|---------|-------------|------------|
| File convention | `pages/about.tsx` | `app/about/page.tsx` |
| Layouts | `_app.tsx`, `_document.tsx` | `layout.tsx` (nested) |
| Data fetching | `getServerSideProps`, `getStaticProps` | Server Components, `fetch` |
| API routes | `pages/api/route.ts` | `app/api/route.ts` (Route Handlers) |
| Loading | custom | `loading.tsx` |
| Error | `_error.tsx` | `error.tsx` (per-route) |
| Default rendering | Client | Server (RSC) |

### Migration Steps

1. Create `app/layout.tsx` (replaces `_app.tsx` + `_document.tsx`):
   ```tsx
   export default function RootLayout({ children }: { children: React.ReactNode }) {
     return (
       <html lang="en">
         <body>{children}</body>
       </html>
     );
   }
   ```

2. Migrate pages one at a time — both `pages/` and `app/` work together.

3. Convert data fetching:
   ```tsx
   // Before (Pages Router)
   export async function getServerSideProps() {
     const data = await fetchData();
     return { props: { data } };
   }
   export default function Page({ data }) { ... }

   // After (App Router - Server Component)
   export default async function Page() {
     const data = await fetchData();
     return <div>{data}</div>;
   }
   ```

4. Convert API routes:
   ```typescript
   // Before: pages/api/users.ts
   export default function handler(req, res) {
     res.json({ users: [] });
   }

   // After: app/api/users/route.ts
   export async function GET() {
     return Response.json({ users: [] });
   }
   ```

5. Client components need the `'use client'` directive:
   ```tsx
   'use client';
   import { useState } from 'react';
   export default function Counter() {
     const [count, setCount] = useState(0);
     return <button onClick={() => setCount(count + 1)}>{count}</button>;
   }
   ```
