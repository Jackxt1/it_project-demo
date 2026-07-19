# Phase 3 Web Admin/Technician (Next.js) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a single Next.js web app (`web_admin/`) shared by ADMIN/OWNER staff and TECHNICIAN users, backed entirely by the already-merged Phase 3 backend.

**Architecture:** App Router + TypeScript + Tailwind CSS. A same-origin catch-all Route Handler (`/api/[...proxy]`) forwards every REST call to Spring Boot, injecting the JWT from an httpOnly cookie — the browser never sees the token or talks to the backend origin directly (except the WebSocket, which connects straight to the backend's `/ws` SockJS endpoint, matching the existing mobile app's pattern). `middleware.ts` gates routes by role, decoded from the same cookie.

**Tech Stack:** Next.js 14.2.5, React 18.3.1, TypeScript 5.4.5, Tailwind CSS 3.4.4, @stomp/stompjs 7.0.0, sockjs-client 1.6.1, Vitest 1.6.0 for the testable pure-logic units (auth/role-gating, realtime upsert).

## Global Constraints

- Color palette (same as the mobile app): primary `#EE2020`, dark `#B31818`, darker `#8F1313`, light `#FDE9E9`, deep `#530B0B`.
- Session cookie name: `bkk_admin_token` — httpOnly, `secure` in production, `sameSite=lax`, `path=/`, 24h maxAge.
- Client components call the backend only through the same-origin proxy (`/api/**` on the Next.js origin). Never call the Spring Boot origin directly from the browser except the STOMP/WebSocket connection.
- Server-side backend base URL: `BACKEND_URL` env var, default `http://localhost:8080`.
- Browser WebSocket URL: `NEXT_PUBLIC_WS_URL` env var, default `http://localhost:8080/ws`.
- Only `ADMIN`, `OWNER`, and `TECHNICIAN` roles may log into this app — `POST /api/auth/login` proxy route rejects `CUSTOMER` logins with 403 before setting any cookie.
- Route access: `/dashboard/**` and `/staff/**` → `OWNER` only. `/queue/**` → `ADMIN`, `OWNER`, `TECHNICIAN`. Everything else under the authenticated app → `ADMIN`, `OWNER`.
- `BookingStatus` values: `PENDING`, `CONFIRMED`, `IN_PROGRESS`, `COMPLETED`, `CANCELLED`.
- All backend endpoints and DTOs referenced below already exist on `main` (Phase 3 backend, merge commit `a0856fb`) — this plan never modifies backend code.
- JWT claims (set by `AuthService`): `sub` = email, `role` = one of `CUSTOMER`/`ADMIN`/`OWNER`/`TECHNICIAN`, plus standard `exp`/`iat`. The frontend decodes but never verifies the signature client-side — every proxied API call still goes through the backend's own JWT verification, so a tampered cookie simply gets 401'd there.

---

### Task 1: Scaffold, session/access logic (TDD), auth proxy routes, middleware, login page

**Files:**
- Create: `web_admin/package.json`
- Create: `web_admin/tsconfig.json`
- Create: `web_admin/next.config.mjs`
- Create: `web_admin/tailwind.config.ts`
- Create: `web_admin/postcss.config.mjs`
- Create: `web_admin/vitest.config.ts`
- Create: `web_admin/.gitignore`
- Create: `web_admin/.env.local.example`
- Create: `web_admin/app/layout.tsx`
- Create: `web_admin/app/globals.css`
- Create: `web_admin/lib/session.ts`
- Test: `web_admin/lib/session.test.ts`
- Create: `web_admin/lib/backend.ts`
- Create: `web_admin/middleware.ts`
- Create: `web_admin/app/api/auth/login/route.ts`
- Create: `web_admin/app/api/auth/logout/route.ts`
- Create: `web_admin/app/api/[...proxy]/route.ts`
- Create: `web_admin/app/(auth)/login/page.tsx`

**Interfaces:**
- Consumes: `POST /api/auth/login` (backend) → `{token, tokenType, userId, fullName, email, role}`
- Produces: `SESSION_COOKIE` constant, `decodeToken(token): Session | null`, `isSessionValid(session): boolean`, `resolveAccess(pathname, role): boolean`, `BACKEND_URL`, `backendFetch(path, token?, init?): Promise<Response>` — every later task imports these from `@/lib/session` and `@/lib/backend`.

- [ ] **Step 1: Create the project directory and `package.json`**

Run: `mkdir -p "C:\Users\Jack\Desktop\it\web_admin"`

Create `web_admin/package.json`:

```json
{
  "name": "web-admin",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "test": "vitest run"
  },
  "dependencies": {
    "next": "14.2.5",
    "react": "18.3.1",
    "react-dom": "18.3.1"
  },
  "devDependencies": {
    "typescript": "5.4.5",
    "@types/node": "20.14.2",
    "@types/react": "18.3.3",
    "@types/react-dom": "18.3.0",
    "tailwindcss": "3.4.4",
    "postcss": "8.4.38",
    "autoprefixer": "10.4.19",
    "eslint": "8.57.0",
    "eslint-config-next": "14.2.5",
    "vitest": "1.6.0",
    "@vitejs/plugin-react": "4.3.1",
    "jsdom": "24.1.0"
  }
}
```

Run: `cd "C:\Users\Jack\Desktop\it\web_admin" && npm install`
Expected: installs without errors, creates `node_modules/` and `package-lock.json`.

- [ ] **Step 2: Create the remaining config files**

Create `web_admin/tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

Create `web_admin/next.config.mjs`:

```js
/** @type {import('next').NextConfig} */
const nextConfig = {};
export default nextConfig;
```

Create `web_admin/tailwind.config.ts`:

```ts
import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./app/**/*.{ts,tsx}', './components/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        brand: {
          DEFAULT: '#EE2020',
          dark: '#B31818',
          darker: '#8F1313',
          light: '#FDE9E9',
          deep: '#530B0B',
        },
      },
    },
  },
  plugins: [],
};
export default config;
```

Create `web_admin/postcss.config.mjs`:

```js
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
```

Create `web_admin/vitest.config.ts`:

```ts
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, '.'),
    },
  },
});
```

Create `web_admin/.gitignore`:

```
node_modules/
.next/
out/
.env.local
```

Create `web_admin/.env.local.example`:

```
BACKEND_URL=http://localhost:8080
NEXT_PUBLIC_WS_URL=http://localhost:8080/ws
```

- [ ] **Step 3: Root layout and global styles**

Create `web_admin/app/globals.css`:

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  @apply bg-gray-50 text-gray-900;
}
```

Create `web_admin/app/layout.tsx`:

```tsx
import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'BKK Car Glass Admin',
  description: 'ระบบจัดการสำหรับแอดมินและช่าง BKK Car Glass',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="th">
      <body>{children}</body>
    </html>
  );
}
```

- [ ] **Step 4: Write the failing test for session/access logic**

Create `web_admin/lib/session.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { decodeToken, isSessionValid, resolveAccess } from './session';

function makeToken(payload: Record<string, unknown>): string {
  const header = btoa(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const body = btoa(JSON.stringify(payload));
  return `${header}.${body}.fakesignature`;
}

describe('decodeToken', () => {
  it('decodes a valid token payload', () => {
    const token = makeToken({ sub: 'owner@test.com', role: 'OWNER', exp: 9999999999 });
    const session = decodeToken(token);
    expect(session).toEqual({ email: 'owner@test.com', role: 'OWNER', exp: 9999999999 });
  });

  it('returns null for a malformed token', () => {
    expect(decodeToken('not-a-jwt')).toBeNull();
  });

  it('returns null when required claims are missing', () => {
    const token = makeToken({ sub: 'owner@test.com' });
    expect(decodeToken(token)).toBeNull();
  });
});

describe('isSessionValid', () => {
  it('returns false for null session', () => {
    expect(isSessionValid(null)).toBe(false);
  });

  it('returns false for an expired session', () => {
    expect(isSessionValid({ email: 'a@test.com', role: 'ADMIN', exp: 1 })).toBe(false);
  });

  it('returns true for a session that has not expired', () => {
    const future = Math.floor(Date.now() / 1000) + 3600;
    expect(isSessionValid({ email: 'a@test.com', role: 'ADMIN', exp: future })).toBe(true);
  });
});

describe('resolveAccess', () => {
  it('allows only OWNER on /dashboard and /staff', () => {
    expect(resolveAccess('/dashboard', 'OWNER')).toBe(true);
    expect(resolveAccess('/dashboard', 'ADMIN')).toBe(false);
    expect(resolveAccess('/staff/accounts', 'OWNER')).toBe(true);
    expect(resolveAccess('/staff/accounts', 'ADMIN')).toBe(false);
  });

  it('allows ADMIN, OWNER, and TECHNICIAN on /queue', () => {
    expect(resolveAccess('/queue', 'ADMIN')).toBe(true);
    expect(resolveAccess('/queue', 'OWNER')).toBe(true);
    expect(resolveAccess('/queue', 'TECHNICIAN')).toBe(true);
    expect(resolveAccess('/queue', 'CUSTOMER')).toBe(false);
  });

  it('allows only ADMIN and OWNER on other staff routes', () => {
    expect(resolveAccess('/customers', 'ADMIN')).toBe(true);
    expect(resolveAccess('/customers', 'OWNER')).toBe(true);
    expect(resolveAccess('/customers', 'TECHNICIAN')).toBe(false);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "C:\Users\Jack\Desktop\it\web_admin" && npm test`
