# Security Questions Screen - Responsive Integration Plan

## Scope
- `SecurityQuestionsScreen` in `lib/screens/security_questions_screen.dart`.
- Layout-only; question save logic unchanged.

## Current Layout Notes
- Uses height-based LayoutBuilder and fixed padding.
- Form fields are single column with fixed spacing.
- Info row uses `Row` with icon + text.

## Integration Steps
1. Replace padding with `ResponsiveBody(useScrollView: true)`.
2. Use token spacing for vertical gaps.
3. Scale icon/text sizes with `ResponsiveInfo.value` where needed.
4. Ensure fields remain full width on compact.

## Files to Touch
- `lib/screens/security_questions_screen.dart`

## Test Checklist
- Small phone: form scrolls without overflow.
- Tablet: centered with max width cap.

## Done Criteria
- Responsive layout, security flow unchanged.
