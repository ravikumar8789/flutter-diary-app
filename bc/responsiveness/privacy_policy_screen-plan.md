# Privacy Policy Screen - Responsive Integration Plan

## Scope
- `PrivacyPolicyScreen` in `lib/screens/privacy_policy_screen.dart`.
- Layout-only; text content unchanged.

## Current Layout Notes
- Uses `isTablet` padding and `ConstrainedBox(maxWidth: 800)`.
- Bullet list uses `Row` + `Expanded`.

## Integration Steps
1. Replace padding/constrained box with `ResponsiveBody`.
2. Use token spacing between sections.
3. Ensure bullets wrap cleanly on compact widths.

## Files to Touch
- `lib/screens/privacy_policy_screen.dart`

## Test Checklist
- Small phone: bullets wrap without overflow.
- Tablet: centered text with max width cap.

## Done Criteria
- Responsive layout, content unchanged.
