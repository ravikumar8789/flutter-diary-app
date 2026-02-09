# Profile Screen - Responsive Integration Plan

## Scope
- `ProfileScreen` in `lib/screens/profile_screen.dart`.
- Layout-only; profile actions unchanged.

## Current Layout Notes
- Uses `isTablet` + `ConstrainedBox(maxWidth: 800)`.
- Avatar and stats use fixed sizes.
- Stats section uses `Row` with two cards.

## Integration Steps
1. Wrap content with `ResponsiveBody`.
2. Use token spacing for vertical gaps.
3. Convert stats `Row` to `ResponsiveWrapRow` on compact.
4. Scale avatar size with `ResponsiveInfo.value`.
5. Keep bottom navigation bar unchanged.

## Files to Touch
- `lib/screens/profile_screen.dart`

## Test Checklist
- Small phone: stats wrap and text fits.
- Tablet: centered content, proper spacing.

## Done Criteria
- Responsive layout, profile actions unchanged.
