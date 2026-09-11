# API gaps noted during full redesign

Non-breaking UI stubs are in place. Do **not** invent endpoints without CoS/user approval.

## Missing backend endpoints

| Need | Current | UI behavior |
|------|---------|-------------|
| Empty trash / purge all | Soft-delete + `POST /photos/{id}/restore` + `GET /photos/trash` only | Web/iOS «Очистить корзину» shows confirm + toast/alert pointing here |
| Permanent delete single trash item | Soft delete only | Not exposed |
| «30 дней» auto-purge policy | Not implemented | Copy mentions when API exists |

## Existing APIs used by redesign (no contract change)

- `POST /albums/{id}/photos` — add photos (bulk)
- `DELETE /albums/{id}/photos/{photoId}` — remove from album
- `PATCH /photos/{id}/favorite`
- `DELETE /photos/{id}` — move to trash
- `POST /photos/{id}/restore`

## iOS platform gaps (not API)

1. **AsyncImage + Authorization** — thumbnails/originals loaded via `AsyncImage` without Bearer token → 401 on protected media. Need authenticated image loader (URLSession + cache) parity with web `AuthImage`.
2. **ATS** — `NSAllowsLocalNetworking` added for LAN/dev. Non-local cleartext `http://` hosts still need TLS or a broader exception.

## Suggested endpoints (approval required)

```
DELETE /api/v1/photos/trash          # empty trash for current user
DELETE /api/v1/photos/{id}/permanent # purge one trashed photo
```

Or:

```
POST /api/v1/photos/trash/empty
```

No implementation shipped without approval.
