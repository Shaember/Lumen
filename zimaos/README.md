# Lumen on ZimaOS

## App Store / Custom Install (paste repo URL)

1. In ZimaOS **App Store → Custom Install** (or Compose), paste:
   ```
   https://github.com/Shaember/Lumen
   ```
2. Set compose file to **`zimaos/docker-compose.yml`** (builds from this repo; no GHCR required).
3. Environment (from `zimaos/.env.example`):
   - `LUMEN_JWT_SECRET` — `openssl rand -hex 32`
   - `LUMEN_CORS_ORIGIN` — `http://YOUR_ZIMAOS_IP` (or https domain)
4. Install. Open **`http://YOUR_ZIMAOS_IP/`** (host **port 80** — avoids clash with other apps on `:3000`).
5. First-run wizard creates the admin account.

### What gets installed

| Service | Role | Internal |
|---------|------|----------|
| `caddy` | TLS-ready reverse proxy | host `:80` → API + Node web |
| `backend` | Go API + SQLite + thumbs | `:8080` |
| `web` | SvelteKit Node adapter | `:3000` (not published) |

### Volumes

| Host | Container | Purpose |
|------|-----------|---------|
| `/DATA/Photos` | `/data/photos` | Originals (SMB-friendly tree) |
| `/DATA/AppData/lumen/data` | `/data` | DB + thumbs metadata |

### iOS

Server URL: `http://YOUR_ZIMAOS_IP` (same origin Caddy serves).

## Optional all-in-one image

```bash
docker build -f zimaos/Dockerfile -t lumen .
```

Prefer the compose multi-service path above for Zima App Store.
