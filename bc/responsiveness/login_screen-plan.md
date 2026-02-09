# Login Screen - Responsive Integration Plan

## Scope
- `LoginScreen` in `lib/screens/login_screen.dart`.
- Layout-only; auth flow and listeners unchanged.

## Current Layout Notes
- Uses `isTablet` for padding and maxWidth (500).
- Fixed icon size and large spacing blocks.
- `Stack` + `SingleChildScrollView` inside `SafeArea`.

## Integration Steps
1. Replace manual padding/constrained box with `ResponsiveBody(useScrollView: true)`.
2. Use token spacing instead of fixed 24/48 values.
3. Scale logo/icon size with `ResponsiveInfo.value`.
4. Keep fields/buttons full width on compact screens.
5. Preserve loading overlay and auth listener behavior.

## Files to Touch
- `lib/screens/login_screen.dart`

## Test Checklist
- Small phone: no overflow, keyboard scroll works.
- Tablet: centered column with max width cap.

## Done Criteria
- Responsive layout, no auth flow changes.
