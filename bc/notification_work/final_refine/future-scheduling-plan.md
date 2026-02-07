Future Scheduling Plan (10-Day Window)
======================================

Goal
----
Implement simple future scheduling without changing the current user flow:
- On app start: cancel all alarms, schedule next 10 days.
- On settings change: cancel all alarms, schedule next 10 days.
- Keep today's reschedule based on diary status working.

Current Code (Key Points)
-------------------------
- `initialize()` calls `_rescheduleAlarmsOnRestart()` only.
- `scheduleAllNotifications()` schedules only for today and may shift to tomorrow if time passed.
- `_scheduleMorningNotifications()` and `_scheduleBedtimeNotification()` use fixed IDs (1001, 1002, 1003, 2001).
- Metadata keys are `alarm_{id}_time/title/body` (no date).
- `updateNotificationSettings()` only calls `_notifications.cancelAll()` (Flutter), not native alarms.
- Android `RescheduleReceiver` and Dart `_rescheduleAlarmsOnRestart()` assume fixed IDs and fixed keys.

Decision (Simple + Reliable)
----------------------------
No gap tracking. No daily recalculation of all future days.
- Always schedule a 10-day window on app start and settings change.
- Use deterministic per-day IDs to avoid collisions.
- Store metadata with date in key to support reboot reschedule.
- Keep today's status-based scheduling, but do not schedule "tomorrow" with today IDs.

ID Strategy (No Collision)
--------------------------
Use stable, per-day IDs for the 10-day window:
- Base IDs: morning1=1001, morning2=1002, morning3=1003, bedtime=2001
- Formula: `id = baseId + (dayOffset * 10)`
  - Day 0: 1001, 1002, 1003, 2001
  - Day 1: 1011, 1012, 1013, 2011
  - Day 9: 1091, 1092, 1093, 2091

Metadata Keys (Date-based)
--------------------------
Store metadata with date to support reboot reschedule:
- `alarm_{id}_{yyyy-MM-dd}_time`
- `alarm_{id}_{yyyy-MM-dd}_title`
- `alarm_{id}_{yyyy-MM-dd}_body`

Implementation Steps
--------------------
1. Add constants and helpers in `notification_service.dart`
   - `const int kFutureDays = 10;`
   - `_alarmIdForDay(int baseId, int dayOffset)`
   - `_formatDate(DateTime date)` -> `yyyy-MM-dd`
   - `_isActiveDay(DateTime date, List<int> activeDays)` (date-specific check)

2. Add window scheduling methods
   - `Future<void> scheduleFutureWindow({String? userId})`
     - Cancel current 10-day native alarms first.
     - Read settings; return if disabled.
     - Loop `dayOffset 0..9`:
       - `targetDate = today + dayOffset`
       - Skip if not active day.
       - For day 0: check diary status.
       - For day 1..9: assume not completed.
       - Schedule alarms using date-based IDs and date-based metadata keys.
     - Do NOT shift today’s alarms to tomorrow. If morning time already passed, skip morning for today.

3. Add cancel helper for the window
   - `Future<void> cancelFutureWindow()`:
     - Loop `dayOffset 0..9` and cancel 4 IDs for each day.
     - Remove date-based metadata keys for those dates.
   - Keep `cancelMorningReminders()` / `cancelBedtimeReminder()` but update them to use today’s date-based IDs.

4. Update existing scheduling calls
   - `initialize()`:
     - Call `scheduleFutureWindow()` after channel creation (and after any init checks).
     - `_rescheduleAlarmsOnRestart()` becomes optional; keep as fallback if needed.
   - `updateNotificationSettings()`:
     - Replace `_notifications.cancelAll()` with `cancelFutureWindow()` + optional `_notifications.cancelAll()`.
     - Then call `scheduleFutureWindow()` if enabled.
   - `checkAndResetDailyStatus()`:
     - Keep today-only recalculation (do not schedule tomorrow).
     - Use a new helper `rescheduleTodayOnly()` that schedules only today using date-based IDs.
   - `rescheduleBasedOnHabits()`:
     - Use `rescheduleTodayOnly()` so today's status overrides day-0 window alarms.

5. Update metadata methods
   - Update `_storeAlarmMetadata()` and `_clearAlarmMetadata()` to include `date`.
   - Ensure all new scheduling calls pass the date string.

6. Update reboot reschedule logic
   - `android/app/src/main/kotlin/.../RescheduleReceiver.kt`
     - Scan all keys starting with `flutter.alarm_`.
     - Parse date from key if present.
     - Reschedule only if time is in the future.
   - Dart `_rescheduleAlarmsOnRestart()` should be updated to read date-based keys or removed in favor of native reboot reschedule.

7. Keep current flow intact
   - Today's reschedule based on diary status stays.
   - Future window scheduling does not alter diary logic.
   - No DB schema changes.

Validation Checklist
--------------------
- App start schedules 10 days ahead (check debug bottom sheet).
- Only 4 alarms per active day, no duplicate IDs.
- Today’s status update replaces only day 0 alarms.
- Settings change cancels all scheduled alarms and rebuilds 10-day window.
- After reboot, future alarms are restored via `RescheduleReceiver`.

Non-Goals
---------
- No background workers.
- No new DB tables.
- No change to UI flow.