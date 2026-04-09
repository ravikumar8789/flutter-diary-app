# Morning Notification Change Plan (Final Locked)

## 1) Final Scope
- Morning notification intent changes to: "yesterday analysis is ready".
- Daily target changes from 4 notifications to 3 notifications.
- Keep bedtime notification behavior unchanged.
- Do not alter unrelated features.

## 2) Final Daily Notification Structure
- Morning at user-selected time (`morningReminder1Id`): analysis-ready message.
- Follow-up at `+6h` (`morningReminder3Id`): reminder message.
- Bedtime at night (`bedtimeReminderId`): existing diary reminder.
- `+3h` reminder (`morningReminder2Id`) is removed from active scheduling.

## 3) Locked Morning Copy (Only First Morning Set)
- Update only `_morningTitles` and `_morningBodies`.
- Keep 10 pairs to match existing `% 10` rotation behavior.

1. Title: "Yesterday analysis is ready ✨" | Body: "Tap to view your key insight."
2. Title: "Your insight is ready 📊" | Body: "See what yesterday reveals."
3. Title: "Report ready for yesterday 🧠" | Body: "Open your personalized summary."
4. Title: "Daily analysis is live 🌅" | Body: "Check yesterday’s trends now."
5. Title: "New insight unlocked 🔍" | Body: "Tap to view yesterday’s analysis."
6. Title: "Your pattern report is ready 📈" | Body: "See highlights from yesterday."
7. Title: "Analysis complete ✅" | Body: "Your yesterday insight is waiting."
8. Title: "Reflection insight ready 💡" | Body: "Tap to check your day pattern."
9. Title: "Yesterday breakdown ready 🌟" | Body: "Open and review your summary."
10. Title: "Insight card is ready 📝" | Body: "View yesterday’s analysis now."

## 4) +6h Guard Rule (Locked)
- Add 3-hour bedtime proximity check for `+6h` reminder:
  - Skip if `+6h` is after or equal to bedtime.
  - Skip if time gap to bedtime is less than 3 hours.
- Purpose: prevent evening clustering and notification fatigue.

## 5) Cancellation Logic (Locked)
- Keep existing cancellation coverage for all morning IDs: `1001`, `1002`, `1003`.
- Keep cancellation in:
  - `cancelMorningReminders()`
  - `_cancelDayAlarms(...)`
- Keep reminder2 (`1002`) metadata cleanup logic intact.
- Reason: users may already have legacy `+3h` alarms; cancel path must clean them safely.

## 6) `today_analysis_seen` Refinement (Phase 2, Optional)
- Add `today_analysis_seen` SharedPreferences flag for advanced behavior.
- Mark `true` only when user views yesterday insight in valid window:
  - after local midnight,
  - before morning notification time,
  - insight exists and is for yesterday.
- Reset to `false` on date change.
- Use as guard to skip/cancel same-day morning reminders when already seen.

## 7) Files Expected to Change
- `lib/services/notification_service.dart`
  - morning copy arrays
  - remove `+3h` scheduling block
  - add `+6h` 3-hour bedtime guard
  - keep existing cancel/cleanup for legacy reminder2
  - optional Phase 2: `today_analysis_seen` logic
- Optional fallback wording only:
  - `android/app/src/main/kotlin/com/zen/diaryapp/NotificationReceiver.kt`

## 8) Validation Checklist
- Morning copy shows analysis-ready messaging.
- `+3h` is no longer scheduled.
- `+6h` is skipped when within 3 hours of bedtime.
- Bedtime behavior remains unchanged.
- Legacy `+3h` alarms get cancelled/cleaned properly.
