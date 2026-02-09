# Terms Screen - Responsive Integration Plan

## Scope
- `TermsScreen` in `lib/screens/terms_screen.dart`.
- Layout-only; text content unchanged.

## Current Layout Notes
- Uses `isTablet` padding and `ConstrainedBox(maxWidth: 800)`.
- Sections are stacked with fixed spacing.

## Integration Steps
1. Replace padding/constrained box with `ResponsiveBody`.
2. Use token spacing between sections.
3. Ensure section text wraps cleanly on compact.

## Files to Touch
- `lib/screens/terms_screen.dart`

## Test Checklist
- Small phone: text wraps without overflow.
- Tablet: centered text with max width cap.

## Done Criteria
- Responsive layout, content unchanged.
