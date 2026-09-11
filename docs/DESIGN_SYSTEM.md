# Lumen Design System — Full Redesign Spec

**Goal:** Apple Photos feel (no smart albums) + modern brutalism + minimalism + liquid glass (Hermes / Zima / Apple Liquid Glass rules).  
**Surfaces:** Web (SvelteKit) + iOS (SwiftUI) — one visual language, shared tokens, parity of IA and states.  
**Non-goals:** Memories, People, For You, ML search. Do not break API contracts without CoS/user approval.

---

## 1. Principles

1. **Photo is the material.** Chrome never competes with the image.
2. **Glass only on chrome** (nav, sheets, toolbars, select bar). Content cards, buttons, text fields, grids = **opaque**.
3. **Brutal-minimal:** hairlines, hard edges on media grid (radius 0), quiet type, no emoji, no indigo SaaS.
4. **Contrast first:** glass never fades text; raised controls stay opaque (Hermes glass rule).
5. **Parity:** same accent, same states, same copy tone on web and iOS. iOS tab tint = web accent (not yellow).

---

## 2. Tokens (both platforms)

| Token | Value | Use |
|-------|--------|-----|
| `bg` | `#0A0A0A` | App canvas |
| `raised` | `#141414` | Opaque panels, fields, toasts, dialogs |
| `raised-2` | `#1A1A1A` | Hover / pressed fill under chrome |
| `glass` | `rgba(10,10,10,0.72)` + `blur(24px)` + `saturate(1.8)` | Nav, sheets, select bar, filmstrip tray |
| `hairline` | `rgba(232,228,217,0.12)` | Borders, dividers |
| `text` | `#F4F1EA` | Primary |
| `muted` | `#8A8578` | Secondary |
| `accent` | `#E8E4D9` | Primary actions, selected tab, checks |
| `accent-ink` | `#0A0A0A` | Text on accent |
| `danger` | `#E24B4B` | Destructive |
| `success` | `#6FCF97` | Rare; upload done |
| `overlay` | `rgba(0,0,0,0.55)` | Modal backdrop |
| `viewer-bg` | `#000000` | Immersive viewer only |

**Radius:** grid tiles `0` · controls `6` · sheets/dialogs `8` · pills/avatars `full`  
**Space:** 4 / 8 / 12 / 16 / 24 / 32 · grid gutter `2`  
**Motion:** `160ms` ease-out · respect `prefers-reduced-motion` (instant opacity only)  
**Focus:** 2px `accent` ring, offset 2px  

**iOS mapping:** `Color(red:green:blue:)` from hex above; glass = `.ultraThinMaterial` darkened to match `glass`. Tab / tint = `accent`.

---

## 3. Typography

| Role | Web | iOS | Size / weight |
|------|-----|-----|----------------|
| Display (year sticky) | `Instrument Sans`, `Geist`, system-ui | SF Pro Display `.largeTitle` | 28–34 / semibold |
| Title (month, screen) | same | `.title2` | 20–22 / semibold |
| Body | SF Pro Text / Inter / system-ui | `.body` | 15–16 / regular |
| Caption | same | `.caption` | 12–13 / regular · `muted` |
| Mono (EXIF) | `ui-monospace`, SF Mono | `.caption` monospaced | 11–12 |

Tracking: display slight negative (−0.02em). No all-caps except rare badges.

---

## 4. Iconography

- **Stroke only**, 1.5–1.75 weight, 20–24px glyph, 44px touch.
- No emoji in nav, empty states, or actions.
- Shared metaphors: timeline, album, heart, trash, close, chevron, check, upload, download, share, search, more.
- Favorite = **heart** (not star) for Apple Photos parity.
- Web: inline SVG. iOS: SF Symbols (`photo`, `rectangle.stack`, `heart`, `trash`).

---

## 5. Components

### 5.1 App chrome (web)
- Sticky top bar: `glass` + hairline bottom. Height 56.
- Left: wordmark Lumen (tracking-tight).
- Nav: Timeline · Albums · Favorites · Trash. Selected = `accent` fill + `accent-ink`. Unselected = `muted`.
- Mobile (<768): **bottom tab bar** glass; hide top links.
- Logout in overflow / settings, not next to primary tabs.

### 5.2 iOS chrome
- `TabView`: Photos · Albums · Favorites · Settings. Tint `accent` (never yellow).
- Trash: Photos toolbar, not a fifth tab.
- Large titles on lists; inline on push.

