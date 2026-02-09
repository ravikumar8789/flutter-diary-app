# History Screen - Responsive Integration Plan

## Scope
- `HistoryScreen` in `lib/screens/history_screen.dart`.
- Layout only; keep provider logic, filters, and navigation intact.

## Current Layout Notes
- Uses `isTablet = width > 600` for padding.
- Header uses fixed padding and a `Row` with text + clear filter button.
- Mood chips use a `Row` with many `Expanded` chips (risk of tight layout on compact).
- List view and calendar view use fixed padding.
- Bottom sheets use fixed height ratios and fixed padding (24).

## Integration Steps
1. Base layout
   - Replace hard-coded paddings with `ResponsiveTokens` (header, list, calendar).
   - Keep `SafeArea` and `Column` structure unchanged.
2. Header section
   - Wrap header `Row` into `ResponsiveWrapRow` for compact.
   - Use token spacing for horizontal/vertical padding.
3. Mood chips
   - Replace `Row + Expanded` with `Wrap` on compact or
     `SingleChildScrollView` horizontal for compact screens.
   - Keep chip styles and logic unchanged.
4. List view / calendar view
   - Use token-based padding.
   - For list cards, consider max width cap via `ResponsiveBody` pattern if needed.
5. Calendar + day tiles
   - Ensure `TableCalendar` has responsive cell sizes on compact.
   - Avoid fixed text sizes if they overflow in landscape.
6. Bottom sheets
   - Use responsive height ratios (compact: smaller, tablet: larger).
   - Replace fixed padding `24` with token spacing.
   - Optional: cap sheet content width on tablet.

## Files to Touch
- `lib/screens/history_screen.dart`

## Test Checklist
- Small phone portrait: mood chips and header do not overflow.
- Small phone landscape: list and calendar remain readable.
- Tablet: padding and widths look balanced, bottom sheet not too narrow/wide.

## Done Criteria
- No overflow/clipping on phone/tablet.
- Filters, list/calendar switch, and bottom sheets work unchanged.
