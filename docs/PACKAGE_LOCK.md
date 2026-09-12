# package-lock.json

Preferred: commit `web/package-lock.json` so Docker/Zima can run `npm ci`.

If the lockfile is missing after clone:

```bash
cd web && npm install
```

Dockerfiles (`web/Dockerfile`, `zimaos/Dockerfile`) accept either path:
- lock present → `npm ci`
- lock missing → `npm install` (slower, non-reproducible)

Commit the lockfile when size allows for reproducible builds.
