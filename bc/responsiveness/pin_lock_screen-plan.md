# PIN Lock Screen - Responsive Integration Plan

## Scope
- `PinLockScreen` in `lib/screens/pin_lock_screen.dart`.
- Layout-only; PIN validation unchanged.

## Current Layout Notes
- Uses height-based LayoutBuilder for spacing.
- Fixed sizes for icon, dots, and keypad.
- No width-based constraints.

## Integration Steps
1. Add width cap using `ResponsiveBody` or `ConstrainedBox`.
2. Replace fixed padding with responsive tokens.
3. Scale dot size and icon size with `ResponsiveInfo.value`.
4. Keep existing height-based spacing for very small screens.
5. Ensure `PinNumberPad` fits on compact widths.

## Files to Touch
- `lib/screens/pin_lock_screen.dart`
- `lib/widgets/pin_number_pad.dart` only if needed.

## Test Checklist
- Small phone portrait/landscape: keypad fits without overflow.
- Tablet: centered with max width cap.

## Done Criteria
- Responsive layout, PIN flow unchanged.
