# Change PIN Screen - Responsive Integration Plan

## Scope
- `ChangePinScreen` in `lib/screens/change_pin_screen.dart`.
- Layout only; keep PIN logic intact.

## Current Layout Notes
- Likely uses fixed padding and column layout.
- PIN keypad size may not scale on small/large phones.

## Integration Steps
1. Wrap body with `ResponsiveBody` (centered, max width).
2. Use responsive spacing tokens for vertical gaps.
3. Constrain keypad width with `ConstrainedBox` + token max width.
4. Ensure title/subtitle text scales via `ResponsiveInfo.value` if needed.
5. Keep all callbacks and validation logic unchanged.

## Files to Touch
- `lib/screens/change_pin_screen.dart`
- `lib/widgets/pin_number_pad.dart` only if keypad overflow occurs.

## Test Checklist
- Small phone: keypad fits, no overflow.
- Large phone: spacing looks balanced.
- Tablet: content centered with max width cap.

## Done Criteria
- No overflow on phone/tablet.
- PIN flow unchanged.