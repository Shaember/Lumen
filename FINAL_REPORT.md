# Lumen — Final Build Report (Audit Pass)

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

## What the Audit Found and Fixed

### Critical Issues Fixed

1. **Smoke test was broken** — `AUTH=*** Bearer ***"` instead of `$TOKEN`. All authenticated steps were silently using a fake token. Fixed: now uses the actual JWT token from login.

2. **No vipsthumbnail in Docker** — The backend Dockerfile only installed `ca-certificates`, not `vips-tools`. Thumbnails were never generated in Docker. Fixed: added `vips-tools` to the Dockerfile.

3. **Rate limiter bugs** — Used `r.RemoteAddr` (ip:port) instead of just IP, and the `paths` parameter was dead code (never checked). Fixed: extracts IP properly, removed unused path filtering.

4. **No first-run enforcement** — The backend served normal API traffic even before an admin account was created. Fixed: added `firstRunGuard` middleware that returns403 on all endpoints except `/auth/setup` and `/auth/login` until a user exists.

5. **No rescan/reindex endpoint** — The spec says "DB is only an index, fully rebuildable via folder rescan" but no endpoint existed. Fixed: added `POST /api/v1/admin/rescan` that walks `/data/photos/` and rebuilds the index.

6. **`Get` handler returned Go field names** — The `GET /photos/:id` endpoint returned `ID`, `UserID`, `Filename` (Go exported names) instead of `id`, `user_id`, `filename` (JSON snake_case). Fixed: now uses `scanPhotos()` consistently.

7. **`chiURLParam` was fragile** — Custom URL path parsing instead of Go 1.22's `r.PathValue()`. Fixed: all handlers now use `r.PathValue("id")`.

8. **`thumbnail_path` leaked filesystem paths** — API responses contained absolute paths like `/data/thumbs/1.jpg`. Fixed: now returns `has_thumbnail: true/false` instead.

9. **CORS mismatch** — Set to `https://localhost` but Caddy serves on HTTP too. Fixed: CORS middleware now accepts both `http://localhost` and `https://localhost`.

10. **`os.MkdirAll` and `io.Copy` errors silently ignored** — File upload could silently fail. Fixed: errors are now checked and handled (cleanup on failure).

11. **Deprecated `version: '3.8'` in docker-compose.yml** — Removed.

12. **No `.env.example`** — Added with all required variables.

### Issues Found But NOT Fixed (out of scope or blocked)

- **Single thumbnail size** — Only400px thumbnails are generated. The spec doesn't explicitly require multiple sizes, but a grid thumb + preview + original pattern would be better. Noted as future improvement.

- **No photo deduplication** — Same file can be uploaded multiple times. The spec doesn't mention dedup, and hash-based dedup adds complexity. Noted.

- **Rate limiter burst=20 for auth** — Means20 requests are allowed before throttling kicks in. This is intentional for normal use but might be too generous for brute-force protection. Noted.

## Verification Results

### 1. Backend Tests — ✅ PASS
```
cd backend && go test ./...
ok   lumen-backend/internal/auth          0.426s
ok   lumen-backend/internal/db            0.583s
ok   lumen-backend/internal/handler       1.261s
ok   lumen-backend/internal/thumb         0.811s
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
lumen-caddy-1     Up              0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
lumen-web-1       Up
```
All 3 services running, none unhealthy or restarting.

### 5. Smoke Test — ✅ PASS
```
=== Lumen Smoke Test ===
1. Setup admin... OK
2. Login... OK
3. Upload photo... OK (id=7)
4. Timeline listing... OK (count=7)
5. Storage path check... OK (2024-06-15_103000_test.png)
6. Create album... OK (id=5)
7. Add photo to album... OK
8. Toggle favorite... OK (fav=True)
9. Reject non-image... OK
10. Soft delete... OK
11. Verify deleted... OK (count=6)
12. Check trash... OK (trash=1)
13. Restore photo... OK
14. Verify restored... OK (count=7)
=== SMOKE TEST PASSED ===
```

### 6. TODO/FIXME Check — ✅ PASS
```
grep -rn "TODO\|FIXME\|not implemented" backend/ web/src ios/
# (no output)
```

### 7. Security Checks — ✅ PASS
- Malformed JSON → proper error response
- Empty body → proper error response
- Missing auth → "unauthorized"
- Fake token → "invalid token"
- Non-image upload → "only image files are accepted" (content sniffing works)
- CORS → locked to configured origin, not `*`
- First-run guard → blocks API until admin created

### 8. iOS Files — ✅ STRUCTURALLY SOUND
All 5 Swift files exist and are syntactically correct. See `ios/` directory.

## API Endpoints

**Public:** POST `/auth/setup`, POST `/auth/login`, POST `/auth/refresh`

**Authenticated (JWT Bearer):**
- Auth: POST `/auth/signup`, POST `/auth/logout`, GET `/auth/me`
- Photos: GET `/photos`, GET `/photos/:id`, GET `/photos/:id/original`, GET `/photos/:id/thumbnail`, POST `/photos/upload`, PATCH `/photos/:id/favorite`, DELETE `/photos/:id`, POST `/photos/:id/restore`, GET `/photos/trash`
- Albums: GET/POST `/albums`, GET/PATCH/DELETE `/albums/:id`, POST `/albums/:id/photos`, DELETE `/albums/:id/photos/:photoId`
- Devices: GET/POST `/devices`, POST `/devices/register`, DELETE `/devices/:id`
- Admin: POST `/admin/rescan`

## Architecture Decisions

1. **modernc.org/sqlite** (pure Go) — eliminates CGO, simplifies Docker
2. **SvelteKit adapter-node** — predictable SSR in Docker
3. **Caddy internal TLS** — auto HTTPS on LAN
4. **In-process thumbnail queue** — simple, sufficient for single-NAS scale
5. **Content-sniffing over extension** — `http.DetectContentType` prevents malicious uploads

## Untested / Manual Steps

### iOS Real-Device Testing
- Requires Xcode + physical iPhone
- Must verify: background sync triggers, upload completes, UI renders

### ZimaOS-Specific Configuration
- Docker volume should be bind-mounted to Samba-accessible path
- Example: `device: /mnt/storage/lumen-photos` in docker-compose override

### APNs Push Certificate
- Requires Apple Developer account ($99/year)
- Create APNs key in Apple Developer portal

## Future Ideas (Out of Scope)

- Multiple thumbnail sizes (grid thumb + preview)
- Photo deduplication by content hash
- Album cover photo auto-selection
- EXIF/GPS data extraction
- Video upload and playback
- Multi-user / family sharing
