# package-lock.json

**Status on `fix/full-redesign`:** lockfile not committed (MCP payload size). Docker/Zima use:

```dockerfile
COPY package.json ./
COPY package-lock.json* ./
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi
```

Generate locally before a reproducible release:

```bash
cd web && npm install
# commit web/package-lock.json when git push credentials are available
```

See also `docs/ZIMAOS_DEPLOY.md`.
