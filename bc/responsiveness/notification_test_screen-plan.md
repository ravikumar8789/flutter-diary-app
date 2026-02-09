# Notification Test Screen - Responsive Integration Plan

## Scope
- `NotificationTestScreen` in `lib/screens/notification_test_screen.dart`.
- Layout-only; test actions unchanged.

## Current Layout Notes
- Single column with fixed padding (16) and many fixed gaps.
- Long status text and monospaced scheduled times.
- Buttons are full width using `SizedBox(width: double.infinity)`.

## Integration Steps
1. Wrap body with `ResponsiveBody(useScrollView: true)`.
2. Use token spacing for gaps between cards/buttons.
3. Constrain max width on tablet to keep text readable.
4. Ensure long status text wraps on compact.

## Files to Touch
- `lib/screens/notification_test_screen.dart`

## Test Checklist
- Small phone: long text wraps without overflow.
- Tablet: content centered with max width cap.

## Done Criteria
- Responsive layout, test actions unchanged.
