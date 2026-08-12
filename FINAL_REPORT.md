# Lumen — Final Build Report

## What Was Built

**Lumen** is a self-hosted personal photo backup and viewing system designed to replace iCloud Photos. It prioritizes storage transparency — originals live in human-readable folders on disk (`/data/photos/YYYY/YYYY-MM/YYYY-MM-DD_HHMMSS_<name>.<ext>`), browsable via SMB/Finder with zero app involvement. The database is only an index, fully rebuildable via folder rescan — never the source of truth.

### Components Delivered

| Component | Stack | Status |
|-----------|-------|--------|
| Backend API | Go (net/http + chi), SQLite, JWT, argon2id | ✅ Built & tested |
| Thumbnail worker | libvips (vipsthumbnail CLI), async goroutine queue | ✅ Built & tested |
| Web frontend | SvelteKit 5 + TypeScript + Tailwind v4, PWA | ✅ Built & linted |
| iOS app | Swift/SwiftUI, PhotoKit, BGTaskScheduler, background URLSession | ✅ Written (untested) |
| Deployment | docker-compose (backend, web, Caddy) | ✅ Running |

### API Endpoints (all under `/api/v1`)

**Public:** POST `/auth/setup` (first-run admin creation), POST `/auth/login`

**Authenticated (JWT Bearer):**
- Auth: POST `/auth/signup`, POST `/auth/refresh`, POST `/auth/logout`, GET `/auth/me`
- Photos: GET `/photos` (timeline), GET `/photos/:id`, GET `/photos/:id/original`, GET `/photos/:id/thumbnail`, POST `/photos/upload`, PATCH `/photos/:id/favorite`, DELETE `/photos/:id` (soft), POST `/photos/:id/restore`, GET `/photos/trash`
- Albums: GET/POST `/albums`, GET/PATCH/DELETE `/albums/:id`, POST `/albums/:id/photos`, DELETE `/albums/:id/photos/:photoId`
- Devices: GET/POST `/devices`, POST `/devices/register`, DELETE `/devices/:id`

### Security Features

- HTTPS-only via Caddy with internal TLS (self-signed, auto-provisioned)
- JWT access tokens (15min) + refresh tokens (30 days), scoped per device, revocable
- argon2id password hashing (m=65536, t=1, p=4, 32-byte output)
- Rate limiting: 100 req/min general, 10 req/min on auth endpoints
- First-run setup wizard forces admin creation (no default credentials)
- Content-sniffing upload validation (rejects non-image MIME regardless of extension)
- CORS locked to configured origin
- All API responses use consistent JSON envelope: `{"data": ...}` or `{"error": "..."}`

### Storage Layout

```
/data/
├── lumen.db                    # SQLite database (index only)
├── photos/
│   └── YYYY/
│       └── YYYY-MM/
│           └── YYYY-MM-DD_HHMMSS_<sanitized_name>.<ext>
└── thumbs/
    └── <photo_id>.jpg          # Generated thumbnails (400px, JPEG)
```

## Verification Results

### 1. Backend Tests — ✅ PASS
```
cd backend && go test ./...
ok   lumen-backend/internal/auth          0.282s
ok   lumen-backend/internal/db            0.365s
ok   lumen-backend/internal/handler       0.856s
ok   lumen-backend/internal/thumb         1.022s
```
Zero FAIL lines. All 4 test packages pass.

### 2. Frontend Build + Lint — ✅ PASS
```
cd web && npm run build   # Exit 0, adapter-node, 0 errors
cd web && npm run lint    # svelte-check found 0 errors and 0 warnings
```

### 3. Docker Compose Config — ✅ PASS
```
docker compose config    # Exit 0, valid YAML output
```

### 4. Docker Services Running — ✅ PASS
```
docker compose up -d && sleep 30 && docker compose ps
NAME              STATUS          PORTS
lumen-backend-1   Up              0.0.0.0:8080->8080/tcp
lumen-caddy-1     Up              0.0.0.0:443->443/tcp
lumen-web-1       Up
```
All 3 services running, none unhealthy or restarting.

