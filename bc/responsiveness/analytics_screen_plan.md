# Analytics Screen - Responsive Integration Plan

## Goals
- Make analytics screen responsive for phone + tablet (portrait/landscape).
- Use new shared responsive utilities.
- Keep all data/providers/navigation unchanged.

## Current Layout Notes
- Uses `isTablet = width > 600` for padding and grid counts.
- Summary cards use `GridView.count` with fixed `crossAxisCount`.
- Monthly stats row uses fixed `Row` with 4 items.
- Charts use fixed height (250).
- AppBar action uses `SegmentedButton` inside AppBar (can overflow on small).

## Integration Steps
1. Wrap body with `ResponsiveBody`
   - Replace `SingleChildScrollView` padding with `ResponsiveBody` tokens.
   - Keep `SingleChildScrollView` but use `ResponsiveBody(useScrollView: true)`.
2. AppBar actions
   - Use `ResponsiveAppBarActions`.
   - Regular: keep `SegmentedButton`.
   - Compact: swap to `PopupMenuButton` with Weekly/Monthly options.
3. Summary cards
   - Replace `GridView.count` with `GridView.builder` + `responsiveGridDelegate`.
   - Use `ResponsiveTokens.gridMinTileWidth` and spacing tokens.
   - Keep card content unchanged.
4. Monthly stats row
   - Replace fixed `Row` with `ResponsiveWrapRow`.
   - Compact: Wrap items; Medium/Expanded: Row.
5. Charts
   - Wrap `LineChart` and `InteractiveBarChart` with `ResponsiveChartBox`.
   - Use `AspectRatio` on tablets if needed, or height token on compact.
6. AI insights cards
   - Constrain width using `ResponsiveBody` max width.
   - Use token spacing in vertical sections (replace fixed 24/32).
7. Spacing cleanup
   - Replace `SizedBox(height: 24/32)` with token spacing from `ResponsiveTokens`.
   - Keep logic and structure intact.

## Widgets to Touch (No Behavior Change)
- `lib/screens/analytics_screen.dart`
- Maybe update `lib/widgets/interactive_bar_chart.dart` only if overflow remains.

## Test Checklist
- Small phone (360x640) portrait/landscape: no AppBar overflow.
- Large phone (412x915): summary grid wraps correctly.
- Small tablet (600x960): 2-3 cards per row, stats row stays in one line.
- Tablet (800x1280): max width cap works, charts scale well.

## Done Criteria
- No overflow/clipping on phone/tablet.
- Navigation + providers unchanged.
- Visual rhythm consistent with tokens.