Expected: FAIL — `Cannot find module './session'` (the module doesn't exist yet).

- [ ] **Step 3: Implement `lib/session.ts`**

Create `web_admin/lib/session.ts`:

```ts
export const SESSION_COOKIE = 'bkk_admin_token';

export type Role = 'CUSTOMER' | 'ADMIN' | 'OWNER' | 'TECHNICIAN';

export interface Session {
  email: string;
  role: Role;
  exp: number;
}

export function decodeToken(token: string): Session | null {
  const parts = token.split('.');
  if (parts.length !== 3) {
    return null;
  }
  try {
    const normalized = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const json = JSON.parse(atob(normalized));
    if (typeof json.sub !== 'string' || typeof json.role !== 'string' || typeof json.exp !== 'number') {
      return null;
    }
    return { email: json.sub, role: json.role as Role, exp: json.exp };
  } catch {
    return null;
  }
}

export function isSessionValid(session: Session | null): session is Session {
  return session !== null && session.exp * 1000 > Date.now();
}

export function canAccessQueue(role: Role): boolean {
  return role === 'ADMIN' || role === 'OWNER' || role === 'TECHNICIAN';
}

export function canAccessStaffArea(role: Role): boolean {
  return role === 'ADMIN' || role === 'OWNER';
}

export function isOwner(role: Role): boolean {
  return role === 'OWNER';
}

export function resolveAccess(pathname: string, role: Role): boolean {
  if (pathname.startsWith('/dashboard') || pathname.startsWith('/staff')) {
    return isOwner(role);
  }
  if (pathname.startsWith('/queue')) {
    return canAccessQueue(role);
  }
  return canAccessStaffArea(role);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "C:\Users\Jack\Desktop\it\web_admin" && npm test`
Expected: PASS — all 10 tests in `session.test.ts` green.

- [ ] **Step 5: Backend fetch helper**

Create `web_admin/lib/backend.ts`:

```ts
export const BACKEND_URL = process.env.BACKEND_URL ?? 'http://localhost:8080';

export async function backendFetch(path: string, token?: string, init?: RequestInit): Promise<Response> {
  const headers = new Headers(init?.headers);
  if (token) {
    headers.set('authorization', `Bearer ${token}`);
  }
  return fetch(`${BACKEND_URL}${path}`, { ...init, headers, cache: 'no-store' });
}
```

- [ ] **Step 6: Middleware**

Create `web_admin/middleware.ts`:

```ts
import { NextRequest, NextResponse } from 'next/server';
import { SESSION_COOKIE, decodeToken, isSessionValid, resolveAccess } from '@/lib/session';

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  const token = request.cookies.get(SESSION_COOKIE)?.value;
  const session = token ? decodeToken(token) : null;

  if (!isSessionValid(session)) {
    const response = NextResponse.redirect(new URL('/login', request.url));
    response.cookies.delete(SESSION_COOKIE);
    return response;
  }

  if (!resolveAccess(pathname, session.role)) {
    return NextResponse.redirect(new URL('/login?error=forbidden', request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|api|login).*)'],
};
```

- [ ] **Step 7: Auth API routes**

Create `web_admin/app/api/auth/login/route.ts`:

```ts
import { NextRequest, NextResponse } from 'next/server';
import { SESSION_COOKIE } from '@/lib/session';
import { backendFetch } from '@/lib/backend';

export async function POST(request: NextRequest) {
  const body = await request.json();

  const backendRes = await backendFetch('/api/auth/login', undefined, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  const data = await backendRes.json();

  if (!backendRes.ok) {
    return NextResponse.json(data, { status: backendRes.status });
  }

  if (data.role !== 'ADMIN' && data.role !== 'OWNER' && data.role !== 'TECHNICIAN') {
    return NextResponse.json({ message: 'บัญชีนี้ไม่มีสิทธิ์เข้าใช้งานระบบนี้' }, { status: 403 });
  }

  const response = NextResponse.json({ fullName: data.fullName, email: data.email, role: data.role });
  response.cookies.set(SESSION_COOKIE, data.token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    path: '/',
    maxAge: 60 * 60 * 24,
  });
  return response;
}
```

Create `web_admin/app/api/auth/logout/route.ts`:

```ts
import { NextResponse } from 'next/server';
import { SESSION_COOKIE } from '@/lib/session';

export async function POST() {
  const response = new NextResponse(null, { status: 204 });
  response.cookies.delete(SESSION_COOKIE);
  return response;
}
```

- [ ] **Step 8: Catch-all API proxy**

Create `web_admin/app/api/[...proxy]/route.ts`:

```ts
import { NextRequest, NextResponse } from 'next/server';
import { SESSION_COOKIE } from '@/lib/session';
import { BACKEND_URL } from '@/lib/backend';

async function proxy(request: NextRequest, params: { proxy: string[] }): Promise<NextResponse> {
  const token = request.cookies.get(SESSION_COOKIE)?.value;
  const path = params.proxy.join('/');
  const url = `${BACKEND_URL}/api/${path}${request.nextUrl.search}`;

  const headers = new Headers();
  const contentType = request.headers.get('content-type');
  if (contentType) {
    headers.set('content-type', contentType);
  }
  if (token) {
    headers.set('authorization', `Bearer ${token}`);
  }

  const hasBody = request.method !== 'GET' && request.method !== 'HEAD';
  const backendRes = await fetch(url, {
    method: request.method,
    headers,
    body: hasBody ? await request.arrayBuffer() : undefined,
  });

  const responseBody = await backendRes.arrayBuffer();
  const responseHeaders = new Headers();
  const resContentType = backendRes.headers.get('content-type');
  if (resContentType) {
    responseHeaders.set('content-type', resContentType);
  }

  return new NextResponse(responseBody, { status: backendRes.status, headers: responseHeaders });
}

export async function GET(request: NextRequest, { params }: { params: { proxy: string[] } }) {
  return proxy(request, params);
}
export async function POST(request: NextRequest, { params }: { params: { proxy: string[] } }) {
  return proxy(request, params);
}
export async function PUT(request: NextRequest, { params }: { params: { proxy: string[] } }) {
  return proxy(request, params);
}
export async function PATCH(request: NextRequest, { params }: { params: { proxy: string[] } }) {
  return proxy(request, params);
}
export async function DELETE(request: NextRequest, { params }: { params: { proxy: string[] } }) {
  return proxy(request, params);
}
```

- [ ] **Step 9: Login page**

Create `web_admin/app/(auth)/login/page.tsx`:

```tsx
'use client';
import { useState, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });
      const data = await res.json();
      if (!res.ok) {
        throw new Error(data.message ?? 'เข้าสู่ระบบไม่สำเร็จ');
      }
      router.push(data.role === 'OWNER' ? '/dashboard' : '/queue');
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'เข้าสู่ระบบไม่สำเร็จ');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-brand-light">
      <form onSubmit={handleSubmit} className="w-full max-w-sm rounded-xl bg-white p-8 shadow-lg">
        <h1 className="mb-6 text-2xl font-bold text-brand-deep">BKK Car Glass — เข้าสู่ระบบ</h1>
        {error && <p className="mb-4 rounded bg-red-50 p-2 text-sm text-brand">{error}</p>}
        <label className="mb-1 block text-sm font-medium text-brand-deep">อีเมล</label>
        <input
          type="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="mb-4 w-full rounded border border-gray-300 px-3 py-2"
        />
        <label className="mb-1 block text-sm font-medium text-brand-deep">รหัสผ่าน</label>
        <input
          type="password"
          required
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="mb-6 w-full rounded border border-gray-300 px-3 py-2"
        />
        <button
          type="submit"
          disabled={loading}
          className="w-full rounded bg-brand py-2 font-semibold text-white hover:bg-brand-dark disabled:opacity-50"
        >
          {loading ? 'กำลังเข้าสู่ระบบ...' : 'เข้าสู่ระบบ'}
        </button>
      </form>
    </div>
  );
}
```

- [ ] **Step 10: Manual verification**

Ensure the backend is running (`cd backend && mvn spring-boot:run`), then:

Run: `cd "C:\Users\Jack\Desktop\it\web_admin" && npm run dev`

- Visit `http://localhost:3000/queue` while logged out → expect redirect to `/login`.
- Visit `http://localhost:3000/login`, log in with a seeded OWNER or ADMIN account (create one via `UPDATE users SET role='OWNER' WHERE email=...` if none exists yet) → expect redirect to `/dashboard` (OWNER) or `/queue` (ADMIN), and a `bkk_admin_token` httpOnly cookie set (visible in DevTools → Application → Cookies, value present but not readable via `document.cookie`).
- Attempt login with a `CUSTOMER` account → expect the 403 Thai error message shown on the form, no cookie set.

- [ ] **Step 11: Commit**

```bash
git add web_admin/package.json web_admin/package-lock.json web_admin/tsconfig.json \
        web_admin/next.config.mjs web_admin/tailwind.config.ts web_admin/postcss.config.mjs \
        web_admin/vitest.config.ts web_admin/.gitignore web_admin/.env.local.example \
        web_admin/app/layout.tsx web_admin/app/globals.css \
        web_admin/lib/session.ts web_admin/lib/session.test.ts web_admin/lib/backend.ts \
        web_admin/middleware.ts web_admin/app/api/auth/login/route.ts \
        web_admin/app/api/auth/logout/route.ts "web_admin/app/api/[...proxy]/route.ts" \
        "web_admin/app/(auth)/login/page.tsx"
git commit -m "$(cat <<'EOF'
feat(web-admin): scaffold Next.js app, auth proxy, role-gating middleware

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Shared API client, types, app shell, queue page (baseline)

**Files:**
- Create: `web_admin/lib/api.ts`
- Create: `web_admin/lib/types.ts`
- Create: `web_admin/components/StatusBadge.tsx`
- Create: `web_admin/components/LogoutButton.tsx`
- Create: `web_admin/components/Sidebar.tsx`
- Create: `web_admin/app/(app)/layout.tsx`
- Create: `web_admin/app/(app)/(staff)/queue/page.tsx`
- Create: `web_admin/app/(app)/(staff)/queue/QueueBoard.tsx`

**Interfaces:**
- Consumes: `SESSION_COOKIE`/`decodeToken`/`isSessionValid`/`Role` (Task 1's `lib/session.ts`), `backendFetch` (Task 1's `lib/backend.ts`)
- Produces: `apiGet/apiPost/apiPut/apiPatch/apiDelete/ApiError` (`lib/api.ts`), all DTO-mirroring TS interfaces (`lib/types.ts`) — every later page task imports these.

- [ ] **Step 1: Client-side API helper**

Create `web_admin/lib/api.ts`:

```ts
export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`/api${path}`, {
    ...init,
    headers: { 'Content-Type': 'application/json', ...(init?.headers ?? {}) },
  });

  if (res.status === 204) {
    return undefined as T;
  }

  const data = await res.json().catch(() => null);
  if (!res.ok) {
    const message = data && typeof data.message === 'string' ? data.message : `Request failed (${res.status})`;
    throw new ApiError(res.status, message);
  }
  return data as T;
}

export const apiGet = <T>(path: string) => request<T>(path);
export const apiPost = <T>(path: string, body: unknown) =>
  request<T>(path, { method: 'POST', body: JSON.stringify(body) });
export const apiPut = <T>(path: string, body: unknown) =>
  request<T>(path, { method: 'PUT', body: JSON.stringify(body) });
export const apiPatch = <T>(path: string, body: unknown) =>
  request<T>(path, { method: 'PATCH', body: JSON.stringify(body) });
