# Lumen on ZimaOS — Deployment Guide

## Quick Deploy

ZimaOS supports Docker Compose natively. Upload these files to your ZimaOS device and deploy via the web UI.

### 1. File Structure on ZimaOS

```
/DATA/AppData/lumen/
├── docker-compose.yml
├── .env
├── Caddyfile
├── backend/
│   └── (backend Docker image will be built here)
└── web/
    └── (web Docker image will be built here)
```

### 2. Create `.env` file

```bash
# Generate a secure JWT secret
LUMEN_JWT_SECRET=your-random-secret-here
LUMEN_CORS_ORIGIN=http://YOUR_ZIMAOS_IP
```

### 3. Create `docker-compose.yml`

```yaml
services:
  caddy:
    image: caddy:2-alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - backend
      - web
    restart: unless-stopped

  backend:
    image: ghcr.io/shaember/lumen-backend:latest  # or build locally
    ports:
      - "8080:8080"
    environment:
      - LUMEN_DATA_DIR=/data
      - LUMEN_DB_PATH=/data/lumen.db
      - LUMEN_JWT_SECRET=${LUMEN_JWT_SECRET}
      - LUMEN_PORT=8080
      - LUMEN_CORS_ORIGIN=${LUMEN_CORS_ORIGIN:-http://localhost}
    volumes:
      - /DATA/Photos:/data/photos  # ZimaOS photos folder
      - lumen_data:/data
    restart: unless-stopped

  web:
    image: ghcr.io/shaember/lumen-web:latest  # or build locally
    environment:
      - ORIGIN=${LUMEN_CORS_ORIGIN:-http://localhost}
    depends_on:
      - backend
    restart: unless-stopped

volumes:
  lumen_data:
  caddy_data:
  caddy_config:
```

### 4. Create `Caddyfile`

```caddy
:80 {
    # API proxy
    handle /api/* {
        reverse_proxy backend:8080
    }

    # Everything else goes to web frontend
    handle {
        reverse_proxy web:3000
    }
}
```

### 5. Deploy via ZimaOS Web UI

1. Open ZimaOS dashboard (http://YOUR_ZIMAOS_IP:8080)
2. Go to **App Store** → **Custom Install** or **Docker Compose**
3. Upload the `docker-compose.yml` file
4. Set environment variables from `.env`
5. Click **Install** / **Deploy**

### 6. Access Lumen

- Open http://YOUR_ZIMAOS_IP in your browser
- First run: create admin account
- Upload photos via web UI or iOS app

## Storage Transparency

Photos are stored in human-readable folders:
```
/DATA/Photos/
├── 2024/
│   └── 2024-06/
│       ├── 2024-06-15_103000_vacation.jpg
│       ├── 2024-06-15_103001_beach.png
│       └── ...
└── 2025/
    └── ...
```

These folders are accessible via:
- **SMB/Samba** — mount as network drive on any computer
- **ZimaOS File Manager** — browse in web UI
- **Direct SSH** — if SSH is enabled

## iOS App Configuration

1. Install Lumen iOS app (TestFlight or build from source)
2. Open Settings → Server URL
3. Enter: `http://YOUR_ZIMAOS_IP`
4. Login with your admin credentials
5. Grant photo library access
6. Enable background sync

## Backup Recommendations

Since Lumen replaces iCloud's implicit redundancy, follow the 3-2-1 rule:

- **3** copies of your photos
- **2** different storage media (e.g., ZimaOS HDD + external USB)
- **1** offsite copy (e.g., cloud backup, another location)

Use ZimaOS's built-in backup tools or rsync:
```bash
rsync -av /DATA/Photos/ /mnt/backup/photos/
```

## Troubleshooting

### Photos not uploading
- Check backend logs: `docker compose logs backend`
- Verify `/DATA/Photos` folder permissions
- Ensure LUMEN_JWT_SECRET is set in .env

### Can't access from iOS app
- Verify ZimaOS IP address
- Check firewall rules (port 80 must be open)
- Try http:// not https://

### Thumbnails not generating
- Backend needs vips-tools installed (included in Docker image)
- Check: `docker compose exec backend which vipsthumbnail`

## Advanced: HTTPS with Let's Encrypt

For HTTPS on a real domain:

```caddy
your-domain.com {
    tls your-email@example.com

    handle /api/* {
        reverse_proxy backend:8080
    }

    handle {
        reverse_proxy web:3000
    }
}
```

Update LUMEN_CORS_ORIGIN to match your domain.
