# Auth Wrapper - Responsive Integration Plan

## Scope
- `AuthWrapper` and internal `AuthLoadingScreen` in `lib/screens/auth_wrapper.dart`.
- Focus on layout only; keep auth flow and provider logic intact.

## Current Layout Notes
- `AuthWrapper` routes to `HomeScreen` or `LoginScreen`.
- `AuthLoadingScreen` uses a centered column with default sizing.
- No responsiveness logic currently.

## Integration Steps
1. Keep `AuthWrapper` logic unchanged.
2. Update `AuthLoadingScreen` layout to use responsive tokens:
   - Wrap body with `ResponsiveBody` (centered, max width).
   - Use token spacing for vertical gaps.
   - Optionally scale icon/text sizes via `ResponsiveInfo.value`.
3. Ensure `CircularProgressIndicator` stays centered on all sizes.

## Files to Touch
- `lib/screens/auth_wrapper.dart` only (layout for loading state).

## Test Checklist
- Small phone: loading screen centered, no overflow.
- Tablet: loading screen not too wide, spacing consistent.

## Done Criteria
- Loading screen looks consistent on phone + tablet.
- No changes to auth navigation or provider behavior.