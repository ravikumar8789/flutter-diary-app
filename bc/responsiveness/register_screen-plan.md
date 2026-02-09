# Register Screen - Responsive Integration Plan

## Scope
- `RegisterScreen` in `lib/screens/register_screen.dart`.
- Layout only; signup flow unchanged.

## Current Layout Notes
- Uses `isTablet` for padding and maxWidth (500).
- Long form with fixed spacing.
- Center + `SingleChildScrollView`.

## Integration Steps
1. Replace padding/constrained box with `ResponsiveBody(useScrollView: true)`.
2. Use token spacing for form sections.
3. Scale top title/subtitle spacing on compact.
4. Keep form fields full width; avoid side-by-side fields.
5. Preserve dialog and error handling.

## Files to Touch
- `lib/screens/register_screen.dart`

## Test Checklist
- Small phone: no overflow, keyboard scroll works.
- Tablet: centered form, width capped.

## Done Criteria
- Responsive layout, signup flow unchanged.