export const apiDelete = <T>(path: string) => request<T>(path, { method: 'DELETE' });
```

- [ ] **Step 2: Shared types mirroring backend DTOs**

Create `web_admin/lib/types.ts`:

```ts
export type BookingStatus = 'PENDING' | 'CONFIRMED' | 'IN_PROGRESS' | 'COMPLETED' | 'CANCELLED';

export interface BookingStatusHistory {
  id: number;
  status: string;
  note: string | null;
  changedByName: string | null;
  changedAt: string;
}

export interface Booking {
  id: number;
  userId: number;
  userFullName: string;
  serviceId: number;
  serviceName: string;
  productId: number | null;
  productName: string | null;
  technicianId: number | null;
  technicianName: string | null;
  bookingDate: string;
  timeSlot: string;
  status: BookingStatus;
  budget: number | null;
  imageUrl: string | null;
  quotePrice: number | null;
  notes: string | null;
  orderCode: string | null;
  vehicleId: number | null;
  vehicleBrandModel: string | null;
  vehicleLicensePlate: string | null;
  installArea: string | null;
  paymentType: string | null;
  paidAmount: number | null;
  createdAt: string;
  updatedAt: string;
  statusHistory: BookingStatusHistory[];
}

export interface Customer {
  id: number;
  fullName: string;
  email: string;
  phone: string | null;
  createdAt: string;
}

export interface CustomerDetail extends Customer {
  bookings: Booking[];
}

export interface Technician {
  id: number;
  userId: number | null;
  fullName: string;
  phone: string | null;
  email: string | null;
  active: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface Service {
  id: number;
  name: string;
  description: string | null;
  basePrice: number;
  maxPerSlot: number;
  createdAt: string;
  updatedAt: string;
}

export interface Product {
  id: number;
  serviceId: number;
  serviceName: string;
  name: string;
  brand: string | null;
  grade: string | null;
  heatRejectionPct: number | null;
  uvRejectionPct: number | null;
  vltPct: number | null;
  price: number;
  description: string | null;
  imageUrl: string | null;
  active: boolean;
  stockQuantity: number | null;
  createdAt: string;
  updatedAt: string;
}

export interface ChatMessage {
  id: number;
  bookingId: number;
  senderType: string;
  senderId: number | null;
  senderName: string | null;
  message: string;
  createdAt: string;
  readAt: string | null;
}

export interface ChatInboxItem {
  bookingId: number;
  customerName: string;
  serviceName: string;
  lastMessage: string;
  lastMessageAt: string;
  unreadCount: number;
}

export interface DashboardSummary {
  bookingsToday: number;
  bookingsThisMonth: number;
  revenueThisMonth: number;
}

export interface BookingsByStatus {
  statusCounts: Record<string, number>;
}

export interface CurrentUser {
  id: number;
  fullName: string;
  email: string;
  phone: string | null;
  profileImageUrl: string | null;
  role: string;
}

export interface Page<T> {
  content: T[];
  totalElements: number;
  totalPages: number;
  number: number;
}
```

- [ ] **Step 3: Status badge component**

Create `web_admin/components/StatusBadge.tsx`:

```tsx
import type { BookingStatus } from '@/lib/types';

const LABELS: Record<BookingStatus, string> = {
  PENDING: 'รอดำเนินการ',
  CONFIRMED: 'ยืนยันแล้ว',
  IN_PROGRESS: 'กำลังดำเนินการ',
  COMPLETED: 'เสร็จสิ้น',
  CANCELLED: 'ยกเลิก',
};

const COLORS: Record<BookingStatus, string> = {
  PENDING: 'bg-gray-100 text-gray-700',
  CONFIRMED: 'bg-blue-100 text-blue-700',
  IN_PROGRESS: 'bg-yellow-100 text-yellow-800',
  COMPLETED: 'bg-green-100 text-green-700',
  CANCELLED: 'bg-red-100 text-red-700',
};

export default function StatusBadge({ status }: { status: BookingStatus }) {
  return (
    <span className={`rounded-full px-3 py-1 text-xs font-medium ${COLORS[status]}`}>{LABELS[status]}</span>
  );
}
```

- [ ] **Step 4: Logout button and sidebar**

Create `web_admin/components/LogoutButton.tsx`:

```tsx
'use client';
import { useRouter } from 'next/navigation';

export default function LogoutButton() {
  const router = useRouter();

  async function handleLogout() {
    await fetch('/api/auth/logout', { method: 'POST' });
    router.push('/login');
    router.refresh();
  }

  return (
    <button onClick={handleLogout} className="text-sm text-brand-light hover:underline">
      ออกจากระบบ
    </button>
  );
}
```

Create `web_admin/components/Sidebar.tsx`:

```tsx
'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import LogoutButton from './LogoutButton';
import type { Role } from '@/lib/session';

interface NavItem {
  href: string;
  label: string;
}

const STAFF_ITEMS: NavItem[] = [
  { href: '/queue', label: 'คิวงาน' },
  { href: '/customers', label: 'ลูกค้า' },
  { href: '/catalog', label: 'บริการ/สินค้า' },
  { href: '/technicians', label: 'ช่าง' },
  { href: '/chat', label: 'แชท' },
];

const OWNER_ITEMS: NavItem[] = [{ href: '/dashboard', label: 'ภาพรวม' }];

export default function Sidebar({ role, fullName }: { role: Role; fullName: string }) {
  const pathname = usePathname();
  const items = role === 'TECHNICIAN' ? [{ href: '/queue', label: 'คิวงานของฉัน' }] : STAFF_ITEMS;
  const ownerItems = role === 'OWNER' ? OWNER_ITEMS : [];

  return (
    <aside className="flex h-screen w-56 flex-col bg-brand-deep text-white">
      <div className="p-4 text-lg font-bold">BKK Car Glass</div>
      <div className="px-4 pb-4 text-sm text-brand-light">{fullName}</div>
      <nav className="flex-1 space-y-1 px-2">
        {[...items, ...ownerItems].map((item) => (
          <Link
            key={item.href}
            href={item.href}
            className={`block rounded px-3 py-2 text-sm ${
              pathname.startsWith(item.href) ? 'bg-brand text-white' : 'text-brand-light hover:bg-brand-darker'
            }`}
          >
            {item.label}
          </Link>
        ))}
      </nav>
      <div className="p-4">
        <LogoutButton />
      </div>
    </aside>
  );
}
```

- [ ] **Step 5: App shell layout**

Create `web_admin/app/(app)/layout.tsx`:

```tsx
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { SESSION_COOKIE, decodeToken, isSessionValid } from '@/lib/session';
import { backendFetch } from '@/lib/backend';
import Sidebar from '@/components/Sidebar';
import type { CurrentUser } from '@/lib/types';

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const token = cookies().get(SESSION_COOKIE)?.value;
  const session = token ? decodeToken(token) : null;

  if (!isSessionValid(session)) {
    redirect('/login');
  }

  const res = await backendFetch('/api/users/me', token);
  const user: CurrentUser = await res.json();

  return (
    <div className="flex min-h-screen">
      <Sidebar role={session.role} fullName={user.fullName} />
      <main className="flex-1 overflow-y-auto bg-gray-50 p-6">{children}</main>
    </div>
  );
}
```

- [ ] **Step 6: Queue page (baseline, no realtime yet)**

Create `web_admin/app/(app)/(staff)/queue/page.tsx`:

```tsx
import { cookies } from 'next/headers';
import { decodeToken, SESSION_COOKIE } from '@/lib/session';
import QueueBoard from './QueueBoard';

export default function QueuePage() {
  const token = cookies().get(SESSION_COOKIE)?.value;
  const session = token ? decodeToken(token) : null;
  const role = session?.role ?? 'ADMIN';

  return (
    <div>
      <h1 className="mb-4 text-xl font-bold text-brand-deep">คิวงาน</h1>
      <QueueBoard role={role} />
    </div>
  );
}
```

Create `web_admin/app/(app)/(staff)/queue/QueueBoard.tsx`:

```tsx
'use client';
import { useEffect, useState } from 'react';
import { apiGet, apiPut, apiPatch, ApiError } from '@/lib/api';
import type { Booking, BookingStatus, Technician } from '@/lib/types';
import StatusBadge from '@/components/StatusBadge';
import type { Role } from '@/lib/session';

