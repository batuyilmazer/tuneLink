# tuneLink

Arkadaş grubunun Spotify'da ne dinlediğini gerçek zamanlıya yakın gösteren iOS uygulaması ve widget'ı.

Ana ekranda ve kilit ekranı / ana ekran widget'ında grubu kaç kişi olduğundan bağımsız olarak tüm üyelerin şu an dinlediklerini görürsün. Kimse aktif dinlemiyorsa son dinlediği parça gösterilir. Spotify Developer Console'da manuel allowlist — sadece davet ettiğin insanlar erişebilir.

---

## Nasıl Çalışır

```
iOS (PKCE) ──► /auth/callback ──► Spotify token exchange
                                         │
                                    Redis'e yaz
                                         │
                        ◄── cron her 30s ──► Spotify /me/player/currently-playing
                                         │
                                    track değişti?
                                         │
                              APNs silent push gönder
                                         │
                        ◄── widget reload ──► GET /group-feed
```

1. iOS, PKCE flow başlatır → kullanıcı Spotify'da onaylar → `code + code_verifier` backend'e gönderilir
2. Backend token exchange yapar, `access_token` ve `refresh_token`'ı Redis'e yazar, iOS'a `userId + sessionToken` döner
3. Poller her 30 saniyede Spotify'ı yoklar; track değişince diğer üyelere APNs silent push atar
4. Widget, push alınca veya kendi refresh zamanında `/group-feed` çağırır

---

## Proje Yapısı

```
tuneLink/
├── backend/              # Hono (TypeScript) API
│   ├── src/
│   │   ├── index.ts
│   │   ├── routes/
│   │   │   ├── auth.ts          # POST /auth/callback, DELETE /auth/logout
│   │   │   ├── group.ts         # GET /group-feed
│   │   │   └── deviceToken.ts   # POST /device-token
│   │   ├── services/
│   │   │   ├── spotify.ts       # Token exchange + /me/player
│   │   │   ├── redis.ts         # Typed Redis helpers
│   │   │   └── apns.ts          # APNs silent push
│   │   └── jobs/
│   │       └── poller.ts        # node-cron, 30s
│   ├── Dockerfile
│   └── docker-compose.yml       # production (api only, redis dışarıda)
├── ios/
│   ├── tuneLink/
│   │   ├── Auth/
│   │   │   ├── SpotifyAuthManager.swift   # PKCE + ASWebAuthenticationSession
│   │   │   └── LoginView.swift
│   │   ├── Pairing/
│   │   │   └── PairingView.swift
│   │   └── AppDelegate.swift
│   └── tuneLinkWidget/
│       ├── Provider.swift       # TimelineProvider → /group-feed
│       ├── WidgetView.swift     # Home screen + lock screen UI
│       └── tuneLinkWidget.swift
├── Caddyfile                    # api.tunelink.bira.pizza → localhost:13742
└── docker-compose.yml           # dev: backend + redis birlikte
```

---

## API

| Method | Endpoint | Açıklama |
|--------|----------|----------|
| `POST` | `/auth/callback` | `{ code, code_verifier }` → `{ userId, sessionToken }` |
| `DELETE` | `/auth/logout` | `{ userId }` + Bearer token → grubu terk et |
| `GET` | `/group-feed?userId=` | Tüm üyelerin now-playing / last-played |
| `POST` | `/device-token` | `{ userId, deviceToken }` → APNs için kaydet |

### `/group-feed` yanıt örneği

```json
[
  {
    "userId": "spotify:user:abc",
    "displayName": "Ahmet",
    "playing": true,
    "track": "Paranoid Android",
    "artist": "Radiohead",
    "albumArt": "https://...",
    "timestamp": 1748524800000,
    "lastTrack": null,
    "lastArtist": null,
    "lastAlbumArt": null,
    "lastPlayedAt": null
  },
  {
    "userId": "spotify:user:xyz",
    "displayName": "Zeynep",
    "playing": false,
    "track": null,
    "artist": null,
    "albumArt": null,
    "timestamp": null,
    "lastTrack": "Exit Music (For a Film)",
    "lastArtist": "Radiohead",
    "lastAlbumArt": "https://...",
    "lastPlayedAt": 1748521200000
  }
]
```

---

## Redis Şeması

| Key | Değer | TTL |
|-----|-------|-----|
| `users:all` | Set — tüm userId'ler | yok |
| `user:{id}:tokens` | `{ access_token, refresh_token }` | yok |
| `user:{id}:now_playing` | `{ track, artist, albumArt, timestamp }` | 60s |
| `user:{id}:last_played` | `{ track, artist, albumArt, timestamp }` | yok |
| `user:{id}:displayName` | string | yok |
| `user:{id}:device_token` | APNs device token | yok |
| `session:{id}` | sessionToken | yok |

---

## Kurulum

### Gereksinimler

- Node 20+
- Redis 7+
- Xcode 15+
- Spotify Developer Console'da uygulama (Development Mode — max 25 kullanıcı)

### Backend — yerel geliştirme

```bash
cp backend/.env.example backend/.env   # değerleri doldur
cd backend
npm install
npm run dev   # tsx watch, port 4002
```

### Backend + Redis — Docker

```bash
docker-compose up --build   # kök dizindeki compose (backend + redis)
```

### Ortam Değişkenleri

```env
SPOTIFY_CLIENT_ID=
SPOTIFY_CLIENT_SECRET=
SPOTIFY_REDIRECT_URI=tunelinkapp://auth/callback
REDIS_URL=redis://localhost:6379
PORT=4002

# APNs (opsiyonel — olmadan push çalışmaz, poller çalışır)
APNS_KEY_PATH=/run/secrets/apns.p8
APNS_KEY_ID=
APNS_TEAM_ID=
APNS_BUNDLE_ID=pizza.bira.tuneLink
APNS_PRODUCTION=false   # production'da true yap
```

### iOS

1. Xcode'da `ios/tuneLink.xcodeproj` aç
2. `Info.plist`'te `BASE_URL`'i backend adresinle güncelle
3. Signing & Capabilities'te kendi Team ID'nı seç
4. App Group'un (`group.pizza.bira.tuneLink`) hem ana target hem widget target'ta aktif olduğunu kontrol et
5. Çalıştır

---

## Deployment

Sunucuda Caddy reverse proxy çalışır:

```
api.tunelink.bira.pizza → localhost:13742
```

Production image yalnızca backend'i içerir; Redis ayrı bir container veya managed servis olarak çalışır.

```bash
# sunucuda
cd /server/projects/tuneLink
docker-compose -f backend/docker-compose.yml up -d --build
```

---

## Limitler

- **Spotify Development Mode:** max 25 kullanıcı, hepsi Spotify Developer Console'a tek tek eklenmeli
- **WidgetKit budget:** sistemin widget'a tanıdığı refresh hakkı saatte ~40–70; anlık değil. Track değişiminde APNs silent push bu limiti aşmak için kullanılır
- **Token yenileme:** backend her 401'de `refresh_token` ile Spotify'dan yeni `access_token` alır; iOS hiçbir zaman token tutmaz
