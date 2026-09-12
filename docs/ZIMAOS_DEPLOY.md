# Lumen on ZimaOS — Deployment Guide

## Recommended: paste GitHub URL (build from repo)

ZimaOS / CasaOS App Store **Custom Install**:

1. Paste repo URL: **`https://github.com/Shaember/Lumen`**
2. Compose path: **`zimaos/docker-compose.yml`**
3. Set env from `zimaos/.env.example`:
   ```bash
   LUMEN_JWT_SECRET=$(openssl rand -hex 32)
   LUMEN_CORS_ORIGIN=http://YOUR_ZIMAOS_IP
   ```
4. Deploy. UI: **`http://YOUR_ZIMAOS_IP/`** on **port 80** (not 3000 — avoids App Store / other app clashes).

See also `zimaos/README.md`.

### Runtime topology (matches this compose)

```
Browser/iOS → :80 Caddy
                ├─ /api/*  → backend:8080  (Go)
                └─ /*      → web:3000      (SvelteKit Node adapter)
```

**Do not** serve the Node build with Caddy `file_server` alone — web uses `@sveltejs/adapter-node` and must be proxied to `node build`.

### Storage

```
/DATA/Photos/YYYY/YYYY-MM/YYYY-MM-DD_HHMMSS_name.ext   # originals (SMB)
/DATA/AppData/lumen/data/                              # SQLite + thumbs
```

### iOS app

1. Build from `ios/` (Xcode, iOS 17+).
2. Settings → Server URL: `http://YOUR_ZIMAOS_IP`
3. Login → grant Photos → Sync.

## Local / non-Zima

Root `docker-compose.yml` + `docker/Caddyfile` (ports 80/443, named volumes) is the generic path. Zima compose adds `/DATA/...` binds and `x-casaos` metadata.

## Troubleshooting

| Symptom | Check |
|---------|--------|
| Build fails on `npm ci` | `web/package-lock.json` must exist in the repo |
| Blank UI / SSR errors | Confirm Caddy proxies to `web:3000`, not `file_server` |
| 401 on media | JWT / login; iOS uses AuthImage with Bearer |
| JWT errors | `LUMEN_JWT_SECRET` set and stable across restarts |
| Port busy | Compose publishes **80**; change host mapping if needed |

## HTTPS

Point a domain at the device and swap `zimaos/Caddyfile` for a `tls` site block; set `LUMEN_CORS_ORIGIN` to `https://your-domain`.
