# Remaining gaps for Designer / Research

Honest leftovers after atmosphere + chrome polish pass on `fix/full-redesign` (2026-09-12).

## Atmosphere lock (done — do not change)
- App canvas `#100E0C` + top-left warm wash `rgba(232,228,217,.09)` ~80vmax + bottom-right `rgba(90,70,50,.14)` ~70vmax + edge vignette
- Grain fixed overlay opacity **`.045`** only (`mix-blend-mode: overlay`) — never 8–15%
- Viewer pure `#000` — no grain, no wash (`body.viewer-mode` / iOS `Color.black`)
- Glass chrome: `blur(24px) saturate(1.8)` on chrome only — no wallpaper under grid, no blur on thumbs, no nested glass cards
- iOS: same mesh via `LumenAtmosphere` + ~4% grain

## Screenshot bugs fixed this pass
- Year sticky `top: var(--chrome-h)` + wall `pt-14` so «2026» sits fully below glass header
- Desktop selected nav: square radius 6 **accent fill + accent-ink** (`.nav-tab.active`) — not dark capsule
- Auth CTA accent `#E8E4D9` + fields radius 6; frost panel over atmospheric washes
- Viewer: both prev/next chevrons always; full-width 72px glass filmstrip with real thumbs; ~80px glass fades; trash stroke consistent
- Mobile Timeline icon: photo/grid stroke (not hamburger)
- Typography: system-ui / SF — never Inter
- Empty album mosaic: dashed stroke, not gray SaaS card
- Rate limits unchanged: general 100/100, auth 10/20

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
- **iOS grain**: Canvas random dots approximate CSS SVG noise; may shimmer on redraw — consider static Image asset later

## Visual nits
- Sticky year/month + select bar vs mobile bottom tabs vertical rhythm under heavy scroll
- Confirm logout overflow on desktop vs dedicated settings
