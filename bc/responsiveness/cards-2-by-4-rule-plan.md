# Cards 2x2 / 4x1 Rule - Plan

## Goal
- For summary cards: force **2 columns** when width < 900, **4 columns** when width ≥ 900.
- Avoid the 3+1 layout and reduce text overflow risk.

## Where to Change
- `lib/ui/responsive/responsive_grid.dart`

## Plan
1. Add helper:
   - `int responsiveCardCrossAxisCount(ResponsiveInfo info)`
   - Returns `2` for compact + medium, `4` for expanded.
2. Add grid delegate helper:
   - `SliverGridDelegateWithFixedCrossAxisCount responsiveCardGridDelegate(...)`
   - Uses crossAxisCount from the helper, plus spacing + childAspectRatio.
3. Update analytics + home summary cards to use this delegate.
4. Keep existing `responsiveGridDelegate` for other grids.

## Notes
- This is layout-only; no logic changes.
- Use in cards where 2x2 or 4x1 is desired.