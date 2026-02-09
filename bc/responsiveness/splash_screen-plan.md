# Splash Screen - Responsive Integration Plan

## Scope
- `SplashScreen` in `lib/screens/splash_screen.dart`.
- Layout-only; startup logic unchanged.

## Current Layout Notes
- Uses fixed sizes for logo container (140), icon (70), and text (36).
- Large fixed vertical spacing.

## Integration Steps
1. Use `ResponsiveInfo` to scale logo/icon/text sizes.
2. Replace fixed spacing with token spacing based on screen height.
3. Cap max width for text to avoid overly wide lines on tablets.
4. Keep animation and startup flow unchanged.

## Files to Touch
- `lib/screens/splash_screen.dart`

## Test Checklist
- Small phone: logo and text fit without clipping.
- Tablet: centered layout, balanced spacing.

## Done Criteria
- Responsive layout, startup flow unchanged.