const STATUS_OPTIONS: BookingStatus[] = ['PENDING', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'];

export default function QueueBoard({ role }: { role: Role }) {
  const isTechnician = role === 'TECHNICIAN';
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [technicians, setTechnicians] = useState<Technician[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      try {
        const data = await apiGet<Booking[]>(isTechnician ? '/technician/bookings/me' : '/bookings');
        setBookings(data);
        if (!isTechnician) {
          const techs = await apiGet<Technician[]>('/admin/technicians?active=true');
          setTechnicians(techs);
        }
      } catch (err) {
        setError(err instanceof ApiError ? err.message : 'โหลดข้อมูลไม่สำเร็จ');
      } finally {
        setLoading(false);
      }
    }
    load();
  }, [isTechnician]);

  async function updateStatus(id: number, status: BookingStatus) {
    try {
      const path = isTechnician ? `/technician/bookings/${id}/status` : `/bookings/${id}/status`;
      const updated = await apiPut<Booking>(path, { status });
      setBookings((prev) => prev.map((b) => (b.id === id ? updated : b)));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'อัปเดตสถานะไม่สำเร็จ');
    }
  }

  async function assignTechnician(id: number, technicianId: number) {
    try {
      const updated = await apiPatch<Booking>(`/bookings/${id}/technician`, { technicianId });
      setBookings((prev) => prev.map((b) => (b.id === id ? updated : b)));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'มอบหมายช่างไม่สำเร็จ');
    }
  }

  if (loading) return <p>กำลังโหลด...</p>;

  return (
    <div className="space-y-3">
      {error && <p className="rounded bg-red-50 p-3 text-sm text-brand">{error}</p>}
      {bookings.length === 0 && <p className="text-gray-500">ไม่มีงานในคิว</p>}
      {bookings.map((booking) => (
        <div key={booking.id} className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="font-semibold">
                {booking.serviceName} — {booking.userFullName}
              </p>
              <p className="text-sm text-gray-500">
                {booking.bookingDate} {booking.timeSlot}
                {booking.orderCode ? ` · ${booking.orderCode}` : ''}
              </p>
              {!isTechnician && (
                <p className="text-sm text-gray-500">ช่าง: {booking.technicianName ?? 'ยังไม่มอบหมาย'}</p>
              )}
            </div>
            <StatusBadge status={booking.status} />
          </div>

          <div className="mt-3 flex flex-wrap items-center gap-2">
            {isTechnician ? (
              <>
                <button
                  onClick={() => updateStatus(booking.id, 'IN_PROGRESS')}
                  disabled={booking.status !== 'CONFIRMED'}
                  className="rounded bg-brand px-3 py-1 text-sm text-white disabled:opacity-40"
                >
                  เริ่มงาน
                </button>
                <button
                  onClick={() => updateStatus(booking.id, 'COMPLETED')}
                  disabled={booking.status !== 'IN_PROGRESS'}
                  className="rounded bg-green-600 px-3 py-1 text-sm text-white disabled:opacity-40"
                >
                  เสร็จสิ้น
                </button>
              </>
            ) : (
              <>
                <select
                  value={booking.status}
                  onChange={(e) => updateStatus(booking.id, e.target.value as BookingStatus)}
                  className="rounded border border-gray-300 px-2 py-1 text-sm"
                >
                  {STATUS_OPTIONS.map((status) => (
                    <option key={status} value={status}>
                      {status}
                    </option>
                  ))}
                </select>
                <select
                  value={booking.technicianId ?? ''}
                  onChange={(e) => e.target.value && assignTechnician(booking.id, Number(e.target.value))}
                  className="rounded border border-gray-300 px-2 py-1 text-sm"
                >
                  <option value="">มอบหมายช่าง</option>
                  {technicians.map((tech) => (
                    <option key={tech.id} value={tech.id}>
                      {tech.fullName}
                    </option>
                  ))}
                </select>
              </>
            )}
          </div>
        </div>
      ))}
    </div>
  );
}
```

- [ ] **Step 7: Manual verification**

Run: `cd "C:\Users\Jack\Desktop\it\web_admin" && npm run dev`

- Log in as ADMIN/OWNER → `/queue` shows every booking, status dropdown and technician dropdown both work (verify a status change and a technician assignment persist after a page refresh).
- Log in as a TECHNICIAN (create one via the future Task 6 UI or `POST /api/admin/technicians` with curl for now) → `/queue` shows only their assigned bookings, with the two-button flow instead of dropdowns.
- Sidebar shows the correct nav items per role (`OWNER` sees "ภาพรวม", `TECHNICIAN` sees only "คิวงานของฉัน").

- [ ] **Step 8: Commit**

```bash
git add web_admin/lib/api.ts web_admin/lib/types.ts web_admin/components/StatusBadge.tsx \
        web_admin/components/LogoutButton.tsx web_admin/components/Sidebar.tsx \
        "web_admin/app/(app)/layout.tsx" "web_admin/app/(app)/(staff)/queue/page.tsx" \
        "web_admin/app/(app)/(staff)/queue/QueueBoard.tsx"
git commit -m "$(cat <<'EOF'
feat(web-admin): app shell and queue page (list, status, assign)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Real-time queue push for technicians (STOMP)

**Files:**
- Create: `web_admin/lib/ws.ts`
- Create: `web_admin/lib/queueStore.ts`
- Test: `web_admin/lib/queueStore.test.ts`
- Modify: `web_admin/app/(app)/(staff)/queue/page.tsx`
- Modify: `web_admin/app/(app)/(staff)/queue/QueueBoard.tsx`
- Modify: `web_admin/package.json`