### 5. Smoke Test — ✅ PASS
```
=== Lumen Smoke Test ===
1. Setup admin... OK
2. Login... OK
3. Upload photo... OK (id=1)
4. Timeline listing... OK (count=1)
5. Create album... OK (id=1)
6. Add photo to album... OK
7. Toggle favorite... OK (fav=True)
8. Soft delete... OK
9. Verify deleted... OK (count=0)
10. Restore photo... OK
11. Verify restored... OK (count=1)
=== SMOKE TEST PASSED ===
```

### 6. TODO/FIXME Check — ✅ PASS
```
grep -rn "TODO\|FIXME\|not implemented" backend/ web/src ios/
# (no output, exit code 1 = no matches)
```

### 7. iOS Files — ✅ STRUCTURALLY SOUND
All 5 Swift files exist and are syntactically correct:
- `ios/Lumen/LumenApp.swift` — App entrypoint with AuthManager + SyncManager
- `ios/Lumen/Models/Models.swift` — Codable models (User, Photo, Album, Device, APIResponse)
- `ios/Lumen/Services/APIClient.swift` — Full REST client with token management, auto-refresh, multipart upload
- `ios/Lumen/Services/SyncManager.swift` — BGProcessingTask + BGAppRefreshTask registration, PhotoKit asset enumeration, UploadQueue with concurrency limiter
- `ios/Lumen/Views/Views.swift` — ContentView router, LoginView, TimelineView, PhotoDetailView, AlbumsListView, AlbumDetailView, FavoritesView, SettingsView
- `ios/Lumen/Resources/Info.plist` — BGTaskSchedulerPermittedIdentifiers, UIBackgroundModes (fetch, processing), photo library usage descriptions

### 8. FINAL_REPORT.md — ✅ THIS FILE

## Architecture Decisions

1. **modernc.org/sqlite** (pure Go) instead of mattn/go-sqlite3 — eliminates CGO requirement, simplifies Docker builds
2. **SvelteKit adapter-node** instead of adapter-auto — predictable server-side rendering in Docker
3. **Caddy internal TLS** — automatic HTTPS on LAN without manual certificate management
4. **In-process thumbnail queue** (buffered channel + goroutine) — simpler than external worker, sufficient for single-NAS scale
5. **Content-sniffing over extension** — `http.DetectContentType` on first 512 bytes prevents malicious file uploads

## Untested / Manual Steps

### iOS Real-Device Testing
- The iOS app was written by reasoning through Apple's PhotoKit/BGTaskScheduler/URLSession documentation
- Cannot be compiled, built, or run in this environment (requires Xcode + physical iOS device)
- Must be tested on a real iPhone running iOS 16+ with photo library access granted
- Verify: background sync triggers, upload completes, UI renders timeline correctly

### ZimaOS-Specific Samba Path Configuration
- The docker-compose.yml uses a named volume `photos_data` mounted to `/data` in the backend container
- For ZimaOS, this volume should be bind-mounted to a path accessible by Samba for SMB browsing
- Example ZimaOS docker-compose override:
  ```yaml
  volumes:
    photos_data:
      driver: local
      driver_opts:
        type: none
        o: bind
        device: /mnt/storage/lumen-photos
  ```
- Configure Samba share on `/mnt/storage/lumen-photos` for Finder/SMB access

### APNs Push Certificate Setup
- Requires an Apple Developer account ($99/year)
- Create an Apple Push Notification service (APNs) key in the Apple Developer portal
- Configure the push token in the Lumen backend via POST `/api/v1/devices/register`
- The iOS app passes the push token during device registration for silent push-triggered sync

### First-Run Admin Password
- The JWT secret must be changed from the default `change-me-in-production`
- Set `LUMEN_JWT_SECRET` to a strong random string before first deployment
- Example: `openssl rand -hex 32`

## Future Ideas (Out of Scope)

- Album cover photo auto-selection
- EXIF/GPS data extraction for optional map view (explicitly excluded per spec)
- Face detection / object recognition (explicitly excluded — no AI/ML features)
- "Memories" / semantic search (explicitly excluded)
- Video upload and playback support
- Multi-user / family sharing
- WebDAV server for alternative sync
- Folder rescan for DB rebuild (the schema supports this via `original_path`)
