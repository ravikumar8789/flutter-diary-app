# Monthly Graph Enhancement Plan (Mood Trend by Day)

## Goal
- Replace the **monthly 4-week mood line** with a **daily mood trend line (day 1 → last day)**.
- Keep **all other functionality unchanged** (cards, AI insights, navigation, providers).
- Ensure **touch/slide** on the chart does not block vertical screen scrolling.
- Follow existing **responsive architecture** (`ResponsiveBody`, `ResponsiveChartBox`, tokens).

## Reference (fl_chart sample)
Use ideas from `line_chart_sample13.dart`:
- X-axis is **day of month**, Y-axis is **value**.
- `LineTouchData` with `handleBuiltInTouches: false` + custom callback to highlight day.
- Bottom titles show **every 5 days**, and **always show hovered day**.

## Data Source (No new fetch)
- Monthly analytics already fetches **entries with `entry_date` + `mood_score`**.
- Build **daily points** from this list:
  - For each day in month, use the mood score from entries (avg if multiple).
  - If no entry that day, **skip point** (no fake 0).

## Chart Design (Daily Mood Trend)
- X-axis: **day number** (1..daysInMonth)
- Y-axis: **mood scale** (1..5)
- Line style: **straight or light curve**, dot visibility minimal.
- Bottom title rule: show every 5 days (and hovered day).
- Tooltip/hover: show **Day + Mood** on touch.

## Touch + Gesture (Don’t block vertical scroll)
- Use `LineTouchData` with:
  - `enabled: true`
  - `handleBuiltInTouches: false`
  - `touchCallback` to track hovered day
- Only react to **tap/long-press move** events.
- Do **not** handle pan/drag gestures manually (let scroll win).
- If scroll conflict appears, fallback to **tap-only** tooltips.

## Responsiveness (From existing architecture)
- Wrap chart in `ResponsiveChartBox`.
- Use `ResponsiveInfo` to adjust:
  - Chart height/aspect ratio
  - Bottom label interval (compact: 5, medium: 3, expanded: 1)
  - Axis label font size
- Keep spacing via `ResponsiveTokens`.

## Implementation Steps
1. **AnalyticsService (monthly)**  
   - Replace weekly `moodTrendData` with **daily points**:
     - `minX = 1`, `maxX = daysInMonth`
     - `FlSpot(x = dayOfMonth, y = moodScore)`
2. **AnalyticsScreen**
   - Update `_buildMoodChart` to:
     - Use day-of-month labels
     - Apply `LineTouchData` similar to sample
     - Show hover day label + tooltip
3. **Axis + Labels**
   - Bottom titles: show 1, 5, 10, 15... and hovered day
   - Y-axis: 1–5 with clear ticks
4. **Edge Cases**
   - No mood data: show empty state card (existing behavior)
   - Sparse data: line connects existing points only

## Safety / Non-Goals
- No DB changes, no provider changes, no AI changes.
- Only monthly chart behavior changes.
- Weekly analytics and other screens remain untouched.

## Testing Checklist
- Small phone: labels don’t overlap; scroll still works.
- Large phone/tablet: labels show more days (interval adapts).
- Touch: tooltip + hovered day works; vertical scroll unaffected.
- Empty month: “No mood data” state.

## Done Criteria
- Daily mood trend renders correctly for 28–31 days.
- Touch/slide is smooth and does not block page scroll.
- Responsive layout matches existing app standards.