### 5.3 Buttons
- Primary: `accent` bg, `accent-ink` text, radius 6, h 44.
- Ghost: transparent + hairline.
- Danger: `danger` fill or ghost-danger.
- Disabled: opacity 0.4.

### 5.4 Fields
- Opaque `raised`, hairline, radius 6–8, h 48. Focus → accent hairline (no glow).

### 5.5 Photo tile
- 1:1 crop, radius **0**, gutter 2.
- Select: accent check top-trailing; selected 88% or accent inset hairline.
- Fail: `raised` + hairline + «не загрузилось» + retry.
- Loading: skeleton pulse on `raised` — **no spinner in grid**.

### 5.6 Empty / Error / Toast / Confirm
- Empty: one `muted` line + one primary CTA. No illustrations.
- Error: hairline box, `danger` text, Retry.
- Toast: bottom, opaque `raised`, 160ms.
- Confirm: opaque `raised` sheet radius 8 (not glass), backdrop `overlay`.

### 5.7 Select bar
- Glass bottom bar when selection ≠ 0.
- Heart · В альбом · Удалить · count. Cancel leading.

---

## 6. Key screens

### 6.1 Auth (web + iOS)
- Full `bg`, column max 360.
- Aperture monoline in `accent` (favicon language) + wordmark + «Your photos, your server».
- Opaque fields; full-width primary CTA.
- Setup vs login: same layout, copy swap.
- iOS: Server URL first (editable). Web: readonly origin.
- **No** indigo circle logo.

### 6.2 Timeline
- Sticky: Year (display) → Month (title) → optional day captions.
- Grid: 3 col phone / 5–7 tablet / 7–8 desktop; gutter 2; radius 0.
- Trailing: Загрузить · Выбрать.
- DnD overlay (accent hairline); multi-file; toast + thin accent progress.
- Tap → immersive viewer. Long-press / Выбрать → select mode.

### 6.3 Immersive viewer
- **No app header.** Fullscreen `viewer-bg` `#000`.
- Letterbox photo; double-tap zoom; pinch; swipe H next/prev; swipe down dismiss.
- Top glass fade: Close · Heart · Download · Delete.
- Bottom glass **filmstrip** 64–72px, current = accent hairline.
- Web keys: Esc dismiss, ←/→ navigate.
- Not found: «Снимок не найден» + CTA Timeline.

### 6.4 Albums
- Cover grid radius 8 (exception; photo grids stay 0).
- Empty cover = raised + album stroke.
- Detail: same photo grid; inline title; **Add photos** = library select; remove in select mode.
- Create album: opaque sheet.

### 6.5 Favorites
- Same grid; heart to unfavorite; empty CTA → Timeline.

### 6.6 Trash
- Same grid at 0.7 opacity; Restore on tap/select.
- Toolbar: Очистить корзину (danger confirm). Copy «30 дней» when API exists.

### 6.7 Settings (iOS now, web later)
- Server URL, account, logout, storage hint. Dark-only v1.

---

## 7. Copy
- User-facing **RU** on the full redesign pass («Загрузить», «Удалить», «В альбом», «Корзина пуста», «Не загрузилось»).
- Kill mixed EN leftover from P0.

---

## 8. Implementation order (Dev)

1. Global tokens + kill indigo/emoji/yellow tint (web+iOS).
2. Auth reskin both.
3. Chrome: web responsive tabs + iOS TabView tint.
4. Timeline hierarchy + skeleton + AuthImage.
5. Immersive viewer (layout **without** shell header).
6. Select mode + glass bar + album add/remove UI.
7. Trash empty + Favorites parity.
8. DnD upload + toasts.
9. Stroke icon pass everywhere.
10. Research nitpick checklist + Designer review.

---

## 9. Acceptance

- [ ] No `#6366f1`, no emoji nav, no Svelte favicon, no yellow iOS tint
- [ ] Glass only on chrome; grids opaque; text readable through glass
- [ ] Empty ≠ error ≠ media-fail
- [ ] Viewer has zero main-nav chrome
- [ ] Date sticky hierarchy at 0 / 50 / 5000 photos (virtualize)
- [ ] Select → bulk favorite / album / delete
- [ ] Album add & remove in UI
- [ ] Web↔iOS same accent, heart favorite, trash semantics
- [ ] `prefers-reduced-motion` respected
- [ ] UI chrome text contrast ≥ WCAG AA
