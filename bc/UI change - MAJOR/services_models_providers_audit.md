# Services, Models, and Providers Audit

## Services (19 Total)

1. ✅ **ai_service.dart** - `AIService`
   - Used in: analytics_screen, home_summary_service, analytics_service, daily_insights_timeline, home_summary_provider

2. ✅ **analytics_service.dart** - `AnalyticsService`
   - Used in: analytics_screen, analytics_provider, period_comparison_card

3. ✅ **app_lifecycle_service.dart** - `AppLifecycleService`
   - Used in: main.dart

4. ✅ **auth_service.dart** - `AuthService`
   - Used in: pin_auth_service, login_screen, privacy_lock_provider, snackbar_utils

5. ✅ **connectivity_service.dart** - `ConnectivityService`
   - Used in: main.dart

6. ✅ **database/database_manager.dart** - `DatabaseManager`
   - Used in: local_entry_service, sync_worker

7. ✅ **database/local_entry_service.dart** - `LocalEntryService`
   - Used in: home_summary_service, entry_service, sync_worker

8. ✅ **entry_service.dart** - `EntryService`
   - Used in: new_diary_screen, home_summary_service, splash_screen, entry_provider, local_entry_service, sync_worker

9. ✅ **error_logging_service.dart** - `ErrorLoggingService`
   - Used in: Multiple files (42 files) - extensively used for error logging

10. ✅ **grace_system_service.dart** - `GraceSystemService`
    - Used in: grace_system_provider

11. ✅ **history_service.dart** - `HistoryService`
    - Used in: history_screen, recent_entries_provider, history_provider

12. ✅ **home_summary_service.dart** - `HomeSummaryService`
    - Used in: home_summary_provider

13. ✅ **native_alarm_manager.dart** - `NativeAlarmManager`
    - Used in: notification_service

14. ✅ **notification_service.dart** - `NotificationService`
    - Used in: notification_test_screen, settings_screen, user_preference_sync_service, main.dart

15. ✅ **pin_auth_service.dart** - `PinAuthService`
    - Used in: privacy_lock_provider

16. 🗑️ **streak_compassion_service.dart** - **DELETED**
    - Status: File removed (will redesign streak feature from scratch)

17. ✅ **support_ticket_service.dart** - `SupportTicketService`
    - Used in: help_support_screen, my_tickets_screen

18. ✅ **sync/supabase_sync_service.dart** - `SupabaseSyncService`
    - Used in: splash_screen, entry_service, app_lifecycle_service, sync_worker, connectivity_service

19. ✅ **sync/sync_worker.dart** - `SyncWorker`
    - Used in: splash_screen, entry_service, app_lifecycle_service, supabase_sync_service, connectivity_service

20. ✅ **timezone_service.dart** - `TimezoneService`
    - Used in: user_data_service, auth_service, auth_provider

21. ✅ **user_data_service.dart** - `UserDataService`
    - Used in: splash_screen, user_data_provider

22. ✅ **user_preference_sync_service.dart** - `UserPreferenceSyncService`
    - Used in: notification_service, paper_style_provider, theme_provider, font_size_provider

## Models (9 Total)

1. ✅ **analytics_models.dart** - Analytics models
   - Used in: Multiple files (15 files) - analytics_screen, widgets, services, providers

2. ✅ **entry_models.dart** - Entry models
   - Used in: Multiple files (11 files) - new_diary_screen, history_screen, services, providers

3. ❌ **error_models.dart** - Error models (`ErrorSeverity`, `ErrorContext`)
   - Status: Defined but never imported/used (ErrorLoggingService uses string severity instead)

4. ✅ **history_entry_model.dart** - `HistoryEntry`
   - Used in: home_screen, history_screen, recent_entries_provider, history_service, history_provider

5. ✅ **home_summary_models.dart** - Home summary models
   - Used in: home_screen, home_summary_service, home_summary_provider

6. ✅ **models.dart** - Main models export
   - Used in: Multiple files (28 files) - central export file

7. ✅ **settings_models.dart** - Settings models
   - Used in: utility_models, models.dart

8. ✅ **user_models.dart** - User models
   - Used in: settings_screen, profile_screen, register_screen, login_screen, auth_provider

9. ✅ **utility_models.dart** - Utility models
   - Used in: models.dart

## Providers (15 Total)

1. ✅ **analytics_provider.dart** - `analyticsProvider`
   - Used in: analytics_screen

2. ✅ **auth_provider.dart** - `authProvider`, `currentUserProvider`, `authControllerProvider`
   - Used in: settings_screen, profile_screen, register_screen, login_screen, auth_wrapper

3. ❌ **date_provider.dart** - `dateProvider`
   - Status: 🗑️ **DELETED** - File removed (unused)

4. ✅ **entry_provider.dart** - `entryProvider`
   - Used in: new_diary_screen, grace_system_provider

5. ✅ **font_size_provider.dart** - `fontSizeProvider`
   - Used in: settings_screen

6. ✅ **grace_system_provider.dart** - `graceSystemProvider`
   - Used in: home_screen, settings_screen, grace_system_info_card, entry_provider

7. ✅ **history_provider.dart** - `historyProvider`
   - Used in: history_screen

8. ✅ **home_summary_provider.dart** - `homeSummaryProvider`, `yesterdayInsightProvider`
   - Used in: home_screen, yesterday_insight_card, analytics_screen

9. ✅ **paper_style_provider.dart** - `paperStyleProvider`
   - Used in: settings_screen

10. ✅ **privacy_lock_provider.dart** - `privacyLockProvider`
    - Used in: settings_screen, pin_recovery_screen, pin_lock_screen, pin_setup_screen, security_questions_screen, change_pin_screen, app_lifecycle_service, main.dart

11. ✅ **recent_entries_provider.dart** - `recentEntriesProvider`
    - Used in: home_screen

12. 🗑️ **streak_compassion_provider.dart** - **DELETED**
    - Status: File removed (will redesign streak feature from scratch)

13. ✅ **sync_status_provider.dart** - `syncStatusProvider`
    - Used in: new_diary_screen, entry_provider

14. ✅ **theme_provider.dart** - `themeProvider`
    - Used in: settings_screen, main.dart

15. ✅ **user_data_provider.dart** - `userDataProvider`
    - Used in: home_screen, splash_screen, profile_screen

## Summary

### Services
- **Total:** 22 services
- **Used:** 21 ✅
- **Deleted:** 1 🗑️ (`streak_compassion_service.dart` - removed for redesign)

### Models
- **Total:** 9 models
- **Used:** 8 ✅
- **Unused:** 1 ❌ (`error_models.dart` - defined but never imported/used)

### Providers
- **Total:** 15 providers
- **Used:** 13 ✅
- **Deleted:** 2 🗑️ (`date_provider.dart`, `streak_compassion_provider.dart` - removed)

## Unused Items

1. 🗑️ **date_provider.dart** - **DELETED** - Provider (`selectedDateProvider`) was unused, file removed
2. 🗑️ **streak_compassion_provider.dart** - **DELETED** - Provider removed (will redesign streak feature from scratch)
3. 🗑️ **streak_compassion_service.dart** - **DELETED** - Service removed (will redesign streak feature from scratch)
4. ❌ **error_models.dart** - Model file (`ErrorSeverity`, `ErrorContext`) defined but never imported/used

