# Yesterday Insight Screen - Responsive Integration Plan

## Scope
- `YesterdayInsightScreen` in `lib/screens/yesterday_insight_screen.dart`.
- Layout-only; insight content unchanged.

## Current Layout Notes
- Uses fixed padding (16) and fixed spacing.
- Header uses `Row` with icon and date text.
- Detail cards have fixed padding.

## Integration Steps
1. Wrap body with `ResponsiveBody(useScrollView: true)` and max width cap.
2. Replace fixed spacing with token spacing.
3. Ensure header row wraps on compact (use `ResponsiveWrapRow` if needed).
4. Keep detail card layout unchanged.

## Files to Touch
- `lib/screens/yesterday_insight_screen.dart`

## Test Checklist
- Small phone: header and cards wrap without overflow.
- Tablet: centered content with max width cap.

## Done Criteria
- Responsive layout, insight rendering unchanged.
