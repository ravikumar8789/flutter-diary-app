# Morning Notification Update - Implementation Plan (Phased)

## Objective
- Implement final agreed behavior from `plan1.md` and `removal-plus-3.md` without breaking existing notification functionality.
- Final outcome:
  - Morning reminder at user-selected time (`1001`) with analysis-ready copy.
  - Remove active `+3h` scheduling (`1002`).
  - Keep `+6h` reminder (`1003`) with 3-hour bedtime proximity guard.
  - Keep bedtime flow unchanged.
  - Keep legacy-safe cancellation/cleanup for `1002`.

---

## Phase 0 - Pre-Change Safety Baseline

### Tasks
- Read and verify current behavior in `lib/services/notification_service.dart`.
- Confirm current morning reminder IDs and schedule flow:
  - `1001` at morning time
  - `1002` at `+3h`
  - `1003` at `+6h`
- Confirm cancellation flow still covers all 3 IDs.

### Edge-case checks
- Ensure no other files rely on `+3h` being scheduled.
- Ensure `1002` ID is still used in cancel/cleanup before edits.

### Exit criteria
- Baseline understood and unchanged code snapshot available in git diff context.

---

## Phase 1 - Copy-Only Update (Morning First Notification Set)

### Tasks
- Update only these arrays:
  - `_morningTitles`
  - `_morningBodies`
- Use locked 10 pairs from `plan1.md`.
- Do not modify `_reminder3h*`, `_reminder6h*`, bedtime arrays in this phase.

### Edge-case checks
- Keep title/body list lengths equal to avoid mismatch fallback behavior.
- Keep 10 entries to preserve `% 10` rotation pattern.

### Exit criteria
- Morning message text changed successfully.
- No behavior logic changed yet.

---

## Phase 2 - Remove Active `+3h` Scheduling

### Tasks
In `_scheduleMorningNotificationsForDate(...)`:
- Remove creation of reminder2 message (`_reminder3hTitles/_reminder3hBodies`).
- Remove reminder2 schedule call (`_scheduleAlarmWithLogging` for `1002`).
- Remove reminder2 metadata store call (`_storeAlarmMetadata` for `1002`).

Keep unchanged:
- reminder1 schedule/store.
- reminder3 schedule/store (will be guarded in next phase).
- `morningReminder2Id` constant and references outside scheduling block.

### Edge-case checks
- If `1002` not scheduled anymore, ensure no null/undefined references remain.
- Ensure compile safety after removing `secondMessage` and `reminder2Time`.

### Exit criteria
- New schedules include no `+3h` alarms.

---

## Phase 3 - Add `+6h` Bedtime Proximity Guard (3h)

### Tasks
Before scheduling reminder3:
- Compute same-day bedtime datetime (`21:00`).
- Compute `reminder3Time = morningDateTime + 6h`.
- Skip reminder3 if:
  - `reminder3Time >= bedtimeDateTime`, or
  - `bedtimeDateTime.difference(reminder3Time) < Duration(hours: 3)`.

### Edge-case checks
- Late morning users (example 2 PM -> +6h 8 PM) should skip reminder3.
- Early morning users should continue receiving reminder3.
- Ensure bedtime reminder scheduling remains unaffected.

### Exit criteria
- Reminder3 is only scheduled when it respects 3-hour separation from bedtime.

---

## Phase 4 - Preserve Legacy-Safe Cancellation

### Tasks
Keep existing cancellation logic intact for:
- `cancelMorningReminders()` -> cancel `1001`, `1002`, `1003`
- `_cancelDayAlarms(...)` -> cancel `1001`, `1002`, `1003`
- `_clearAlarmMetadata(...)` for reminder2 keys

### Why mandatory
- Existing users may already have previously scheduled `1002` alarms.
- Retaining cancel/cleanup prevents stale notifications after update.

### Edge-case checks
- Canceling a non-existent `1002` alarm should be harmless (no break).
- Verify no fatal path depends on successful `1002` cancellation.

### Exit criteria
- Legacy `1002` alarms are still cleaned safely; no new `1002` alarms are created.

---

## Phase 5 - Verification Matrix

### Functional verification
1) Morning time in future, active day:
- Expect schedules for `1001`, `1003`, `2001`.
- Expect no new schedule metadata for `1002`.

2) Late morning time (e.g., 14:00):
- `1003` skipped due to 3-hour bedtime guard.
- `1001` and `2001` remain.

3) Morning already passed for today:
- Preserve current behavior (today morning skipped in no-shift flow).

4) Inactive day:
- No morning/bedtime schedules for that date.

### Legacy verification
5) Device with old `1002` alarms:
- Trigger reschedule/cancel flow.
- Confirm old `1002` canceled and metadata removed.

### Regression verification
6) Bedtime filled/not-filled branching unchanged.
7) Active-day filtering unchanged.
8) Daily reset flow unchanged.

### Technical verification
9) No lints/errors in edited files.
10) No title/body length mismatch warnings introduced.

---

## Phase 6 - Release Safety and Cleanup Policy

### Release approach
- Ship with reminder2 cancel compatibility enabled.
- Monitor for notification-related errors for one release cycle.

### Deferred cleanup (future, optional)
- Remove unused `_reminder3hTitles/_reminder3hBodies` only after confirming no fallback/testing dependency.
- Keep this out of current scope to minimize risk.

---

## Non-Negotiable Guardrails
- Do not change bedtime timing/content logic.
- Do not change alarm ID strategy/date-key strategy.
- Do not remove `1002` cancel/metadata cleanup in this release.
- Do not alter unrelated features.
