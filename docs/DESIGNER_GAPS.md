# Remaining gaps for Designer / Research

Honest leftovers after `fix/full-redesign` (web + iOS).

## Acceptance still soft

- **True windowed virtualization** for 5k tiles: section `content-visibility` + max-200 paging is in; absolute recycled-cell grid not yet.
- **Web pinch-zoom** in immersive viewer: double-tap scale + swipe H/V only; no full gesture matrix.
- **iOS year sticky hierarchy** is month-level pinned headers, not full YYYY → MMMM YYYY → day stack like web.
- **iOS select/bulk on Timeline/Favorites** not parity with web glass bar (album detail add/remove is).
- **iOS AuthImage parity**: AsyncImage still unauthenticated; Settings notes ATS/local networking.
- **Empty trash / permanent delete**: UI stub only — needs API approval (`docs/API_GAPS.md`).
- **Web Settings** screen deferred per DESIGN_SYSTEM §6.7.
- **Font loading**: Instrument Sans / Geist not bundled; system + Inter stack used.
- **Filmstrip performance**: loads AuthImage thumbs for up to 5k — may need windowed filmstrip.

## Visual nits for picky pass

- Sticky year/month stacking under mobile bottom tabs + select bar vertical rhythm.
- Album cover radius 8 vs photo grid radius 0 — intentional exception; confirm covers don’t look “SaaS card”.
- Confirm whether logout overflow on desktop is enough vs dedicated settings.
