Restarted application in 9,887ms.
I/AlarmService(23536): AlarmService started!
I/flutter (23536): supabase.supabase_flutter: INFO: ***** Supabase init completed ***** 
W/AlarmService(23536): Attempted to start a duplicate background isolate. Returning...
I/flutter (23536): 🔔 DEBUG: Permission status: PermissionStatus.granted
I/flutter (23536): 🔔 DEBUG: Notification permission granted!
I/flutter (23536):  STREAK DEBUG: calculateStreakOnAppLaunch START - userId: f0bfcdff-b74c-4765-ab1e-c15b4aaae0b8
I/flutter (23536):  STREAK DEBUG: Today date: 2026-01-25
I/flutter (23536):  STREAK DEBUG: Fetching streaks from Supabase...
I/flutter (23536):  STREAK DEBUG: fetchStreaks - Fetching from Supabase with select(*)
I/flutter (23536):  STREAK DEBUG: fetchStreaks - Supabase raw response: {user_id: f0bfcdff-b74c-4765-ab1e-c15b4aaae0b8, current: 1, longest: 12, last_entry_date: 2026-01-25, freeze_credits: 2, updated_at: 2026-01-25T16:06:08.963961+00:00, grace_pieces_total: 22.0, today_date: 2026-01-25, today_diary: true, today_affirmations: false, today_gratitude: false, today_self_care_count: 1, today_grace_pieces: 1.0}
I/flutter (23536):  STREAK DEBUG: fetchStreaks - Caching Supabase response to local DB
I/flutter (23536):  STREAK DEBUG: fetchStreaks - Cached to local DB
I/flutter (23536):  STREAK DEBUG: Supabase streak data: {user_id: f0bfcdff-b74c-4765-ab1e-c15b4aaae0b8, current: 1, longest: 12, last_entry_date: 2026-01-25, freeze_credits: 2, updated_at: 2026-01-25T16:06:08.963961+00:00, grace_pieces_total: 22.0, today_date: 2026-01-25, today_diary: true, today_affirmations: false, today_gratitude: false, today_self_care_count: 1, today_grace_pieces: 1.0}
I/flutter (23536):  STREAK DEBUG: Checking local streak cache...
I/flutter (23536):  STREAK DEBUG: Local streak exists: true, last_sync_at: 2026-01-25T21:37:22.342228
I/flutter (23536):  STREAK DEBUG: Local cache exists, local today_date: 2026-01-25, Supabase today_date: 2026-01-25
I/flutter (23536):  STREAK DEBUG: Local cache already exists, skipping cache update
I/flutter (23536):  STREAK DEBUG: Streak today_date: 2026-01-25, App today: 2026-01-25, isNewDay: false
I/flutter (23536):  STREAK DEBUG: SAME DAY - populating habits_daily from streaks.today_*
I/flutter (23536):  STREAK DEBUG: Existing habits_daily records: 1
I/flutter (23536):  STREAK DEBUG: habits_daily record already exists, skipping creation
I/flutter (23536):  STREAK DEBUG: last_entry_date: 2026-01-25, current: 1
I/flutter (23536):  STREAK DEBUG: lastDateOnly: 2026-01-25, daysDiff: 0
I/flutter (23536):  STREAK DEBUG: Same day, trusting Supabase streak, skipping recalculation
I/flutter (23536):  STREAK DEBUG: calculateStreakOnAppLaunch END - same day
W/WindowOnBackDispatcher(23536): OnBackInvokedCallback is not enabled for the application.
W/WindowOnBackDispatcher(23536): Set 'android:enableOnBackInvokedCallback="true"' in the application manifest.
W/WindowOnBackDispatcher(23536): OnBackInvokedCallback is not enabled for the application.
W/WindowOnBackDispatcher(23536): Set 'android:enableOnBackInvokedCallback="true"' in the application manifest.
W/WindowOnBackDispatcher(23536): OnBackInvokedCallback is not enabled for the application.
W/WindowOnBackDispatcher(23536): Set 'android:enableOnBackInvokedCallback="true"' in the application manifest.
D/TextSelection(23536): onUseCache cache=false
I/PowerHalMgrImpl(23536): hdl:27473, pid:23536 
I/flutter (23536): 🔍 DIARY DEBUG: Using local date: 2026-01-25
I/flutter (23536): 🔍 DIARY DEBUG: Local timezone: IST, UTC offset: 5:30:00.000000
I/PowerHalMgrImpl(23536): hdl:27474, pid:23536 
I/flutter (23536):  STREAK DEBUG: GraceSystemService.trackTaskCompletion START - userId: f0bfcdff-b74c-4765-ab1e-c15b4aaae0b8, taskType: diary, completed: true
I/flutter (23536):  STREAK DEBUG: dateStr: 2026-01-25
I/flutter (23536):  STREAK DEBUG: Habits record retrieved/created
I/flutter (23536):  STREAK DEBUG: Update data: {wrote_entry: 1}
I/flutter (23536):  STREAK DEBUG: habits_daily updated
I/flutter (23536):  STREAK DEBUG: Updated record: 1 records
I/flutter (23536):  STREAK DEBUG: Habit data: {id: cc448832-1993-4106-9f41-98377534c616, user_id: f0bfcdff-b74c-4765-ab1e-c15b4aaae0b8, date: 2026-01-25, wrote_entry: 1, filled_affirmations: 0, filled_gratitude: 0, self_care_completed_count: 1, grace_pieces_earned: 1.0, is_synced: 1, last_sync_at: 2026-01-25T21:36:08.398026}
I/flutter (23536):  STREAK DEBUG: Pieces earned: 1.0
I/flutter (23536):  STREAK DEBUG: oldTodayPieces: 1.0, currentTotalPieces: 22.0
I/flutter (23536):  STREAK DEBUG: newTotalPieces: 22.0
I/flutter (23536):  STREAK DEBUG: Calculated grace days: 2
I/flutter (23536):  STREAK DEBUG: Updating existing streaks record
I/flutter (23536):  STREAK DEBUG: Update data: {grace_pieces_total: 22.0, freeze_credits: 2, today_date: 2026-01-25, today_diary: 1, today_affirmations: 0, today_gratitude: 0, today_self_care_count: 1, today_grace_pieces: 1.0, updated_at: 2026-01-25T21:37:32.340009, is_synced: 0}
I/flutter (23536):  STREAK DEBUG: Streaks record updated
I/flutter (23536):  STREAK DEBUG: Scheduling sync to Supabase
I/flutter (23536):  STREAK DEBUG: GraceSystemService.trackTaskCompletion END - success
I/flutter (23536):  STREAK DEBUG: recalculateStreak START - userId: f0bfcdff-b74c-4765-ab1e-c15b4aaae0b8
I/flutter (23536):  STREAK DEBUG: Existing streaks: 1
I/flutter (23536):  STREAK DEBUG: last_entry_date: 2026-01-25
I/flutter (23536):  STREAK DEBUG: lastDateOnly: 2026-01-25, todayDateOnly: 2026-01-25
I/flutter (23536):  STREAK DEBUG: Same day or future, skipping recalculation
I/flutter (23536):  STREAK DEBUG: RPC call successful, marking as synced in local DB
I/flutter (23536):  STREAK DEBUG: Streaks marked as synced
I/flutter (23536):  STREAK DEBUG: Marking 1 habits as synced
I/flutter (23536):  STREAK DEBUG: batchUpdateStreakData END - success
D/TextSelection(23536): onUseCache cache=false
I/PowerHalMgrImpl(23536): hdl:27477, pid:23536 
I/PowerHalMgrImpl(23536): hdl:27478, pid:23536 