# tuneLink Roadmap

Check off each step as it's completed. Every step has exactly one job.

---

## Phase 1 — Backend Scaffold

- [x] **1.1** Create `backend/` directory and run `npm init -y`
- [x] **1.2** Install runtime dependencies: `hono`, `@hono/node-server`, `ioredis`, `node-cron`
- [x] **1.3** Install dev dependencies: `typescript`, `tsx`, `vitest`, `eslint`, `@types/node`
- [x] **1.4** Create `backend/tsconfig.json` (target ES2022, module NodeNext)
- [x] **1.5** Add `dev`, `build`, `start`, `test`, `lint` scripts to `backend/package.json`
- [x] **1.6** Create `backend/src/index.ts` — bare Hono app on port 3000, health-check `GET /`
- [x] **1.7** Confirm `npm run dev` starts and `GET /` returns 200

---

## Phase 2 — Redis Service

- [x] **2.1** Create `backend/src/services/redis.ts` — initialise `ioredis` client from `REDIS_URL`
- [x] **2.2** Add typed helper `setTokens(userId, { access_token, refresh_token })` (no TTL)
- [x] **2.3** Add typed helper `getTokens(userId)` → `{ access_token, refresh_token } | null`
- [x] **2.4** Add typed helper `setNowPlaying(userId, payload)` with TTL 60s
- [x] **2.5** Add typed helper `getNowPlaying(userId)` → payload or `null`
- [x] **2.6** Add typed helper `setPair(pairId, { userA, userB })` (no TTL)
- [x] **2.7** Add typed helper `getPair(pairId)` → `{ userA, userB } | null`
- [x] **2.8** Add typed helper `setUserPairId(userId, pairId)` (no TTL) — reverse lookup key `user:{userId}:pairId`
- [x] **2.9** Add typed helper `getUserPairId(userId)` → `pairId | null`

---

## Phase 3 — Spotify Service

- [x] **3.1** Create `backend/src/services/spotify.ts` — `exchangeCode(code, codeVerifier)` calls `/api/token` and returns tokens along with the Spotify `user_id` (from `GET /v1/me` immediately after exchange)
- [x] **3.2** Add `refreshAccessToken(userId)` — reads `refresh_token` from Redis, fetches new `access_token`, writes back to Redis
- [x] **3.3** Add `fetchNowPlaying(userId)` — calls `GET /v1/me/player/currently-playing`, handles 204 (not playing) and 401 (triggers `refreshAccessToken` then retries once)
- [x] **3.4** Add `.env` file with placeholder values for all required env vars

---

## Phase 4 — Auth Routes

- [x] **4.1** Create `backend/src/routes/auth.ts` — `POST /auth/callback` receives `{ code, code_verifier }` from iOS, calls `exchangeCode`, stores tokens via Redis helper, returns `{ userId }` (Spotify user ID)
  > iOS constructs the Spotify authorize URL and runs PKCE itself via `ASWebAuthenticationSession` — no backend redirect step needed.

---

## Phase 5 — Pairing Route

- [x] **5.1** Create `backend/src/routes/pair.ts` — `POST /pair/invite` accepts `{ userId }`, generates a short unique invite code, stores `invite:{code} → userId` in Redis (TTL 10 min), returns `{ inviteCode }`
- [x] **5.2** Add `POST /pair` — accepts `{ inviteCode, userId }`, looks up the inviting user, generates a `pairId` (UUID v4), writes `pair:{pairId}` to Redis for both users, writes `user:{userId}:pairId` reverse-lookup for both users via `setUserPairId`, deletes the invite key, returns `{ pairId }`

---

## Phase 6 — Partner Track Route

- [x] **6.1** Create `backend/src/routes/partner.ts` — `GET /partner-track` accepts `userId` query param, calls `getUserPairId(userId)` to look up `pairId`, gets `{ userA, userB }` from `getPair`, resolves the partner's userId, fetches partner's `now_playing` from Redis, returns JSON (or `{ playing: false }`)
  > Note: `userId` is not authenticated — acceptable for a private 2-user app, but do not expose sensitive data beyond now-playing state.

