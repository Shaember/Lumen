# package-lock.json

`web/package-lock.json` is required for `npm ci` in:

- `web/Dockerfile`
- `zimaos/Dockerfile`

If the lockfile is missing after clone:

```bash
cd web && npm install
```

Then commit the generated `web/package-lock.json` before building Docker/Zima images.
