# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**tuneLink** — A small group of friends (manually allowlisted in Spotify dev console) each see everyone else's live Spotify now-playing track in an iOS widget and main app feed.

## Architecture

### Monorepo Layout (planned)
```
tuneLink/
├── backend/          # Hono (TypeScript) API server
│   ├── src/
│   │   ├── index.ts          # Entry point, Hono app
│   │   ├── routes/
│   │   │   ├── auth.ts       # /auth/callback
│   │   │   └── group.ts      # /group-feed
│   │   ├── services/
│   │   │   ├── spotify.ts    # Spotify API client + token refresh
│   │   │   └── redis.ts      # Redis client + typed helpers
│   │   └── jobs/
│   │       └── poller.ts     # Cron: polls Spotify every ~30s per active user
│   └── package.json
└── ios/              # Swift + SwiftUI + WidgetKit
    ├── tuneLink/             # Main app target
    │   ├── Auth/             # PKCE flow, Spotify OAuth
    │   └── Pairing/          # Invite code UI
    └── tuneLinkWidget/       # WidgetKit extension
        ├── Provider.swift    # TimelineProvider, calls /group-feed
        └── WidgetView.swift  # Lock screen + home screen views
```

## Backend

**Framework:** Hono on Node.js (TypeScript)  
**Runtime:** Node 20+  
**Package manager:** npm (or bun — decide at init time)

### Dev Commands
```bash
cd backend
npm run dev        # Start with hot reload (tsx watch)
npm run build      # tsc compile to dist/
npm start          # Run compiled dist/index.js
npm test           # Run tests (vitest)
npm run lint       # eslint
```

### Redis Schema
```
users:all                  → Set of all registered userIds              TTL: none
user:{userId}:tokens       → { access_token, refresh_token }           TTL: none
user:{userId}:now_playing  → { track, artist, albumArt, timestamp }     TTL: 60s
user:{userId}:last_played  → { track, artist, albumArt, timestamp }     TTL: none
user:{userId}:displayName  → string                                     TTL: none
```

### Auth Flow (PKCE)
1. iOS initiates PKCE → sends `code + code_verifier` to backend  
2. Backend exchanges with Spotify (`/api/token`) → stores tokens in Redis  
3. All subsequent Spotify calls happen backend-only; iOS never holds tokens

### Token Refresh
Backend catches 401 from Spotify, pulls `refresh_token` from Redis, fetches new `access_token`, updates Redis, retries. Transparent to iOS.

### Polling Architecture
- Cron job runs every ~30s, iterates active users, calls `GET /me/player/currently-playing`
- Writes result to `user:{userId}:now_playing` (TTL 60s)
- Widget reads `/group-feed` → backend reads from Redis, never hits Spotify directly
- Spotify scope needed: `user-read-currently-playing` or `user-read-playback-state`
- 204 response from Spotify = user not playing → surface as "not listening" state

## iOS

**Language:** Swift 5.9+  
**Min target:** iOS 16 (required for APNs-triggered widget reload)  
**Key frameworks:** SwiftUI, WidgetKit, AuthenticationServices (ASWebAuthenticationSession for PKCE)

### Widget Refresh Strategy
- WidgetKit system budget: ~40–70 refreshes/hour (not real-time)
- For faster updates: APNs silent push → app calls `WidgetCenter.shared.reloadAllTimelines()` in background
- Backend detects track change during poll → sends APNs silent push to all other group members

### Build / Test
Use Xcode 15+. No CLI build commands defined yet — use Xcode GUI or `xcodebuild`.

## Environment Variables (backend)

```
SPOTIFY_CLIENT_ID
SPOTIFY_CLIENT_SECRET
SPOTIFY_REDIRECT_URI
REDIS_URL
APNS_KEY_ID           # optional, for push notifications
APNS_TEAM_ID          # optional
APNS_KEY_PATH         # optional
```

## Spotify API Notes

- App starts in **Development Mode**: max 25 allowlisted users — users are manually added in the Spotify developer console
- Extended Quota required only for public launch (Spotify manual review; social apps often rejected)
- Poll `/v1/me/player/currently-playing` at ~30s intervals; 204 = nothing playing
