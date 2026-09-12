# package-lock.json

## Preferred (reproducible)

`web/package-lock.json.gz.b64` is a gzip+base64 of the npm lockfile (small enough for MCP sync).

Dockerfiles decode it to `package-lock.json` then run `npm ci`.

To expand locally:

```bash
base64 -d web/package-lock.json.gz.b64 | gunzip > web/package-lock.json
```

Or generate fresh:

```bash
cd web && npm install
```

## Fallback

If neither `package-lock.json` nor `package-lock.json.gz.b64` exists, Docker runs `npm install`.
