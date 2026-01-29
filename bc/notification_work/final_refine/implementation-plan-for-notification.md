# Notification Implementation Plan (Refine Only)

## Goal
- Keep the existing local notification system working.
- Only change messages, cancellation logic, and timezone handling as discussed.
- No other functionality or flows should change.

---

## Scope (What changes, what stays)

### Stays the same
- Local notifications only (no push).
- Android AlarmManager scheduling (survives reboot).
- Default morning time 7:00 AM (user can change in Settings).
- Active days logic remains unchanged.
- Reschedule on app start remains unchanged.

### Changes
- Morning reminders cancel based on diary completion.
- 9 PM reminder never cancels; message adapts based on diary state.
- Message rotation using Option 2 (days since epoch % 10).
- Remove timezone package usage (hardcoded India timezone).
- Ensure rescheduling happens on every `habits_daily` update.

---

## Implementation Steps

### 1. Review current notification flow
- Verify `NotificationService.scheduleAllNotifications()` is the single entry point.
- Confirm `NativeAlarmManager.scheduleAlarm()` is used for all scheduling.
- Confirm reschedule on restart uses stored times/titles/bodies.

### 2. Remove timezone handling
- Remove `timezone` imports from `notification_service.dart`.
- Remove `tz.initializeTimeZones()` and hardcoded `Asia/Kolkata`.
- Remove unused `_scheduleSingleNotification()` if not used anywhere.
- Keep scheduling based on `DateTime.now()` (device local time).

### 3. Add message rotation logic (Option 2)
- Create helper method:
  - `messageIndex = daysSinceEpoch % 10`
- Store 5 message arrays:
  - Morning (X time) – 10
  - +3 hours – 10
  - +6 hours – 10
  - 9 PM (Diary filled) – 10
  - 9 PM (Diary not filled) – 10
- Pick message by index at scheduling time.

### 4. Determine diary completion from habits data
- Use `habits_daily.wrote_entry` for diary status.
- Create helper to read today’s diary completion from local DB.
- Use this value to decide:
  - Cancel morning reminders if diary completed.
  - 9 PM message set based on diary completed or not.

### 5. Reschedule on every habits update
- After `habits_daily` update, call a new method:
  - `NotificationService.instance.rescheduleBasedOnHabits()`
- Rescheduling logic:
  - If diary completed: cancel morning alarms.
  - If diary not completed: schedule morning alarms.
  - Always schedule 9 PM with correct message set.

### 6. Keep persistence and reboot recovery
- Ensure every scheduled alarm stores:
  - time, title, body in SharedPreferences (already used).
- Reschedule on app restart remains unchanged, using stored values.

---

## Safe Integration Points (No other flows affected)
- Add reschedule call only in habit completion path:
  - After `trackTaskCompletion()` in `grace_system_service.dart`
  - Or after `_batchTrackGraceTasks()` in `entry_provider.dart`
- Do not touch unrelated providers, screens, or sync flows.
- No DB schema changes.

---

## Testing Checklist (Manual)
- New install: default 7:00 AM schedule.
- User changes morning time → X, X+3, X+6 updated correctly.
- Diary completed early → morning reminders canceled.
- Diary not completed → morning reminders remain.
- 9 PM always scheduled:
  - Diary not filled → message from "not filled" list.
  - Diary filled → message from "filled" list.
- App restart → alarms still fire.
- Device timezone change → schedules based on local time after next habit update.

---

## No Regression Guarantee
- Do not modify any unrelated features or workflows.
- Keep all existing notification settings, preferences, and UI behavior.