---

## Phase 7 — Polling Cron Job

- [x] **7.1** Create `backend/src/jobs/poller.ts` — cron runs every 30s, iterates all `user:*:tokens` keys using `SCAN` (cursor-based, not `KEYS`) to avoid blocking Redis
- [x] **7.2** For each active user, call `fetchNowPlaying(userId)` and write result with `setNowPlaying`
- [x] **7.3** Register poller in `backend/src/index.ts` so it starts with the server

---

## Phase 8 — Backend Tests

- [x] **8.1** Write unit test for `refreshAccessToken` (mock Spotify HTTP, assert Redis write)
- [x] **8.2** Write unit test for `fetchNowPlaying` — 204 path returns `null`, 401 path triggers refresh
- [x] **8.3** Write integration test for `GET /partner-track` against a real Redis (test container or local)
- [x] **8.4** Confirm `npm test` passes with all tests green

---

## Phase 9 — iOS App Scaffold

- [ ] **9.1** Create Xcode project `ios/tuneLink` (iOS 16+, SwiftUI lifecycle)
- [ ] **9.2** Add WidgetKit extension target `tuneLinkWidget` to the Xcode project
- [ ] **9.3** Configure App Group entitlement shared between main app and widget extension
- [ ] **9.4** Add `BASE_URL` to `Info.plist` pointing at backend

---

## Phase 10 — iOS Auth (PKCE)

- [x] **10.1** Create `Auth/SpotifyAuthManager.swift` — generates `code_verifier` and `code_challenge`
- [x] **10.2** Open Spotify authorize URL via `ASWebAuthenticationSession`, capture redirect with `code`
- [x] **10.3** POST `{ code, code_verifier }` to `POST /auth/callback`, store returned `userId` in `UserDefaults` (shared App Group)

---

## Phase 11 — iOS Pairing UI

- [x] **11.1** Create `Pairing/PairingView.swift` — two sections: (a) "Your invite code" — on appear, POST `{ userId }` to `/pair/invite` and display the returned `inviteCode` for user A to share; (b) "Enter partner's code" — text field + submit button
- [x] **11.2** On submit, POST `{ inviteCode, userId }` to `/pair`, store returned `pairId` in shared `UserDefaults`

---

## Phase 12 — WidgetKit Extension

- [x] **12.1** Create `tuneLinkWidget/Provider.swift` — `TimelineProvider` that calls `GET /partner-track?userId=…` and decodes response
- [x] **12.2** Create `tuneLinkWidget/WidgetView.swift` — home screen widget view (track name, artist, album art)
- [x] **12.3** Add lock screen widget view variant (`accessoryRectangular` / `accessoryCircular` families)
- [x] **12.4** Register both widget families in `tuneLinkWidget/@main` entry point

---

## Phase 13 — APNs Push (Widget Fast-Refresh)

- [ ] **13.1** Enable Push Notifications capability in the main app target
- [ ] **13.2** Register for remote notifications in `AppDelegate` / `@main`, send device token to backend `POST /device-token`
- [x] **13.3** Add `POST /device-token` route to backend — stores `user:{userId}:device_token` in Redis
- [x] **13.4** In `poller.ts`, after writing `now_playing`, compare with previous value — if track changed, send APNs silent push to partner's device token
- [x] **13.5** Handle silent push in app background: call `WidgetCenter.shared.reloadAllTimelines()`

---

## Phase 14 — End-to-End Smoke Test

- [ ] **14.1** Auth both users A and B through the iOS app against the local backend
- [ ] **14.2** Pair A and B using an invite code
- [ ] **14.3** Start playing a track on Spotify as user A; confirm widget on user B's device updates within ~30s (polling) or ~5s (APNs)
- [ ] **14.4** Verify "not listening" state renders correctly when user A stops playback
