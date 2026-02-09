# Help & Support Screen - Responsive Integration Plan

## Scope
- `HelpSupportScreen` in `lib/screens/help_support_screen.dart`.
- Layout only; no changes to form submission or navigation.

## Current Layout Notes
- Uses `isTablet` padding + `ConstrainedBox(maxWidth: 800)`.
- Form fields and cards are in a single column.
- Action icon in AppBar for My Tickets.

## Integration Steps
1. Replace padding + constrained box with `ResponsiveBody`.
2. Use token spacing for vertical gaps (replace fixed 20/24).
3. Ensure dropdown/fields stretch full width in compact.
4. For tablet, cap width via `ResponsiveBody` max width.
5. If AppBar actions overflow on compact, reduce icon size or use tooltip only.

## Files to Touch
- `lib/screens/help_support_screen.dart`

## Test Checklist
- Small phone: form scrolls without overflow.
- Large phone: consistent spacing.
- Tablet: centered column with max width cap.

## Done Criteria
- No overflow, clean spacing.
- Form behavior unchanged.