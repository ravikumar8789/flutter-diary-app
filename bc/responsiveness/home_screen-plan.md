# Home Screen - Responsive Integration Plan

## Scope
- `HomeScreen` in `lib/screens/home_screen.dart`.
- Layout only; keep all data loading, prefetch, and navigation intact.

## Current Layout Notes
- Uses `isTablet = width > 600` for padding and card sizing.
- Multiple fixed `Row` sections and fixed `SizedBox` spacing.
- Summary skeleton uses `GridView.count` with fixed aspect ratio.
- Streak and metrics sections use hard-coded padding and row layouts.
- Some card widths use `LayoutBuilder` and `Wrap` already.

## Integration Steps
1. Base layout
   - Replace `SingleChildScrollView` padding with `ResponsiveBody(useScrollView: true)`.
   - Replace fixed `SizedBox` spacing with `ResponsiveTokens`.
2. Summary skeleton + metrics grids
   - Replace `GridView.count` with `responsiveGridDelegate`.
   - Use `gridMinTileWidth` and token spacing.
3. Streak section + "This Week" cards
   - Replace tight `Row` with `ResponsiveWrapRow` on compact.
   - Ensure icons + text stack properly on small widths.
4. Grace system and info cards
   - Keep existing maxWidth constraints but align within `ResponsiveBody`.
5. Cards with internal rows (mood/self-care)
   - Convert inner `Row` to `Wrap` if overflow occurs in compact.
6. Debug bottom sheet (temporary)
   - Ensure sheet container uses responsive padding and max width (no behavior change).

## Files to Touch
- `lib/screens/home_screen.dart`
- Optional: `lib/widgets/grace_system_info_card.dart` if layout still overflows.

## Test Checklist
- Small phone portrait: no overflow in streak/metrics/cards.
- Small phone landscape: wrap rows correctly.
- Tablet: content centered, spacing balanced.

## Done Criteria
- No overflow/clipping on phone/tablet.
- Prefetch/loading behavior unchanged.
