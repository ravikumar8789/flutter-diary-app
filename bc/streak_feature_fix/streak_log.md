estarted application in 5,346ms.
I/AlarmService(13516): AlarmService started!
I/flutter (13516): supabase.supabase_flutter: INFO: ***** Supabase init completed ***** 
W/AlarmService(13516): Attempted to start a duplicate background isolate. Returning...
I/flutter (13516):  STREAK DEBUG: calculateStreakOnAppLaunch START - userId: f0bfcdff-b74c-4765-ab1e-c15b4aaae0b8
I/flutter (13516): 🔔 NATIVE: Alarm 1001 scheduled for 2026-01-20 07:00:00.000
I/flutter (13516): 🔔 RESTART: Rescheduled alarm 1001 for 2026-01-20 07:00:00.000
I/flutter (13516): 🔔 NATIVE: Alarm 1002 scheduled for 2026-01-20 10:00:00.000
I/flutter (13516): 🔔 RESTART: Rescheduled alarm 1002 for 2026-01-20 10:00:00.000
I/flutter (13516): 🔔 NATIVE: Alarm 1003 scheduled for 2026-01-20 13:00:00.000
I/flutter (13516): 🔔 RESTART: Rescheduled alarm 1003 for 2026-01-20 13:00:00.000
I/flutter (13516):  STREAK DEBUG: Today date: 2026-01-20
I/flutter (13516): 🔔 NATIVE: Alarm 2001 scheduled for 2026-01-20 21:00:00.000
I/flutter (13516): 🔔 RESTART: Rescheduled bedtime alarm for 2026-01-20 21:00:00.000
I/flutter (13516):  STREAK DEBUG: Fetching streaks from Supabase...
I/flutter (13516): 🔔 DEBUG: Permission status: PermissionStatus.granted
I/flutter (13516): 🔔 DEBUG: Notification permission granted!
I/flutter (13516):  STREAK DEBUG: fetchStreaks - Fetching from Supabase with select(*)
I/flutter (13516):  STREAK DEBUG: fetchStreaks - Supabase raw response: {user_id: f0bfcdff-b74c-4765-ab1e-c15b4aaae0b8, current: 9, longest: 6, last_entry_date: 2026-01-20, freeze_credits: 1, updated_at: 2026-01-19T19:17:22.229864+00:00, grace_pieces_total: 15.0, today_date: 2026-01-20, today_diary: true, today_affirmations: true, today_gratitude: true, today_self_care_count: 1, today_grace_pieces: 2.0}
I/flutter (13516):  STREAK DEBUG: fetchStreaks - Caching Supabase response to local DB
I/flutter (13516):  STREAK DEBUG: fetchStreaks - Cached to local DB
I/flutter (13516):  STREAK DEBUG: Supabase streak data: {user_id: f0bfcdff-b74c-4765-ab1e-c15b4aaae0b8, current: 9, longest: 6, last_entry_date: 2026-01-20, freeze_credits: 1, updated_at: 2026-01-19T19:17:22.229864+00:00, grace_pieces_total: 15.0, today_date: 2026-01-20, today_diary: true, today_affirmations: true, today_gratitude: true, today_self_care_count: 1, today_grace_pieces: 2.0}
I/flutter (13516):  STREAK DEBUG: Checking local streak cache...
I/flutter (13516):  STREAK DEBUG: Local streak exists: true, last_sync_at: 2026-01-20T00:47:39.673026
I/flutter (13516):  STREAK DEBUG: Local cache exists, local today_date: 2026-01-20, Supabase today_date: 2026-01-20
I/flutter (13516):  STREAK DEBUG: Local cache already exists, skipping cache update
I/flutter (13516):  STREAK DEBUG: Streak today_date: 2026-01-20, App today: 2026-01-20, isNewDay: false
I/flutter (13516):  STREAK DEBUG: SAME DAY - populating habits_daily from streaks.today_*
I/flutter (13516):  STREAK DEBUG: Existing habits_daily records: 1
I/flutter (13516):  STREAK DEBUG: habits_daily record already exists, skipping creation
I/flutter (13516):  STREAK DEBUG: last_entry_date: 2026-01-20, current: 9
I/flutter (13516):  STREAK DEBUG: lastDateOnly: 2026-01-20, daysDiff: 0
I/flutter (13516):  STREAK DEBUG: Same day, trusting Supabase streak, skipping recalculation
I/flutter (13516):  STREAK DEBUG: calculateStreakOnAppLaunch END - same day
W/WindowOnBackDispatcher(13516): OnBackInvokedCallback is not enabled for the application.
W/WindowOnBackDispatcher(13516): Set 'android:enableOnBackInvokedCallback="true"' in the application manifest.
W/WindowOnBackDispatcher(13516): OnBackInvokedCallback is not enabled for the application.
W/WindowOnBackDispatcher(13516): Set 'android:enableOnBackInvokedCallback="true"' in the application manifest.
W/WindowOnBackDispatcher(13516): OnBackInvokedCallback is not enabled for the application.
W/WindowOnBackDispatcher(13516): Set 'android:enableOnBackInvokedCallback="true"' in the application manifest.
