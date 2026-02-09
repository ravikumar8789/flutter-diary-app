# New Diary Screen - Responsive Integration Plan

## Scope
- `NewDiaryScreen` in `lib/screens/new_diary_screen.dart`.
- Layout-only; entry load/save and autosave unchanged.

## Current Layout Notes
- Single column with fixed padding (20) and many fixed gaps (24).
- Mood selector uses fixed 56x56 boxes in a `Row`.
- Many sections use `Row` headers and fixed content padding.
- No responsive logic currently.

## Integration Steps
1. Wrap body with `ResponsiveBody(useScrollView: true)`.
2. Replace fixed spacing (24) with `ResponsiveTokens`.
3. Mood selector:
   - Use `Wrap` on compact, `Row` on medium/expanded.
   - Reduce tile size on compact via `ResponsiveInfo.value`.
4. Long text areas:
   - Cap max width on tablet.
   - Keep input padding consistent via tokens.
5. Sections with multiple fields (affirmations, priorities, gratitude):
   - Use `Wrap`/grid on tablet if safe, single column on compact.
6. Keep all autosave listeners and providers unchanged.

## Files to Touch
- `lib/screens/new_diary_screen.dart`

## Test Checklist
- Small phone portrait/landscape: no overflow in mood row and forms.
- Tablet: content centered and readable.

## Done Criteria
- Responsive layout without changing data flow.
