# Remaining gaps for Designer / Research

Honest leftovers after designer hit-list pass on `fix/full-redesign`.

## Hit-list addressed (this pass)
- No `max-w-7xl` on photo screens; full-bleed wall
- No SaaS page titles («Лента» / «Альбомы» / …) as big headers
- No cream/accent capsule selected nav; mobile selected = square radius 6
- Controls radius 6 / sheets 8; Inter removed (system-ui / SF / Geist)
- Glass chrome **overlays** the photo grid (fixed header + bottom tabs) so blur is real
- Auth frost panel; timeline year sticky overlay 72–96px; viewer glass-fade ~80px + 72px filmstrip
- Album covers as mosaic; empty = 1 line + CTA
- iOS: frost auth, mosaic albums, inline titles, accent tint, trash from Photos toolbar

## Acceptance still soft
- **True windowed virtualization** for 5k tiles: section `content-visibility` + paging; absolute recycled-cell grid not yet
- **Web pinch-zoom** in immersive viewer: double-tap scale + swipe only
- **iOS year sticky hierarchy** still month-level, not full YYYY → MMMM YYYY → day
- **iOS select/bulk** on Timeline/Favorites not parity with web glass bar
- **iOS AuthImage parity**: AsyncImage still unauthenticated
- **Empty trash / permanent delete**: UI stub only — needs API (`docs/API_GAPS.md`)
- **Web Settings** deferred per DESIGN_SYSTEM §6.7
- **Font loading**: Instrument Sans / Geist not bundled; system stack used (no Inter)
- **Filmstrip performance**: AuthImage thumbs for large libraries — may need windowed filmstrip
- **Album mosaic** on list uses cover crop positions (single cover_photo_id); multi-thumb mosaic needs API cover set

## Visual nits
- Sticky year/month stacking under mobile bottom tabs + select bar vertical rhythm
- Confirm logout overflow on desktop vs dedicated settings
