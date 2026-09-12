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

1. ~~AsyncImage + Authorization~~ — **fixed:** `AuthImage` (URLSession + Bearer from Keychain token store + cache).
2. **ATS** — `NSAllowsLocalNetworking` for LAN/dev. Non-LAN cleartext `http://` still blocked — use https or LAN IP.
3. Tokens in **Keychain** (migrates legacy UserDefaults once).
4. Refresh / upload / createAlbum / registerDevice decode shapes match backend partial payloads.

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
