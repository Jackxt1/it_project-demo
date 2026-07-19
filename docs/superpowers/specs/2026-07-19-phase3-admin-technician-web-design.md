# Phase 3: Web Admin + Technician (Next.js) — Design

## 1. Overview

Phase 3 replaces the never-built "Flutter Web admin" plan with a single **Next.js** web
application shared by two audiences that log into the same system with different roles:

- **Admin / Owner** — day-to-day operations (queue, customers, products, chat) plus,
  for Owner only, revenue dashboard.
- **Technician** — sees only their own assigned job queue and updates status on their
  own jobs. Cannot see anything admin-scoped.

This phase also adds two features that came up during scoping but touch existing
systems more than the web app itself:

- **Film stock tracking** on `products`, enforced at booking time and surfaced to the
  existing customer mobile app.
- **Profile editing** (name, phone, profile picture, password) in the existing
  customer mobile app.

Everything in this document ships together — no further staging within Phase 3.

## 2. Roles

`Role` enum grows from `{CUSTOMER, ADMIN}` to:

| Role | Can see |
|---|---|
| `CUSTOMER` | unchanged — mobile app only |
| `ADMIN` | queue, assign technicians, customers, products/services, chat inbox — no revenue dashboard |
| `OWNER` | everything `ADMIN` can do **+** revenue dashboard **+** manage admin/owner accounts |
| `TECHNICIAN` | only their own assigned bookings (queue), can update status on those bookings |

`ADMIN` and `OWNER` are both "staff" for the purposes of every endpoint except the
dashboard and admin-account management, which are `OWNER`-only.

## 3. Technician login — link, don't merge

`technicians` stays its own table (it's already referenced by `bookings.technician_id`
and by tested Phase 1 code). Instead of migrating that foreign key, we **link** a
technician record to a login identity:

```sql
ALTER TABLE technicians ADD COLUMN IF NOT EXISTS user_id BIGINT UNIQUE REFERENCES users(id);
```

- Creating a technician (admin action) now creates **both** a `users` row
  (`role = TECHNICIAN`, email + password so they can log in) **and** a `technicians`
  row pointing at it via `user_id`.
- `bookings.technician_id` keeps working exactly as today — no data migration, no
  changes to `BookingRepository`/existing slot logic.
- A technician's identity for auth (`CurrentUserService.getCurrentUser()`) is the
  `User`; their identity for job assignment is still `Technician`. The link is
  `technician.getUser().getId()`.

This was chosen over fully merging `Technician` into `User` because it avoids
touching the already-shipped, tested Phase 1 booking/assignment code — smaller, safer
change for the same outcome.

## 4. New/changed backend endpoints

All under existing `GlobalExceptionHandler` conventions (`{timestamp, status, error, message}`).

**Technician accounts** (`ROLE_ADMIN`/`ROLE_OWNER`):
- `POST /api/admin/technicians` `{fullName, phone, email, password}` → creates `User(TECHNICIAN)` + linked `Technician`
- `PUT /api/admin/technicians/{id}` `{fullName, phone}` → updates both rows
- `PUT /api/admin/technicians/{id}/deactivate` → existing soft-delete, unchanged behavior, also worth considering whether the linked `User` should be blocked from login (recommend yes: reject login if `technician.active == false`)

**Technician queue** (`ROLE_TECHNICIAN`):
- `GET /api/technician/bookings/me` → bookings where `booking.technician.user.id == currentUser.id`, soonest first
- `PUT /api/technician/bookings/{id}/status` `{status}` → only `IN_PROGRESS` or `COMPLETED`, only on bookings assigned to the caller; reuses `BookingService` status-history recording, rejects with 403 if the booking isn't theirs and 400 if the target status isn't one of the two allowed values

**Real-time queue push:**
- `BookingService.assignTechnician(...)`, after saving, sends the updated `BookingResponse` to `/topic/technician/{technicianUserId}/queue` via the existing `SimpMessagingTemplate` (same pattern `ChatService` already uses for `/topic/chat/{bookingId}`). No new WebSocket endpoint needed — same `/ws` SockJS endpoint, new topic.
- Next.js queue page subscribes to `/topic/technician/{myUserId}/queue` and upserts the booking into its local list when a message arrives.

**Stock** (`products.stock_quantity`, nullable — `null` means "not tracked, always bookable"):
- `PUT /api/admin/products/{id}/stock` `{stockQuantity}` (`ROLE_ADMIN`/`ROLE_OWNER`) — admin sets the absolute count (matches "แอดมินปรับเอง" — no delta math needed)
- `GET /api/products` response gains `stockQuantity` so the mobile app can compute `available = stockQuantity == null || stockQuantity > 0`
- `BookingService.create()`: if `product.stockQuantity != null`, decrement by 1; if it's already `0`, reject with a new `OutOfStockException` ("สินค้าหมดสต็อก") — this is the server-side backstop even though the mobile UI will already hide out-of-stock products
- `BookingService.updateStatus(...)`: when transitioning **into** `CANCELLED` from any non-`CANCELLED` status, if `product.stockQuantity != null`, increment by 1

