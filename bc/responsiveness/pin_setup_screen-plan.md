# PIN Setup Screen - Responsive Integration Plan

## Scope
- `PinSetupScreen` in `lib/screens/pin_setup_screen.dart`.
- Layout-only; PIN creation flow unchanged.

## Current Layout Notes
- Uses height-based LayoutBuilder for spacing.
- Fixed icon/dot sizes and keypad.
- No width-based constraints.

## Integration Steps
1. Add width cap via `ResponsiveBody` or `ConstrainedBox`.
2. Replace fixed padding with responsive tokens.
3. Scale icon/dots with `ResponsiveInfo.value`.
4. Keep existing height-based spacing logic for tiny screens.
5. Ensure keypad fits on compact widths.

## Files to Touch
- `lib/screens/pin_setup_screen.dart`
- `lib/widgets/pin_number_pad.dart` only if needed.

## Test Checklist
- Small phone: keypad and dots fit.
- Tablet: centered layout with max width cap.

## Done Criteria
- Responsive layout, setup flow unchanged.
