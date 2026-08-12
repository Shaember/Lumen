# Lumen

Self-hosted personal photo backup and viewing system — an iCloud Photos replacement.

**Philosophy**: Storage transparency. Originals live in human-readable folders on disk, browsable via SMB/Finder with zero app involvement. The database is only an index, fully rebuildable via folder rescan.

## Architecture

```
┌─────────┐     ┌─────────┐     ┌─────────┐
│  Caddy  │────▶│  Web    │     │ Backend │
│  :443   │     │ (Svelte)│     │  (Go)   │
│  :80    │     │  :3000  │     │  :8080  │
└─────────┘     └─────────┘     └─────────┘
     │                              │
     └──────────────────────────────┘
                     │
              ┌──────┴──────┐
              │   SQLite    │
              │  /data/     │
              │  photos/    │
              │  thumbs/    │
              └─────────────┘
```

## Components

| Component | Stack |
|-----------|-------|
| Backend | Go (net/http + chi), SQLite, JWT, argon2id |
| Thumbnail worker | libvips (vipsthumbnail), async queue |
| Web frontend | SvelteKit 5 + TypeScript + Tailwind v4, PWA |
| iOS app | Swift/SwiftUI, PhotoKit, BGTaskScheduler |
| Deploy | docker-compose + Caddy (auto HTTPS) |

## Quick Start

```bash
# Set a JWT secret
export LUMEN_JWT_SECRET=$(openssl rand -hex 32)

# Build and run
docker compose up -d --build

# Open in browser
open http://localhost

# First visit: create admin account
# Then upload photos from the web UI or iOS app
```

## Storage Layout

```
/data/
├── lumen.db                 # SQLite index (rebuildable)
├── photos/
│   └── YYYY/YYYY-MM/
│       └── YYYY-MM-DD_HHMMSS_<name>.<ext>
└── thumbs/
    └── <photo_id>.jpg       # 400px JPEG thumbnails
```

## API

All endpoints under `/api/v1`. See `FINAL_REPORT.md` for full endpoint list.

## Backup

**3-2-1 Rule**: Since Lumen replaces iCloud's implicit redundancy:
- **3** copies of your photos
- **2** different storage media
- **1** offsite copy

The `/data/photos` folder can be backed up with any standard tool (rsync, restic, borg).

## iOS App

Native Swift/SwiftUI app with:
- PhotoKit-based background sync (BGProcessingTask)
- Foreground full-sync on launch
- Silent push hook for immediate sync
- Timeline browsing matching the web UI

Requires Xcode 15+ and iOS 16+. See `ios/` directory.

## License

MIT
