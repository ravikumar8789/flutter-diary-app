# My Tickets Screen - Responsive Integration Plan

## Scope
- `MyTicketsScreen` in `lib/screens/my_tickets_screen.dart`.
- Layout-only; ticket loading and bottom sheet unchanged.

## Current Layout Notes
- List uses fixed padding (16) and card spacing.
- Header row in cards uses `Row` + `Spacer`.
- Bottom sheet uses fixed padding and fixed height ratios.

## Integration Steps
1. Replace list padding with token spacing.
2. Use `ResponsiveBody`/max width cap for list on tablet.
3. Convert card header row to `ResponsiveWrapRow` on compact if needed.
4. Update bottom sheet padding and handle width cap on tablets.
5. Keep list behavior and pull-to-refresh intact.

## Files to Touch
- `lib/screens/my_tickets_screen.dart`

## Test Checklist
- Small phone: card rows and badges do not overflow.
- Tablet: list centered with max width cap.
- Bottom sheet: comfortable padding on all sizes.

## Done Criteria
- Responsive list and sheet, no behavior changes.
