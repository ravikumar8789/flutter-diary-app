# PIN Recovery Screen - Responsive Integration Plan

## Scope
- `PinRecoveryScreen` in `lib/screens/pin_recovery_screen.dart`.
- Layout-only; recovery logic unchanged.

## Current Layout Notes
- Uses height-based LayoutBuilder and dynamic spacing.
- Multiple steps with progress indicator.
- Fixed padding and card sizes.

## Integration Steps
1. Add width cap via `ResponsiveBody` or `ConstrainedBox`.
2. Replace fixed padding with responsive tokens.
3. Scale icons and text sizes with `ResponsiveInfo.value`.
4. Keep existing step logic and height-based spacing.

## Files to Touch
- `lib/screens/pin_recovery_screen.dart`

## Test Checklist
- Small phone: steps scroll without overflow.
- Tablet: centered content, readable spacing.

## Done Criteria
- Responsive layout, recovery flow unchanged.