**Interfaces:**
- Consumes: `Booking` (Task 2's `lib/types.ts`), backend WebSocket topic `/topic/technician/{userId}/queue` (Phase 3 backend Task 4, already live)
- Produces: `createStompClient(onConnect): Client` (`lib/ws.ts`), `upsertBooking(bookings, updated): Booking[]` (`lib/queueStore.ts`)

- [ ] **Step 1: Add WebSocket dependencies**

Edit `web_admin/package.json` — add to `dependencies`:

```json
    "@stomp/stompjs": "7.0.0",
    "sockjs-client": "1.6.1"
```

and to `devDependencies`:

```json
    "@types/sockjs-client": "1.5.4"
```

Run: `cd "C:\Users\Jack\Desktop\it\web_admin" && npm install`
Expected: installs without errors.

- [ ] **Step 2: Write the failing test for the queue upsert reducer**

Create `web_admin/lib/queueStore.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { upsertBooking } from './queueStore';
import type { Booking } from './types';

function makeBooking(overrides: Partial<Booking>): Booking {
  return {
    id: 1,
    userId: 1,
    userFullName: 'ลูกค้าทดสอบ',
    serviceId: 1,
    serviceName: 'ล้างรถ',
    productId: null,
    productName: null,
    technicianId: 7,
    technicianName: 'ช่างเอ',
    bookingDate: '2026-07-21',
    timeSlot: '09:00',
    status: 'CONFIRMED',
    budget: null,
    imageUrl: null,
    quotePrice: null,
    notes: null,
    orderCode: null,
    vehicleId: null,
    vehicleBrandModel: null,
    vehicleLicensePlate: null,
    installArea: null,
    paymentType: null,
    paidAmount: null,
    createdAt: '2026-07-20T00:00:00',
    updatedAt: '2026-07-20T00:00:00',
    statusHistory: [],
    ...overrides,
  };
}

describe('upsertBooking', () => {
  it('adds a new booking not already in the list', () => {
    const existing = [makeBooking({ id: 1 })];
    const incoming = makeBooking({ id: 2, bookingDate: '2026-07-22' });

    const result = upsertBooking(existing, incoming);

    expect(result).toHaveLength(2);
    expect(result.map((b) => b.id)).toContain(2);
  });

  it('replaces an existing booking with the same id', () => {
    const existing = [makeBooking({ id: 1, status: 'CONFIRMED' })];
    const incoming = makeBooking({ id: 1, status: 'IN_PROGRESS' });

    const result = upsertBooking(existing, incoming);

    expect(result).toHaveLength(1);
    expect(result[0].status).toBe('IN_PROGRESS');
  });

  it('keeps the list sorted by date then time slot', () => {
    const existing = [
      makeBooking({ id: 1, bookingDate: '2026-07-22', timeSlot: '09:00' }),
      makeBooking({ id: 2, bookingDate: '2026-07-21', timeSlot: '15:00' }),
    ];
    const incoming = makeBooking({ id: 3, bookingDate: '2026-07-21', timeSlot: '09:00' });

    const result = upsertBooking(existing, incoming);

    expect(result.map((b) => b.id)).toEqual([3, 2, 1]);
  });
});
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd "C:\Users\Jack\Desktop\it\web_admin" && npm test`
Expected: FAIL — `Cannot find module './queueStore'`.

- [ ] **Step 4: Implement `lib/queueStore.ts`**

Create `web_admin/lib/queueStore.ts`:

```ts
import type { Booking } from './types';

export function upsertBooking(bookings: Booking[], updated: Booking): Booking[] {
  const index = bookings.findIndex((b) => b.id === updated.id);
  const next = index === -1 ? [...bookings, updated] : bookings.map((b) => (b.id === updated.id ? updated : b));
  return next.sort(compareByDateSlot);
}

function compareByDateSlot(a: Booking, b: Booking): number {
  if (a.bookingDate !== b.bookingDate) {
    return a.bookingDate.localeCompare(b.bookingDate);
  }
  return a.timeSlot.localeCompare(b.timeSlot);
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd "C:\Users\Jack\Desktop\it\web_admin" && npm test`
Expected: PASS — all 3 tests in `queueStore.test.ts` green (plus the 10 from Task 1 still passing).

- [ ] **Step 6: STOMP client factory**

Create `web_admin/lib/ws.ts`:

```ts
import { Client } from '@stomp/stompjs';
import SockJS from 'sockjs-client';

const WS_URL = process.env.NEXT_PUBLIC_WS_URL ?? 'http://localhost:8080/ws';

export function createStompClient(onConnect: (client: Client) => void): Client {
  const client = new Client({
    webSocketFactory: () => new SockJS(WS_URL) as unknown as WebSocket,
    reconnectDelay: 5000,
  });
  client.onConnect = () => onConnect(client);
  client.activate();
  return client;
}
```

- [ ] **Step 7: Wire realtime updates into the queue page**

Replace `web_admin/app/(app)/(staff)/queue/page.tsx`:

```tsx
import { cookies } from 'next/headers';
import { decodeToken, SESSION_COOKIE } from '@/lib/session';
import { backendFetch } from '@/lib/backend';
import QueueBoard from './QueueBoard';
import type { CurrentUser } from '@/lib/types';

export default async function QueuePage() {
  const token = cookies().get(SESSION_COOKIE)?.value;
  const session = token ? decodeToken(token) : null;
  const role = session?.role ?? 'ADMIN';

  let userId: number | null = null;
  if (role === 'TECHNICIAN' && token) {
    const res = await backendFetch('/api/users/me', token);
    const user: CurrentUser = await res.json();
    userId = user.id;
  }

  return (
    <div>
      <h1 className="mb-4 text-xl font-bold text-brand-deep">คิวงาน</h1>
      <QueueBoard role={role} userId={userId} />
    </div>
  );
}
```

Replace `web_admin/app/(app)/(staff)/queue/QueueBoard.tsx`:

```tsx
'use client';
import { useEffect, useState } from 'react';
import { apiGet, apiPut, apiPatch, ApiError } from '@/lib/api';
import type { Booking, BookingStatus, Technician } from '@/lib/types';
import StatusBadge from '@/components/StatusBadge';
import { createStompClient } from '@/lib/ws';
import { upsertBooking } from '@/lib/queueStore';
import type { Role } from '@/lib/session';

const STATUS_OPTIONS: BookingStatus[] = ['PENDING', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'];

export default function QueueBoard({ role, userId }: { role: Role; userId: number | null }) {
  const isTechnician = role === 'TECHNICIAN';
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [technicians, setTechnicians] = useState<Technician[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      try {
        const data = await apiGet<Booking[]>(isTechnician ? '/technician/bookings/me' : '/bookings');
        setBookings(data);
        if (!isTechnician) {
          const techs = await apiGet<Technician[]>('/admin/technicians?active=true');
          setTechnicians(techs);
        }
      } catch (err) {
        setError(err instanceof ApiError ? err.message : 'โหลดข้อมูลไม่สำเร็จ');
      } finally {
        setLoading(false);
      }
    }
    load();
  }, [isTechnician]);

  useEffect(() => {
    if (!isTechnician || !userId) return;
    const client = createStompClient((connected) => {
      connected.subscribe(`/topic/technician/${userId}/queue`, (message) => {
        const updated = JSON.parse(message.body) as Booking;
        setBookings((prev) => upsertBooking(prev, updated));
      });
    });
    return () => {
      client.deactivate();
    };
  }, [isTechnician, userId]);

  async function updateStatus(id: number, status: BookingStatus) {
    try {
      const path = isTechnician ? `/technician/bookings/${id}/status` : `/bookings/${id}/status`;
      const updated = await apiPut<Booking>(path, { status });
      setBookings((prev) => prev.map((b) => (b.id === id ? updated : b)));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'อัปเดตสถานะไม่สำเร็จ');
    }
  }

  async function assignTechnician(id: number, technicianId: number) {
    try {
      const updated = await apiPatch<Booking>(`/bookings/${id}/technician`, { technicianId });
      setBookings((prev) => prev.map((b) => (b.id === id ? updated : b)));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'มอบหมายช่างไม่สำเร็จ');
    }
  }

  if (loading) return <p>กำลังโหลด...</p>;

  return (
    <div className="space-y-3">
      {error && <p className="rounded bg-red-50 p-3 text-sm text-brand">{error}</p>}
      {bookings.length === 0 && <p className="text-gray-500">ไม่มีงานในคิว</p>}
      {bookings.map((booking) => (
        <div key={booking.id} className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="font-semibold">
                {booking.serviceName} — {booking.userFullName}
              </p>
              <p className="text-sm text-gray-500">
                {booking.bookingDate} {booking.timeSlot}
                {booking.orderCode ? ` · ${booking.orderCode}` : ''}
              </p>
              {!isTechnician && (
                <p className="text-sm text-gray-500">ช่าง: {booking.technicianName ?? 'ยังไม่มอบหมาย'}</p>
              )}
            </div>
            <StatusBadge status={booking.status} />
          </div>

          <div className="mt-3 flex flex-wrap items-center gap-2">
            {isTechnician ? (
              <>
                <button
                  onClick={() => updateStatus(booking.id, 'IN_PROGRESS')}
                  disabled={booking.status !== 'CONFIRMED'}
                  className="rounded bg-brand px-3 py-1 text-sm text-white disabled:opacity-40"
                >
                  เริ่มงาน
                </button>
                <button
                  onClick={() => updateStatus(booking.id, 'COMPLETED')}
                  disabled={booking.status !== 'IN_PROGRESS'}
                  className="rounded bg-green-600 px-3 py-1 text-sm text-white disabled:opacity-40"
                >
                  เสร็จสิ้น
                </button>
              </>
            ) : (
              <>
                <select
                  value={booking.status}
                  onChange={(e) => updateStatus(booking.id, e.target.value as BookingStatus)}
                  className="rounded border border-gray-300 px-2 py-1 text-sm"
                >
                  {STATUS_OPTIONS.map((status) => (
                    <option key={status} value={status}>
                      {status}
                    </option>
                  ))}
                </select>
                <select
                  value={booking.technicianId ?? ''}
                  onChange={(e) => e.target.value && assignTechnician(booking.id, Number(e.target.value))}
                  className="rounded border border-gray-300 px-2 py-1 text-sm"
                >
                  <option value="">มอบหมายช่าง</option>
                  {technicians.map((tech) => (
                    <option key={tech.id} value={tech.id}>
                      {tech.fullName}
                    </option>
                  ))}
                </select>
              </>
            )}
          </div>
        </div>
      ))}
    </div>
  );
}
```

- [ ] **Step 8: Manual verification**

With the backend running, open two browser windows: one logged in as ADMIN/OWNER on `/queue`, one logged in as a TECHNICIAN on `/queue`. In the admin window, assign a booking to that technician. Expect the technician's window to show the new booking appear within a few seconds without a manual refresh (no console errors in either window).

- [ ] **Step 9: Commit**

```bash
git add web_admin/package.json web_admin/package-lock.json web_admin/lib/ws.ts \
        web_admin/lib/queueStore.ts web_admin/lib/queueStore.test.ts \
        "web_admin/app/(app)/(staff)/queue/page.tsx" "web_admin/app/(app)/(staff)/queue/QueueBoard.tsx"
git commit -m "$(cat <<'EOF'
feat(web-admin): push assigned bookings to technician queue live over STOMP

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Customers page (search/list + detail)

**Files:**
- Create: `web_admin/app/(app)/(staff)/customers/page.tsx`
- Create: `web_admin/app/(app)/(staff)/customers/CustomerList.tsx`
- Create: `web_admin/app/(app)/(staff)/customers/[id]/page.tsx`

**Interfaces:**
- Consumes: `apiGet`, `Customer`/`CustomerDetail`/`Page<T>` (Task 2), `backendFetch` (Task 1), `StatusBadge` (Task 2)
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Customers list page**

Create `web_admin/app/(app)/(staff)/customers/page.tsx`:

```tsx
import CustomerList from './CustomerList';

export default function CustomersPage() {
  return (
    <div>
      <h1 className="mb-4 text-xl font-bold text-brand-deep">ลูกค้า</h1>
      <CustomerList />
    </div>
  );
}
```

Create `web_admin/app/(app)/(staff)/customers/CustomerList.tsx`:

```tsx
'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { apiGet, ApiError } from '@/lib/api';
import type { Customer, Page } from '@/lib/types';

export default function CustomerList() {
  const [search, setSearch] = useState('');
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      setLoading(true);
      try {
        const query = search ? `?search=${encodeURIComponent(search)}` : '';
        const data = await apiGet<Page<Customer>>(`/admin/customers${query}`);
        setCustomers(data.content);
      } catch (err) {
        setError(err instanceof ApiError ? err.message : 'โหลดข้อมูลไม่สำเร็จ');
      } finally {
        setLoading(false);
      }
    }
    const timeout = setTimeout(load, 300);
    return () => clearTimeout(timeout);
  }, [search]);

  return (
    <div>
      <input
        type="text"
        placeholder="ค้นหาชื่อ, อีเมล, เบอร์โทร"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        className="mb-4 w-full max-w-sm rounded border border-gray-300 px-3 py-2"
      />
      {error && <p className="mb-3 rounded bg-red-50 p-3 text-sm text-brand">{error}</p>}
      {loading ? (
        <p>กำลังโหลด...</p>
      ) : (
        <table className="w-full rounded-lg bg-white shadow-sm">
          <thead>
            <tr className="border-b text-left text-sm text-gray-500">
              <th className="p-3">ชื่อ</th>
              <th className="p-3">อีเมล</th>
              <th className="p-3">เบอร์โทร</th>
              <th className="p-3"></th>
            </tr>
          </thead>
          <tbody>
            {customers.map((customer) => (
              <tr key={customer.id} className="border-b text-sm last:border-0">
                <td className="p-3">{customer.fullName}</td>
                <td className="p-3">{customer.email}</td>
                <td className="p-3">{customer.phone ?? '-'}</td>
                <td className="p-3">
                  <Link href={`/customers/${customer.id}`} className="text-brand hover:underline">
                    ดูรายละเอียด
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
```

- [ ] **Step 2: Customer detail page**

Create `web_admin/app/(app)/(staff)/customers/[id]/page.tsx`:

```tsx
import { cookies } from 'next/headers';
import { notFound } from 'next/navigation';
import { SESSION_COOKIE } from '@/lib/session';
import { backendFetch } from '@/lib/backend';
import StatusBadge from '@/components/StatusBadge';
import type { CustomerDetail } from '@/lib/types';

export default async function CustomerDetailPage({ params }: { params: { id: string } }) {
  const token = cookies().get(SESSION_COOKIE)?.value;
  const res = await backendFetch(`/api/admin/customers/${params.id}`, token);
  if (res.status === 404) {
    notFound();
  }
  const customer: CustomerDetail = await res.json();

  return (
    <div>
      <h1 className="mb-1 text-xl font-bold text-brand-deep">{customer.fullName}</h1>
      <p className="mb-4 text-sm text-gray-500">
        {customer.email} · {customer.phone ?? '-'}
      </p>

      <h2 className="mb-2 font-semibold text-brand-deep">ประวัติการจอง</h2>
      <div className="space-y-2">
        {customer.bookings.length === 0 && <p className="text-gray-500">ยังไม่มีการจอง</p>}
        {customer.bookings.map((booking) => (
          <div key={booking.id} className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
            <div className="flex items-center justify-between">
              <div>
                <p className="font-medium">{booking.serviceName}</p>
                <p className="text-sm text-gray-500">
                  {booking.bookingDate} {booking.timeSlot}
                </p>
              </div>
              <StatusBadge status={booking.status} />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
```

- [ ] **Step 3: Manual verification**

Run: `cd "C:\Users\Jack\Desktop\it\web_admin" && npm run dev`

- Log in as ADMIN/OWNER, go to `/customers`. Verify the search box filters results (type part of a known customer's name, confirm the list narrows).
- Click "ดูรายละเอียด" on a customer with at least one booking → verify their booking history renders with correct status badges.
- Visit `/customers/999999` (a non-existent id) → expect Next.js's not-found page, not a crash.

- [ ] **Step 4: Commit**

```bash
git add "web_admin/app/(app)/(staff)/customers"
git commit -m "$(cat <<'EOF'
feat(web-admin): customers list, search, and detail page

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Catalog page (services + products CRUD + stock)

**Files:**
- Create: `web_admin/app/(app)/(staff)/catalog/page.tsx`
- Create: `web_admin/app/(app)/(staff)/catalog/ServiceManager.tsx`
- Create: `web_admin/app/(app)/(staff)/catalog/ProductManager.tsx`

**Interfaces:**
- Consumes: `apiGet/apiPost/apiPut/apiDelete`, `Service`/`Product` (Task 2)
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Catalog page shell**

Create `web_admin/app/(app)/(staff)/catalog/page.tsx`:

```tsx
import ServiceManager from './ServiceManager';
import ProductManager from './ProductManager';

export default function CatalogPage() {
  return (
    <div className="space-y-8">
      <div>
        <h1 className="mb-4 text-xl font-bold text-brand-deep">บริการ</h1>
        <ServiceManager />
      </div>
      <div>
        <h2 className="mb-4 text-xl font-bold text-brand-deep">สินค้า (ฟิล์ม)</h2>
        <ProductManager />
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Service manager**

Create `web_admin/app/(app)/(staff)/catalog/ServiceManager.tsx`:

```tsx
'use client';
import { useEffect, useState, type FormEvent } from 'react';
import { apiGet, apiPost, apiPut, apiDelete, ApiError } from '@/lib/api';
import type { Service } from '@/lib/types';

const EMPTY_FORM = { name: '', description: '', basePrice: '', maxPerSlot: '' };

export default function ServiceManager() {
  const [services, setServices] = useState<Service[]>([]);
  const [form, setForm] = useState(EMPTY_FORM);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    setServices(await apiGet<Service[]>('/services'));
  }

  useEffect(() => {
    load().catch((err) => setError(err instanceof ApiError ? err.message : 'โหลดข้อมูลไม่สำเร็จ'));
  }, []);

  function startEdit(service: Service) {
    setEditingId(service.id);
    setForm({
      name: service.name,
      description: service.description ?? '',
      basePrice: String(service.basePrice),
      maxPerSlot: String(service.maxPerSlot),
    });
  }

  function resetForm() {
    setEditingId(null);
    setForm(EMPTY_FORM);
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    const payload = {
      name: form.name,
      description: form.description || null,
      basePrice: Number(form.basePrice),
      maxPerSlot: Number(form.maxPerSlot),
    };
    try {
      if (editingId) {
        await apiPut(`/services/${editingId}`, payload);
      } else {
        await apiPost('/services', payload);
      }
      resetForm();
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'บันทึกไม่สำเร็จ');
    }
  }

  async function handleDelete(id: number) {
    if (!confirm('ลบบริการนี้?')) return;
    try {
      await apiDelete(`/services/${id}`);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'ลบไม่สำเร็จ');
    }
  }

  return (
    <div className="grid gap-4 md:grid-cols-[2fr_1fr]">
      <table className="w-full rounded-lg bg-white shadow-sm">
        <thead>
          <tr className="border-b text-left text-sm text-gray-500">
            <th className="p-3">ชื่อบริการ</th>
            <th className="p-3">ราคาเริ่มต้น</th>
            <th className="p-3">คิวสูงสุด/ช่วงเวลา</th>
            <th className="p-3"></th>
          </tr>
        </thead>
        <tbody>
          {services.map((service) => (
            <tr key={service.id} className="border-b text-sm last:border-0">
              <td className="p-3">{service.name}</td>
              <td className="p-3">{service.basePrice.toLocaleString()} บาท</td>
              <td className="p-3">{service.maxPerSlot}</td>
              <td className="space-x-2 p-3">
                <button onClick={() => startEdit(service)} className="text-brand hover:underline">
                  แก้ไข
                </button>
                <button onClick={() => handleDelete(service.id)} className="text-red-600 hover:underline">
                  ลบ
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      <form onSubmit={handleSubmit} className="space-y-3 rounded-lg bg-white p-4 shadow-sm">
        <h3 className="font-semibold">{editingId ? 'แก้ไขบริการ' : 'เพิ่มบริการใหม่'}</h3>
        {error && <p className="rounded bg-red-50 p-2 text-sm text-brand">{error}</p>}
        <input
          required
          placeholder="ชื่อบริการ"
          value={form.name}
          onChange={(e) => setForm({ ...form, name: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <textarea
          placeholder="รายละเอียด"
          value={form.description}
          onChange={(e) => setForm({ ...form, description: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <input
          required
          type="number"
          min="0"
          placeholder="ราคาเริ่มต้น"
          value={form.basePrice}
          onChange={(e) => setForm({ ...form, basePrice: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <input
          required
          type="number"
          min="1"
          placeholder="คิวสูงสุดต่อช่วงเวลา"
          value={form.maxPerSlot}
          onChange={(e) => setForm({ ...form, maxPerSlot: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <div className="flex gap-2">
          <button type="submit" className="rounded bg-brand px-4 py-2 text-sm text-white hover:bg-brand-dark">
            {editingId ? 'บันทึก' : 'เพิ่ม'}
          </button>
          {editingId && (
            <button type="button" onClick={resetForm} className="rounded border border-gray-300 px-4 py-2 text-sm">
              ยกเลิก
            </button>
          )}
        </div>
      </form>
    </div>
  );
}
```

- [ ] **Step 3: Product manager (with stock adjustment)**

Create `web_admin/app/(app)/(staff)/catalog/ProductManager.tsx`:

```tsx
'use client';
import { useEffect, useState, type FormEvent } from 'react';
import { apiGet, apiPost, apiPut, apiDelete, ApiError } from '@/lib/api';
import type { Product, Service } from '@/lib/types';

const EMPTY_FORM = {
  serviceId: '',
  name: '',
  brand: '',
  grade: '',
  price: '',
  description: '',
  imageUrl: '',
  active: true,
};

export default function ProductManager() {
  const [products, setProducts] = useState<Product[]>([]);
  const [services, setServices] = useState<Service[]>([]);
  const [form, setForm] = useState(EMPTY_FORM);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [stockDrafts, setStockDrafts] = useState<Record<number, string>>({});
  const [error, setError] = useState<string | null>(null);

  async function load() {
    const [productList, serviceList] = await Promise.all([
      apiGet<Product[]>('/products?includeInactive=true'),
      apiGet<Service[]>('/services'),
    ]);
    setProducts(productList);
    setServices(serviceList);
  }

  useEffect(() => {
    load().catch((err) => setError(err instanceof ApiError ? err.message : 'โหลดข้อมูลไม่สำเร็จ'));
  }, []);

  function startEdit(product: Product) {
    setEditingId(product.id);
    setForm({
      serviceId: String(product.serviceId),
      name: product.name,
      brand: product.brand ?? '',
      grade: product.grade ?? '',
      price: String(product.price),
      description: product.description ?? '',
      imageUrl: product.imageUrl ?? '',
      active: product.active,
    });
  }

  function resetForm() {
    setEditingId(null);
    setForm(EMPTY_FORM);
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    const payload = {
      serviceId: Number(form.serviceId),
      name: form.name,
      brand: form.brand || null,
      grade: form.grade || null,
      price: Number(form.price),
      description: form.description || null,
      imageUrl: form.imageUrl || null,
      active: form.active,
    };
    try {
      if (editingId) {
        await apiPut(`/products/${editingId}`, payload);
      } else {
        await apiPost('/products', payload);
      }
      resetForm();
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'บันทึกไม่สำเร็จ');
    }
  }

  async function handleDelete(id: number) {
    if (!confirm('ลบสินค้านี้?')) return;
    try {
      await apiDelete(`/products/${id}`);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'ลบไม่สำเร็จ');
    }
  }

  async function handleStockSave(id: number) {
    const raw = stockDrafts[id];
    if (raw === undefined) return;
    try {
      await apiPut(`/products/${id}/stock`, { stockQuantity: Number(raw) });
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'อัปเดตสต็อกไม่สำเร็จ');
    }
  }

  return (
    <div className="grid gap-4 md:grid-cols-[2fr_1fr]">
      <table className="w-full rounded-lg bg-white shadow-sm">
        <thead>
          <tr className="border-b text-left text-sm text-gray-500">
            <th className="p-3">สินค้า</th>
            <th className="p-3">ราคา</th>
            <th className="p-3">สถานะ</th>
            <th className="p-3">สต็อก</th>
            <th className="p-3"></th>
          </tr>
        </thead>
        <tbody>
          {products.map((product) => (
            <tr key={product.id} className="border-b text-sm last:border-0">
              <td className="p-3">
                {product.name}
                <div className="text-xs text-gray-400">{product.serviceName}</div>
              </td>
              <td className="p-3">{product.price.toLocaleString()} บาท</td>
              <td className="p-3">{product.active ? 'เปิดขาย' : 'ปิดขาย'}</td>
              <td className="p-3">
                <div className="flex items-center gap-1">
                  <input
                    type="number"
                    min="0"
                    placeholder={product.stockQuantity === null ? 'ไม่จำกัด' : String(product.stockQuantity)}
                    value={stockDrafts[product.id] ?? ''}
                    onChange={(e) => setStockDrafts({ ...stockDrafts, [product.id]: e.target.value })}
                    className="w-20 rounded border border-gray-300 px-2 py-1"
                  />
                  <button onClick={() => handleStockSave(product.id)} className="text-brand hover:underline">
                    บันทึก
                  </button>
                </div>
              </td>
              <td className="space-x-2 p-3">
                <button onClick={() => startEdit(product)} className="text-brand hover:underline">
                  แก้ไข
                </button>
                <button onClick={() => handleDelete(product.id)} className="text-red-600 hover:underline">
                  ลบ
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      <form onSubmit={handleSubmit} className="space-y-3 rounded-lg bg-white p-4 shadow-sm">
        <h3 className="font-semibold">{editingId ? 'แก้ไขสินค้า' : 'เพิ่มสินค้าใหม่'}</h3>
        {error && <p className="rounded bg-red-50 p-2 text-sm text-brand">{error}</p>}
        <select
          required
          value={form.serviceId}
          onChange={(e) => setForm({ ...form, serviceId: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        >
          <option value="">เลือกบริการ</option>
          {services.map((service) => (
            <option key={service.id} value={service.id}>
              {service.name}
            </option>
          ))}
        </select>
        <input
          required
          placeholder="ชื่อสินค้า"
          value={form.name}
          onChange={(e) => setForm({ ...form, name: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <input
          placeholder="แบรนด์"
          value={form.brand}
          onChange={(e) => setForm({ ...form, brand: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <input
          placeholder="เกรด"
          value={form.grade}
          onChange={(e) => setForm({ ...form, grade: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <input
          required
          type="number"
          min="0"
          placeholder="ราคา"
          value={form.price}
          onChange={(e) => setForm({ ...form, price: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <textarea
          placeholder="รายละเอียด"
          value={form.description}
          onChange={(e) => setForm({ ...form, description: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={form.active}
            onChange={(e) => setForm({ ...form, active: e.target.checked })}
          />
          เปิดขาย
        </label>
        <div className="flex gap-2">
          <button type="submit" className="rounded bg-brand px-4 py-2 text-sm text-white hover:bg-brand-dark">
            {editingId ? 'บันทึก' : 'เพิ่ม'}
          </button>
          {editingId && (
            <button type="button" onClick={resetForm} className="rounded border border-gray-300 px-4 py-2 text-sm">
              ยกเลิก
            </button>
          )}
        </div>
      </form>
    </div>
  );
}
```

- [ ] **Step 4: Manual verification**

Run: `cd "C:\Users\Jack\Desktop\it\web_admin" && npm run dev`

- On `/catalog`, create a new service, edit it, then delete it — verify the table updates each time.
- Create a product against that service, set its stock to `2` via the stock field, save, and verify the table shows `2`. Set it to `0` and confirm a booking attempt for that product in the mobile app is rejected (out-of-stock check from Phase 3 backend Task 5).
- Toggle a product's "เปิดขาย" checkbox off, save, and verify `GET /api/products` (no `includeInactive`) no longer lists it while the catalog page (which always passes `includeInactive=true`) still shows it.

- [ ] **Step 5: Commit**

```bash
git add "web_admin/app/(app)/(staff)/catalog"
git commit -m "$(cat <<'EOF'
feat(web-admin): catalog page — services and products CRUD + stock

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Technicians page (account CRUD)

**Files:**
- Create: `web_admin/app/(app)/(staff)/technicians/page.tsx`
- Create: `web_admin/app/(app)/(staff)/technicians/TechnicianManager.tsx`

**Interfaces:**
- Consumes: `apiGet/apiPost/apiPut/apiPatch`, `Technician` (Task 2)
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Technicians page shell**

Create `web_admin/app/(app)/(staff)/technicians/page.tsx`:

```tsx
import TechnicianManager from './TechnicianManager';

export default function TechniciansPage() {
  return (
    <div>
      <h1 className="mb-4 text-xl font-bold text-brand-deep">ช่าง</h1>
      <TechnicianManager />
    </div>
  );
}
```

- [ ] **Step 2: Technician manager**

Create `web_admin/app/(app)/(staff)/technicians/TechnicianManager.tsx`:

```tsx
'use client';
import { useEffect, useState, type FormEvent } from 'react';
import { apiGet, apiPost, apiPut, apiPatch, ApiError } from '@/lib/api';
import type { Technician } from '@/lib/types';

const EMPTY_ACCOUNT_FORM = { fullName: '', phone: '', email: '', password: '' };
const EMPTY_EDIT_FORM = { fullName: '', phone: '' };

export default function TechnicianManager() {
  const [technicians, setTechnicians] = useState<Technician[]>([]);
  const [accountForm, setAccountForm] = useState(EMPTY_ACCOUNT_FORM);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [editForm, setEditForm] = useState(EMPTY_EDIT_FORM);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    setTechnicians(await apiGet<Technician[]>('/admin/technicians'));
  }

  useEffect(() => {
    load().catch((err) => setError(err instanceof ApiError ? err.message : 'โหลดข้อมูลไม่สำเร็จ'));
  }, []);

  async function handleCreate(e: FormEvent) {
    e.preventDefault();
    setError(null);
    try {
      await apiPost('/admin/technicians', accountForm);
      setAccountForm(EMPTY_ACCOUNT_FORM);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'สร้างบัญชีช่างไม่สำเร็จ');
    }
  }

  function startEdit(tech: Technician) {
    setEditingId(tech.id);
    setEditForm({ fullName: tech.fullName, phone: tech.phone ?? '' });
  }

  async function handleUpdate(e: FormEvent) {
    e.preventDefault();
    if (!editingId) return;
    setError(null);
    try {
      await apiPut(`/admin/technicians/${editingId}`, editForm);
      setEditingId(null);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'บันทึกไม่สำเร็จ');
    }
  }

  async function handleDeactivate(id: number) {
    if (!confirm('ปิดใช้งานช่างคนนี้?')) return;
    try {
      await apiPatch(`/admin/technicians/${id}/deactivate`, {});
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'ปิดใช้งานไม่สำเร็จ');
    }
  }

  return (
    <div className="grid gap-4 md:grid-cols-[2fr_1fr]">
      <table className="w-full rounded-lg bg-white shadow-sm">
        <thead>
          <tr className="border-b text-left text-sm text-gray-500">
            <th className="p-3">ชื่อ</th>
            <th className="p-3">เบอร์โทร</th>
            <th className="p-3">อีเมล</th>
            <th className="p-3">สถานะ</th>
            <th className="p-3"></th>
          </tr>
        </thead>
        <tbody>
          {technicians.map((tech) =>
            editingId === tech.id ? (
              <tr key={tech.id} className="border-b text-sm last:border-0">
                <td className="p-2" colSpan={5}>
                  <form onSubmit={handleUpdate} className="flex flex-wrap items-center gap-2">
                    <input
                      required
                      value={editForm.fullName}
                      onChange={(e) => setEditForm({ ...editForm, fullName: e.target.value })}
                      className="rounded border border-gray-300 px-2 py-1"
                    />
                    <input
                      value={editForm.phone}
                      onChange={(e) => setEditForm({ ...editForm, phone: e.target.value })}
                      className="rounded border border-gray-300 px-2 py-1"
                    />
                    <button type="submit" className="rounded bg-brand px-3 py-1 text-white">
                      บันทึก
                    </button>
                    <button type="button" onClick={() => setEditingId(null)} className="rounded border px-3 py-1">
                      ยกเลิก
                    </button>
                  </form>
                </td>
              </tr>
            ) : (
              <tr key={tech.id} className="border-b text-sm last:border-0">
                <td className="p-3">{tech.fullName}</td>
                <td className="p-3">{tech.phone ?? '-'}</td>
                <td className="p-3">{tech.email ?? '-'}</td>
                <td className="p-3">{tech.active ? 'ใช้งานอยู่' : 'ปิดใช้งาน'}</td>
                <td className="space-x-2 p-3">
                  <button onClick={() => startEdit(tech)} className="text-brand hover:underline">
                    แก้ไข
                  </button>
                  {tech.active && (
                    <button onClick={() => handleDeactivate(tech.id)} className="text-red-600 hover:underline">
                      ปิดใช้งาน
                    </button>
                  )}
                </td>
              </tr>
            ),
          )}
        </tbody>
      </table>

      <form onSubmit={handleCreate} className="space-y-3 rounded-lg bg-white p-4 shadow-sm">
        <h3 className="font-semibold">เพิ่มช่างใหม่</h3>
        {error && <p className="rounded bg-red-50 p-2 text-sm text-brand">{error}</p>}
        <input
          required
          placeholder="ชื่อ-นามสกุล"
          value={accountForm.fullName}
          onChange={(e) => setAccountForm({ ...accountForm, fullName: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <input
          placeholder="เบอร์โทร"
          value={accountForm.phone}
          onChange={(e) => setAccountForm({ ...accountForm, phone: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <input
          required
          type="email"
          placeholder="อีเมล (ใช้ล็อกอิน)"
          value={accountForm.email}
          onChange={(e) => setAccountForm({ ...accountForm, email: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <input
          required
          type="password"
          minLength={8}
          placeholder="รหัสผ่าน (อย่างน้อย 8 ตัว)"
          value={accountForm.password}
          onChange={(e) => setAccountForm({ ...accountForm, password: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <button type="submit" className="rounded bg-brand px-4 py-2 text-sm text-white hover:bg-brand-dark">
          เพิ่มช่าง
        </button>
      </form>
    </div>
  );
}
```

- [ ] **Step 3: Manual verification**

Run: `cd "C:\Users\Jack\Desktop\it\web_admin" && npm run dev`

- On `/technicians`, create a new technician account (email + password ≥ 8 chars). Verify it appears in the table as "ใช้งานอยู่".
- Log in as that technician in a separate/incognito window — confirm login succeeds and `/queue` shows the technician view.
- Edit the technician's name/phone from the admin window, save, and confirm the table updates.
- Deactivate the technician, then confirm their login attempt is rejected (403 "บัญชีนี้ถูกระงับการใช้งาน", per Phase 3 backend Task 1's disabled-login check).

- [ ] **Step 4: Commit**

```bash
git add "web_admin/app/(app)/(staff)/technicians"
git commit -m "$(cat <<'EOF'
feat(web-admin): technicians page — account create/edit/deactivate

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Chat page (inbox + thread, live via STOMP)

**Files:**
- Create: `web_admin/app/(app)/(staff)/chat/page.tsx`
- Create: `web_admin/app/(app)/(staff)/chat/ChatInbox.tsx`
- Create: `web_admin/app/(app)/(staff)/chat/ChatThread.tsx`

**Interfaces:**
- Consumes: `apiGet/apiPost/apiPut`, `ChatMessage`/`ChatInboxItem` (Task 2), `createStompClient` (Task 3), backend topic `/topic/chat/{bookingId}` (pre-existing, same one the mobile app uses)
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Chat page shell**

Create `web_admin/app/(app)/(staff)/chat/page.tsx`:

```tsx
import ChatInbox from './ChatInbox';

export default function ChatPage() {
  return (
    <div>
      <h1 className="mb-4 text-xl font-bold text-brand-deep">แชท</h1>
      <ChatInbox />
    </div>
  );
}
```

- [ ] **Step 2: Chat inbox**

Create `web_admin/app/(app)/(staff)/chat/ChatInbox.tsx`:

```tsx
'use client';
import { useEffect, useState } from 'react';
import { apiGet, ApiError } from '@/lib/api';
import type { ChatInboxItem } from '@/lib/types';
import ChatThread from './ChatThread';

export default function ChatInbox() {
  const [items, setItems] = useState<ChatInboxItem[]>([]);
  const [selected, setSelected] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    try {
      setItems(await apiGet<ChatInboxItem[]>('/chat/inbox'));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'โหลดข้อมูลไม่สำเร็จ');
    }
  }

  useEffect(() => {
    load();
  }, []);

  return (
    <div className="grid gap-4 md:grid-cols-[1fr_2fr]">
      <div className="rounded-lg bg-white shadow-sm">
        {error && <p className="p-3 text-sm text-brand">{error}</p>}
        {items.map((item) => (
          <button
            key={item.bookingId}
            onClick={() => setSelected(item.bookingId)}
            className={`block w-full border-b p-3 text-left last:border-0 ${
              selected === item.bookingId ? 'bg-brand-light' : 'hover:bg-gray-50'
            }`}
          >
            <div className="flex items-center justify-between">
              <span className="font-medium">{item.customerName}</span>
              {item.unreadCount > 0 && (
                <span className="rounded-full bg-brand px-2 text-xs text-white">{item.unreadCount}</span>
              )}
            </div>
            <p className="text-xs text-gray-500">{item.serviceName}</p>
            <p className="truncate text-sm text-gray-600">{item.lastMessage}</p>
          </button>
        ))}
        {items.length === 0 && <p className="p-3 text-sm text-gray-500">ยังไม่มีข้อความ</p>}
      </div>
      <div className="rounded-lg bg-white shadow-sm">
        {selected ? (
          <ChatThread bookingId={selected} onMessagesRead={load} />
        ) : (
          <p className="p-6 text-center text-gray-400">เลือกการสนทนาทางซ้าย</p>
        )}
      </div>
    </div>
  );
}
```

- [ ] **Step 3: Chat thread**

Create `web_admin/app/(app)/(staff)/chat/ChatThread.tsx`:

```tsx
'use client';
import { useEffect, useState, type FormEvent } from 'react';
import { apiGet, apiPost, apiPut, ApiError } from '@/lib/api';
import type { ChatMessage } from '@/lib/types';
import { createStompClient } from '@/lib/ws';

export default function ChatThread({
  bookingId,
  onMessagesRead,
}: {
  bookingId: number;
  onMessagesRead: () => void;
}) {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [draft, setDraft] = useState('');
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;

    async function load() {
      try {
        const history = await apiGet<ChatMessage[]>(`/chat/bookings/${bookingId}/messages`);
        if (active) setMessages(history);
        await apiPut(`/chat/bookings/${bookingId}/read`, {});
        onMessagesRead();
      } catch (err) {
        setError(err instanceof ApiError ? err.message : 'โหลดข้อความไม่สำเร็จ');
      }
    }
    load();

    const client = createStompClient((connected) => {
      connected.subscribe(`/topic/chat/${bookingId}`, (message) => {
        const incoming = JSON.parse(message.body) as ChatMessage;
        setMessages((prev) => [...prev, incoming]);
      });
    });

    return () => {
      active = false;
      client.deactivate();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [bookingId]);

  async function handleSend(e: FormEvent) {
    e.preventDefault();
    if (!draft.trim()) return;
    try {
      await apiPost(`/chat/bookings/${bookingId}/messages`, { message: draft });
      setDraft('');
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'ส่งข้อความไม่สำเร็จ');
    }
  }

  return (
    <div className="flex h-[32rem] flex-col">
      <div className="flex-1 space-y-2 overflow-y-auto p-4">
        {error && <p className="text-sm text-brand">{error}</p>}
        {messages.map((message) => (
          <div
            key={message.id}
            className={`max-w-[75%] rounded-lg p-2 text-sm ${
              message.senderType === 'ADMIN' ? 'ml-auto bg-brand-light text-brand-deep' : 'bg-gray-100'
            }`}
          >
            <p>{message.message}</p>
          </div>
        ))}
      </div>
      <form onSubmit={handleSend} className="flex gap-2 border-t p-3">
        <input
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          placeholder="พิมพ์ข้อความ..."
          className="flex-1 rounded border border-gray-300 px-3 py-2"
        />
        <button type="submit" className="rounded bg-brand px-4 py-2 text-sm text-white hover:bg-brand-dark">
          ส่ง
        </button>
      </form>
    </div>
  );
}
```

- [ ] **Step 4: Manual verification**

With the backend running, open `/chat` as ADMIN/OWNER in one window and the mobile app's chat screen (or a second browser hitting the customer-facing chat) for the same booking in another. Send a message from each side and confirm it appears on the other side within a few seconds, with the admin's own messages right-aligned. Confirm the inbox's unread badge clears after opening a thread.

- [ ] **Step 5: Commit**

```bash
git add "web_admin/app/(app)/(staff)/chat"
git commit -m "$(cat <<'EOF'
feat(web-admin): chat inbox and live thread view

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Owner dashboard, docs update, final live-integration check

**Files:**
- Create: `web_admin/app/(app)/(owner)/dashboard/page.tsx`
- Create: `web_admin/app/(app)/(owner)/dashboard/DashboardView.tsx`
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: `apiGet`, `DashboardSummary`/`BookingsByStatus` (Task 2)
- Produces: nothing (final task).

- [ ] **Step 1: Dashboard page**

Create `web_admin/app/(app)/(owner)/dashboard/page.tsx`:

```tsx
import DashboardView from './DashboardView';

export default function DashboardPage() {
  return (
    <div>
      <h1 className="mb-4 text-xl font-bold text-brand-deep">ภาพรวม</h1>
      <DashboardView />
    </div>
  );
}
```

Create `web_admin/app/(app)/(owner)/dashboard/DashboardView.tsx`:

```tsx
'use client';
import { useEffect, useState } from 'react';
import { apiGet, ApiError } from '@/lib/api';
import type { BookingsByStatus, DashboardSummary } from '@/lib/types';

const STATUS_LABELS: Record<string, string> = {
  PENDING: 'รอดำเนินการ',
  CONFIRMED: 'ยืนยันแล้ว',
  IN_PROGRESS: 'กำลังดำเนินการ',
  COMPLETED: 'เสร็จสิ้น',
  CANCELLED: 'ยกเลิก',
};

export default function DashboardView() {
  const [summary, setSummary] = useState<DashboardSummary | null>(null);
  const [byStatus, setByStatus] = useState<BookingsByStatus | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function load() {
      try {
        const [summaryData, statusData] = await Promise.all([
          apiGet<DashboardSummary>('/admin/dashboard/summary'),
          apiGet<BookingsByStatus>('/admin/dashboard/bookings-by-status'),
        ]);
        setSummary(summaryData);
        setByStatus(statusData);
      } catch (err) {
        setError(err instanceof ApiError ? err.message : 'โหลดข้อมูลไม่สำเร็จ');
      }
    }
    load();
  }, []);

  if (error) return <p className="rounded bg-red-50 p-3 text-sm text-brand">{error}</p>;
  if (!summary || !byStatus) return <p>กำลังโหลด...</p>;

  return (
    <div className="space-y-6">
      <div className="grid gap-4 sm:grid-cols-3">
        <div className="rounded-lg bg-white p-4 shadow-sm">
          <p className="text-sm text-gray-500">การจองวันนี้</p>
          <p className="text-2xl font-bold text-brand-deep">{summary.bookingsToday}</p>
        </div>
        <div className="rounded-lg bg-white p-4 shadow-sm">
          <p className="text-sm text-gray-500">การจองเดือนนี้</p>
          <p className="text-2xl font-bold text-brand-deep">{summary.bookingsThisMonth}</p>
        </div>
        <div className="rounded-lg bg-white p-4 shadow-sm">
          <p className="text-sm text-gray-500">รายได้เดือนนี้</p>
          <p className="text-2xl font-bold text-brand-deep">{summary.revenueThisMonth.toLocaleString()} บาท</p>
        </div>
      </div>

      <div className="rounded-lg bg-white p-4 shadow-sm">
        <h2 className="mb-3 font-semibold text-brand-deep">จำนวนการจองตามสถานะ</h2>
        <div className="space-y-2">
          {Object.entries(byStatus.statusCounts).map(([status, count]) => (
            <div key={status} className="flex items-center justify-between text-sm">
              <span>{STATUS_LABELS[status] ?? status}</span>
              <span className="font-medium">{count}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Update CLAUDE.md**

Add a new section to `CLAUDE.md` (after the existing "Customer App Status" section, following whatever heading level that section uses):

```markdown
## Web Admin/Technician App Status

`web_admin/` — Next.js 14 (App Router, TypeScript, Tailwind) shared by ADMIN/OWNER staff
and TECHNICIAN users, built entirely against the Phase 3 backend (`main`, commit `a0856fb`).

- Auth: httpOnly-cookie JWT via `app/api/auth/login`, proxied through `app/api/[...proxy]`
  so the browser never talks to the Spring Boot origin directly except WebSocket/STOMP.
- Role gating: `middleware.ts` — `/dashboard/**` and `/staff/**` OWNER-only, `/queue/**` all
  three staff roles, everything else ADMIN/OWNER.
- Pages: `/queue` (list + status update + technician assignment, realtime push for
  technicians via `/topic/technician/{userId}/queue`), `/customers` (search + detail),
  `/catalog` (services + products CRUD + stock), `/technicians` (account CRUD),
  `/chat` (inbox + live thread via `/topic/chat/{bookingId}`), `/dashboard` (OWNER revenue
  summary).
- Run: `cd web_admin && npm run dev` (needs the backend running; see `.env.local.example`
  for `BACKEND_URL`/`NEXT_PUBLIC_WS_URL`).
- Tests: `cd web_admin && npm test` (Vitest) — covers `lib/session.ts` (auth/role-gating
  logic) and `lib/queueStore.ts` (realtime upsert). Page components are verified manually;
  no component-test framework is set up for them.
- Known gap: no dedicated ADMIN/OWNER account-management page yet (`/staff/**` middleware
  rule is reserved for it) — new OWNER/ADMIN users must be created directly in the database
  for now.
```

- [ ] **Step 3: Full test suite**

Run: `cd "C:\Users\Jack\Desktop\it\web_admin" && npm test`
Expected: PASS — all tests from Tasks 1 and 3 green (13 total: 10 in `session.test.ts`, 3 in `queueStore.test.ts`).

Run: `cd "C:\Users\Jack\Desktop\it\web_admin" && npm run build`
Expected: production build succeeds with no type errors.

- [ ] **Step 4: Live integration check**

With the backend running against the real database:

- Seed or promote one OWNER account, one ADMIN account, and create one TECHNICIAN account through the `/technicians` page.
- As OWNER: visit every page (`/dashboard`, `/queue`, `/customers`, `/customers/[id]`, `/catalog`, `/technicians`, `/chat`) — confirm no console errors, no broken requests in the Network tab.
- As ADMIN: confirm `/dashboard` and any `/staff/**` URL redirect to `/login?error=forbidden`; every other page works identically to OWNER minus the dashboard link in the sidebar.
- As TECHNICIAN: confirm `/customers`, `/catalog`, `/technicians`, `/chat`, and `/dashboard` all redirect; `/queue` shows only their own bookings with the two-button status flow; assigning them a new booking from the ADMIN window updates their `/queue` live.
- End-to-end booking lifecycle: create a booking as a customer (mobile app), see it appear on `/queue` as ADMIN, assign a technician, watch it appear on the technician's `/queue`, mark it `IN_PROGRESS` then `COMPLETED` as the technician, confirm the status reflects back on the ADMIN's `/queue` after a refresh.

- [ ] **Step 5: Commit**

```bash
git add "web_admin/app/(app)/(owner)/dashboard" CLAUDE.md
git commit -m "$(cat <<'EOF'
feat(web-admin): owner dashboard, docs, and final integration pass

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## After all 8 tasks

Run `cd web_admin && npm test && npm run build` one more time and confirm both succeed. This branch (`feature/phase3-web-admin`) is then ready for the finishing-a-development-branch workflow (merge/PR/keep/discard), the same way Phase 1, 2, and 3-backend were handled.
