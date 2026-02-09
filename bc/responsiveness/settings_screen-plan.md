# Settings Screen - Responsive Integration Plan

## Scope
- `SettingsScreen` in `lib/screens/settings_screen.dart`.
- Layout-only; settings logic unchanged.

## Current Layout Notes
- Uses `isTablet` + `ConstrainedBox(maxWidth: 800)`.
- Fixed padding and section spacing.
- Reminder days chips already use `Wrap`.

## Integration Steps
1. Replace padding/constrained box with `ResponsiveBody`.
2. Use token spacing between sections and cards.
3. Ensure ListTile text wraps properly on compact.
4. Keep chips layout; adjust spacing with tokens.

## Files to Touch
- `lib/screens/settings_screen.dart`

## Test Checklist
- Small phone: no overflow in tiles or chips.
- Tablet: balanced spacing and centered content.

## Done Criteria
- Responsive layout, settings behavior unchanged.
