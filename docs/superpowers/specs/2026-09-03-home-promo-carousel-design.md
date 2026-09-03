# Home Promo Banner Carousel — Design

## Goal
Replace the static promo banner on the customer app home screen
([mobile/lib/screens/home/home_screen.dart](../../../mobile/lib/screens/home/home_screen.dart))
with an auto-sliding carousel of 3 promo slides, in this fixed order:

1. ติดฟิล์มกรองแสง (keyword `ฟิล์ม`)
2. ซ่อมรอยร้าวกระจก (keyword `ซ่อม`)
3. ล้างรถครบวงจร (keyword `ล้าง`)

Real promo images are not ready yet — build the carousel mechanics now with a
placeholder look; swapping in real images later is a follow-up.

## Component
`_PromoCarousel` (new `StatefulWidget`), replacing `_Banner` in the same file
(kept in `home_screen.dart` because it needs `_HomeScreenState._matchService`
for CTA routing — same pattern as `_QuickActionsRow`).

Slide data is a hardcoded `const List<_PromoSlide>` (title, subtitle, icon,
keyword) — same pattern as the existing `_quickActions` list.

## Mechanics
- `PageView.builder` + `PageController`, infinite loop via modulo index.
- `Timer.periodic(5s)` auto-advances to the next page.
- User can swipe manually; `onPageChanged` (fired by both auto-advance and
  manual swipe) resets the 5s timer so a manual swipe doesn't get
  immediately overridden by the pending auto-advance.
- Dot indicator row below the banner shows current slide position.
- Each slide's "จองเลย" button calls
  `widget.onBookService?.call(_matchService(slide.keyword))` — same routing
  behavior as the quick-action cards, so it deep-links into the matching
  service's booking flow instead of the generic booking flow.
- `Timer` is cancelled in `dispose()`.

## Visual placeholder (until real images arrive)
- Fixed height 190dp (up from the old banner's ~150dp content-driven height)
  to leave room for a future full-bleed image.
- All 3 slides use the same `AppColors.primary` red background; only the
  icon, title, and subtitle differ per slide.
- When real images are added later, the background will be replaced with
  `Image` widgets inside the same slide structure — the height/layout
  should not need to change.

## Testing
Widget tests in `mobile/test/`:
- Renders the first slide's title/subtitle/icon.
- Tapping "จองเลย" on a given slide invokes the booking callback with the
  service matched by that slide's keyword.
- Manual swipe changes the displayed slide.
- Auto-advance timer itself is not asserted on (would slow down the test
  suite); only wiring (timer created/cancelled) is exercised indirectly via
  the above interaction tests plus `dispose()` not throwing.