**Profile** (`ROLE_CUSTOMER`, but really any authenticated user):
- `PUT /api/users/me` `{fullName?, phone?, profileImageUrl?}` → `UserResponse`
- `PUT /api/users/me/password` `{currentPassword, newPassword}` → 204; verifies `currentPassword` against `passwordHash`, `newPassword` ≥ 8 chars (same rule as registration); rejects with 400 + Thai message on mismatch
- Reuses the existing `POST /api/uploads/image` endpoint for the picture itself — the profile endpoint just stores the resulting URL
- `users` table gains `profile_image_url VARCHAR(500) NULL`

**Dashboard** (`ROLE_OWNER` only):
- `GET /api/admin/dashboard/summary?from=YYYY-MM-DD&to=YYYY-MM-DD` → booking counts by status + revenue sum (`SUM(paid_amount)` for bookings with `status != CANCELLED` in range), grouped by day. Kept intentionally simple — no charts library decisions here, just numbers; the Next.js side decides how to render them.

## 5. Next.js application

New top-level folder `web_admin/` (Next.js, App Router, TypeScript, Tailwind CSS —
same red/white premium palette as the mobile app: `#EE2020` / `#B31818` / `#8F1313` /
`#FDE9E9` / `#530B0B`).

**Auth & session:**
- `app/api/auth/login/route.ts` — proxies to `POST /api/auth/login`, then sets the
  returned JWT as an **httpOnly, secure, sameSite=lax cookie** — never exposed to
  client-side JS.
- `app/api/[...proxy]/route.ts` — a single catch-all proxy route that forwards any
  `/api/**` call to the Spring Boot backend, injecting `Authorization: Bearer` from
  the cookie server-side. Client code calls `/api/...` on the Next.js origin, never
  the Spring Boot origin directly.
- `middleware.ts` — reads the cookie, decodes the JWT role claim, and gates routes:
  - `/queue/**` → `TECHNICIAN`, `ADMIN`, `OWNER`
  - `/dashboard/**`, `/staff/**` (admin account management) → `OWNER` only
  - everything else under `/(app)` → `ADMIN`, `OWNER`
  - unauthenticated → redirect to `/login`

**Pages (route groups):**
- `(auth)/login`
- `(staff)/queue` — booking list, status updates, assign technician (Admin/Owner view — full list; Technician view — same route, filtered to their own jobs server-side)
- `(staff)/customers` — search/history
- `(staff)/catalog` — products/services CRUD + stock adjustment
- `(staff)/technicians` — technician account CRUD (Owner: full; Admin: read + assign only — exact split can be refined during implementation)
- `(staff)/chat` — inbox + thread view (STOMP subscribe to `/topic/chat/{bookingId}`, same contract the mobile app already uses)
- `(owner)/dashboard` — revenue/report

**Real-time:** browser STOMP client (`@stomp/stompjs`) over native `SockJS`
(`sockjs-client`) against the existing `/ws` endpoint — browsers support SockJS
natively so there's no need for the raw-WebSocket workaround the Flutter app uses.

## 6. Mobile app changes (existing `mobile/` Phase 2 app)

- **Out-of-stock films:** `step2_product.dart` (film mode) hides or visibly disables
  any product where `available == false` per the updated `Product` model/contract.
- **Profile editing:** new screen off `profile_screen.dart` — edit name/phone, change
  picture (reuses existing `uploadImage` flow), change password (current + new +
  confirm). New `UserService` methods calling the two new endpoints from §4.

## 7. Testing

- Backend: extend existing JUnit/Mockito suites — new tests for technician-account
  creation (User+Technician link), technician-scoped queue endpoint (ownership +
  status-transition guard), stock decrement/increment on create/cancel and the
  out-of-stock rejection, profile update + password change (including wrong-current-password case).
- Next.js: component/route tests for auth gating (middleware role checks) and the
  queue real-time upsert behavior; exact framework (Jest+RTL vs Playwright) decided
  in the implementation plan.
- Mobile: extend existing widget tests for the out-of-stock product state and the new
  profile-edit screen.

## 8. Out of scope for this phase

- Full inventory workflow (batch receiving, per-install-area consumption math) — stock
  is a flat count per product, admin-adjusted.
- Push notifications to the Next.js web app (browser push) — the real-time queue uses
  WebSocket while the tab is open; no background/closed-tab notification.
- Anything from the original Phase 4 list (real payments, Google Sign-In, forgot
  password) — unaffected by this phase.
