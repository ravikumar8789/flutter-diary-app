# Morning Notification - 1 Day Ahead (Entry-Based Scheduling)

## Goal
- Change morning notification (`1001`) scheduling from 10-day blind loop to 1-day-ahead entry-based.
- Only schedule tomorrow's morning notification if user wrote **today's** diary entry (`wrote_entry = 1`).
- `+6h` (`1003`) is now **fully independent** — scheduled for 10 days, cancelled only when diary written today.
- Bedtime (`2001`) is **fully independent** — scheduled 10 days, never cancelled.

---

## Final Behavior Table

| Notification | Schedule | Cancel Condition |
|---|---|---|
| Morning `1001` | Tomorrow only, if today `wrote_entry = 1` | Not applicable (entry-gated at scheduling) |
| `+6h` `1003` | 10 days always | Cancel only when user writes diary today |
| Bedtime `2001` | 10 days always | Never cancelled |

---

## Auto-Trigger Already Wired
- `grace_system_service.dart` calls `rescheduleBasedOnHabits(userId)` every time diary entry is saved.
- This triggers `_rescheduleTodayNotifications()` → new logic runs automatically.
- **No extra trigger needed** after diary write.

---

## Architecture Changes

### 1) Split `+6h` out of `_scheduleMorningNotificationsForDate()`
- Currently `+6h` lives inside `_scheduleMorningNotificationsForDate()`.
- Extract into new `_scheduleFollowUpReminderForDate(date, morningTime, userId)`.
- `_scheduleMorningNotificationsForDate()` now only schedules `1001`.

### 2) New helper: `_scheduleTomorrowMorningIfEntryExists(userId, settings)`
- Queries today's `wrote_entry` via existing `_isDiaryCompletedToday()`.
- Gets tomorrow = `today + 1 day`.
- Checks if tomorrow is an active day via `_isActiveDayForDate()`.
- If both true → calls `_scheduleMorningNotificationsForDate(tomorrow, morningTime)`.
- If either false → silently skip.

### 3) New helper: `_scheduleFollowUpReminderForDate(date, morningTime, userId)`
- Computes `reminder3Time = morningDateTime + 6h`.
- Applies existing 3-hour bedtime proximity guard.
- If guard passes → schedule `1003` + store metadata.

### 4) New cancel method: `cancelFollowUpReminder()`
- Cancels only `1003` for today.
- Called in `_rescheduleTodayNotifications()` when `diaryCompleted = true`.
- Does not touch `1001`, `1002`, `2001`.

---

## Affected Functions

### `scheduleFutureWindow()` — PRIMARY CHANGE
Old behavior:
- 10-day loop schedules morning + bedtime.
- Checks diary completion for today, skips/cancels today morning if completed.

New behavior:
- 10-day loop: schedule bedtime (`2001`) + `+6h` (`1003` via new function) for each active day.
- After loop: call `_scheduleTomorrowMorningIfEntryExists()` for morning (`1001`).
- Remove morning from inside the loop entirely.
- Remove `if (isToday && diaryCompleted)` morning-completion skip.
- Remove `todayMorningCompleted` set logic.

### `_rescheduleTodayNotifications()` — SECONDARY CHANGE
Old behavior:
- If diary completed → `cancelMorningReminders()` (cancels 1001+1002+1003).
- If not completed → schedule today morning.

New behavior:
- If diary completed → call `cancelFollowUpReminder()` (cancels `1003` only).
- Remove today morning scheduling entirely.
- After bedtime scheduling → call `_scheduleTomorrowMorningIfEntryExists()`.

### `cancelMorningReminders()` — KEPT FOR LEGACY
- Keeps cancelling `1001`, `1002`, `1003` for legacy/manual cancel use.
- No longer called automatically on diary write.
- Still available for test screen and future use.

---

## Implementation Steps

### Step 1
Extract `+6h` block from `_scheduleMorningNotificationsForDate()` into `_scheduleFollowUpReminderForDate()`.
`_scheduleMorningNotificationsForDate()` now only handles `1001`.

### Step 2
Create `_scheduleTomorrowMorningIfEntryExists(userId, settings)`.

### Step 3
Create `_scheduleFollowUpReminderForDate(date, morningTime, userId)`.

### Step 4
Create `cancelFollowUpReminder()` — cancel `1003` for today only.

### Step 5
Update `scheduleFutureWindow()`:
- Add `_scheduleFollowUpReminderForDate()` call inside 10-day loop.
- Remove morning from loop.
- Add `_scheduleTomorrowMorningIfEntryExists()` after loop.

### Step 6
Update `_rescheduleTodayNotifications()`:
- Replace `cancelMorningReminders()` with `cancelFollowUpReminder()` on diary complete.
- Replace today morning schedule with `_scheduleTomorrowMorningIfEntryExists()`.

---

## Edge Cases

| Case | Handling |
|---|---|
| `habits_daily` row missing | `_isDiaryCompletedToday` returns false → skip morning → safe |
| `wrote_entry` type mismatch | Already handled in `_isDiaryCompletedToday()` |
| Tomorrow is inactive day | `_isActiveDayForDate(tomorrow)` check → skip morning |
| User writes entry multiple times | `rescheduleBasedOnHabits` fires each time → idempotent (cancel+reschedule) |
| User changes morning time | `updateNotificationSettings` → `scheduleFutureWindow` → correct new time |
| Legacy 10-day morning alarms | `cancelFutureWindow` runs before reschedule → cleans old alarms |
| `resolvedUserId` is null | Skip morning + follow-up cancel → safe |
| `+6h` too close to bedtime | 3-hour guard in `_scheduleFollowUpReminderForDate()` → skip |
| Morning time for tomorrow passed | `_scheduleMorningNotificationsForDate` `isBefore(now)` guard → skip |

---

## What Does NOT Change
- Bedtime scheduling (10-day, filled/not-filled branching, never cancelled).
- `cancelMorningReminders()` kept for legacy/manual/test use.
- `_cancelDayAlarms()` and all metadata cleanup paths.
- Rotation index logic, alarm ID strategy.
- Morning message content (already updated).
- Cancel path for `1002` (legacy safety).

---

## Validation Checklist
- [ ] User writes today → tomorrow morning `1001` scheduled.
- [ ] User writes today → today's `+6h` `1003` cancelled.
- [ ] User does not write today → no `1001` tomorrow.
- [ ] `+6h` `1003` scheduled for 10 days regardless of entry.
- [ ] Bedtime `2001` scheduled 10 days, never cancelled.
- [ ] User changes settings → reschedule works correctly.
- [ ] Inactive day tomorrow → morning skipped correctly.
- [ ] Old 10-day morning alarms cleaned on app open.
- [ ] No linter errors introduced.

---

## Files to Change
- `lib/services/notification_service.dart`
  - `_scheduleMorningNotificationsForDate()` — remove `+6h` block
  - `scheduleFutureWindow()` — loop and post-loop changes
  - `_rescheduleTodayNotifications()` — remove today morning, add entry-check cancel
  - New: `_scheduleTomorrowMorningIfEntryExists()`
  - New: `_scheduleFollowUpReminderForDate()`
  - New: `cancelFollowUpReminder()`
