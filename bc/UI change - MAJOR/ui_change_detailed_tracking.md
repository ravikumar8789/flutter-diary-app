# UI Change Detailed Tracking - Complete Codebase Audit

**Purpose:** Track every function, service, provider, widget, and screen to identify what's used in the new UI, what's left unused, and what needs action.

**Status Legend:**
- ✅ **Used in New UI** - Actively used in new UI screens
- ⏳ **Partially Used** - Some methods/functions used, others not
- ❌ **Not Used** - Not referenced in new UI
- 🔄 **Merged/Replaced** - Functionality merged into another component
- 🗑️ **Removed** - Intentionally removed from new UI

**Last Updated:** December 2024

---

## 📦 SERVICES (22 Total)

### 1. `ai_service.dart`
**Status:** ✅ **Used in New UI**

**Methods:**
- ✅ `getYesterdayInsight(String userId)` - Used in Home Screen (Yesterday Insight Card)
- ✅ `generateWeeklyInsight(String userId, DateTime weekStart)` - Used in Analytics Screen
- ✅ `generateDailyInsight(String entryId)` - Used internally
- ✅ `analyzeEntrySentiment(String entryId)` - Used internally
- ✅ `getEntryTopics(String entryId)` - Used internally

**Used In:**
- `lib/providers/home_summary_provider.dart` (yesterdayInsightProvider)
- `lib/providers/analytics_provider.dart` (weekly insights)
- `lib/services/home_summary_service.dart`

---

### 2. `analytics_service.dart`
**Status:** ✅ **Used in New UI**

**Methods:**
- ✅ `getWeeklyAnalytics(String userId, DateTime weekStart)` - Used in Analytics Screen
- ✅ `getMonthlyAnalytics(String userId, DateTime monthStart)` - Used in Analytics Screen
- ✅ `getDailyProgress(String userId, DateTime startDate, DateTime endDate)` - Used in Analytics Screen
- ✅ `getMoodDistribution(String userId, DateTime startDate, DateTime endDate)` - Used in Analytics Screen
- ✅ `getHabitCorrelations(String userId, DateTime startDate, DateTime endDate)` - Used in Analytics Screen
- ✅ `getPeriodComparison(String userId, DateTime currentStart, DateTime previousStart)` - Used in Analytics Screen
- ✅ `getWeeklyInsightsList(String userId)` - Used in Analytics Screen

**Used In:**
- `lib/providers/analytics_provider.dart`
- `lib/screens/analytics_screen.dart`

---

### 3. `app_lifecycle_service.dart`
**Status:** ✅ **Used in New UI**

**Methods:**
- ✅ `initialize()` - Used in app initialization
- ✅ `handleAppStateChange(AppLifecycleState state)` - Used for background/foreground handling

**Used In:**
- `lib/main.dart` (app lifecycle management)

---

### 4. `auth_service.dart`
**Status:** ✅ **Used in New UI**

**Methods:**
- ✅ `signIn(String email, String password)` - Used in Login Screen
- ✅ `signUp(String email, String password, String displayName)` - Used in Register Screen
- ✅ `signOut()` - Used in Profile Screen
- ✅ `resetPassword(String email)` - Used in Login Screen
- ✅ `getCurrentUser()` - Used throughout app

**Used In:**
- `lib/providers/auth_provider.dart`
- `lib/screens/login_screen.dart`
- `lib/screens/register_screen.dart`
- `lib/screens/profile_screen.dart`

---

### 5. `connectivity_service.dart`
**Status:** ✅ **Used in New UI** (Internal)

**Methods:**
- ✅ `isConnected()` - Used internally by EntryService
- ✅ `onConnectivityChanged()` - Used for sync triggers

**Used In:**
- `lib/services/entry_service.dart` (internal)

---

### 6. `database/database_manager.dart`
**Status:** ✅ **Used in New UI** (Internal)

**Methods:**
- ✅ `database` (getter) - Used by LocalEntryService
- ✅ `initDatabase()` - Used in app initialization
- ✅ `closeDatabase()` - Used in cleanup

**Used In:**
- `lib/services/database/local_entry_service.dart` (internal)

---

### 7. `database/local_entry_service.dart`
**Status:** ✅ **Used in New UI**

**Methods:**
- ✅ `getEntryByDate(String userId, DateTime date)` - Used in New Entry Screen
- ✅ `upsertEntry(Entry entry)` - Used in New Entry Screen (auto-save)
- ✅ `upsertAffirmations(EntryAffirmations affirmations)` - Used in New Entry Screen
- ✅ `upsertPriorities(EntryPriorities priorities)` - Used in New Entry Screen
- ✅ `upsertMeals(EntryMeals meals)` - Used in New Entry Screen
- ✅ `upsertGratitude(EntryGratitude gratitude)` - Used in New Entry Screen
- ✅ `upsertSelfCare(EntrySelfCare selfCare)` - Used in New Entry Screen
- ✅ `upsertShowerBath(EntryShowerBath showerBath)` - Used in New Entry Screen
- ✅ `upsertTomorrow(EntryTomorrow tomorrow)` - Used in New Entry Screen
- ✅ `getMeals(String entryId)` - Used in Home Summary Service (week cards)
- ✅ `getSelfCare(String entryId)` - Used in Home Summary Service (week cards)
- ✅ `getEntriesInRange(String userId, DateTime start, DateTime end)` - Used in Home Summary Service (week cards)
- ✅ `deleteEntry(String entryId)` - Used in History Screen
- ✅ `getAffirmations(String entryId)` - Used in New Entry Screen
- ✅ `getPriorities(String entryId)` - Used in New Entry Screen
- ✅ `getGratitude(String entryId)` - Used in New Entry Screen
- ✅ `getTomorrow(String entryId)` - Used in New Entry Screen
- ✅ `getShowerBath(String entryId)` - Used in New Entry Screen

**Used In:**
- `lib/services/entry_service.dart`
- `lib/services/home_summary_service.dart` (new calculation method)
- `lib/screens/new_diary_screen.dart`

---

### 8. `entry_service.dart`
**Status:** ✅ **Used in New UI**

**Methods:**
- ✅ `saveEntry(EntryData data)` - Used in New Entry Screen (auto-save)
- ✅ `loadEntry(DateTime date)` - Used in New Entry Screen
- ✅ `deleteEntry(String entryId)` - Used in History Screen
- ✅ `syncEntry(String entryId)` - Used internally for sync
- ✅ `getEntryById(String entryId)` - Used in History Screen

**Used In:**
- `lib/providers/entry_provider.dart`
- `lib/screens/new_diary_screen.dart`

---

### 9. `error_logging_service.dart`
**Status:** ✅ **Used in New UI**

**Methods:**
- ✅ `logError(...)` - Used throughout all services
- ✅ `logHighError(...)` - Used for critical errors
- ✅ `logLowError(...)` - Used for minor errors
- ✅ `logMediumError(...)` - Used for medium severity errors

**Used In:**
- All services (comprehensive error logging)

---

### 10. `grace_system_service.dart`
**Status:** ✅ **Used in New UI**

**Methods:**
- ✅ `calculateGracePieces(...)` - Used in New Entry Screen
- ✅ `updateGraceSystem(...)` - Used when entries are saved
- ✅ `getGraceSystemStatus(String userId)` - Used in Home Screen

**Used In:**
- `lib/providers/grace_system_provider.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/new_diary_screen.dart`

---

### 11. `history_service.dart`
**Status:** ✅ **Used in New UI**

**Methods:**
- ✅ `getEntriesForMonth(String userId, DateTime month)` - Used in History Screen
- ✅ `getRecentEntries(String userId, {int limit})` - Used in Home Screen (Recent Entries)
- ✅ `getEntryById(String entryId)` - Used in History Screen
- ✅ `searchEntries(String userId, String query)` - Used in History Screen
- ✅ `getCalendarMoodData(String userId, DateTime month)` - Used in History Screen (Calendar view)

**Used In:**
- `lib/providers/history_provider.dart`
- `lib/providers/recent_entries_provider.dart`
- `lib/screens/history_screen.dart`
- `lib/screens/home_screen.dart`

---

### 12. `home_summary_service.dart`
**Status:** ✅ **Used in New UI**

**Methods:**
- ✅ `fetchAll(String userId)` - Used in Home Screen
- ✅ `_fetchStreak(String userId)` - Used internally
- ✅ `_fetchTodayProgress(String userId, DateTime today)` - Used internally
- ✅ `_fetchWeeklySnapshot(String userId, DateTime thisWeekStart, DateTime prevWeekStart)` - **UPDATED** - Now calculates from local DB
- ✅ `_calculateCurrentWeekFromLocal(String userId, DateTime weekStart)` - **NEW** - Calculates week metrics from local DB
- ✅ `_countSelfCareItems(EntrySelfCare selfCare)` - **NEW** - Helper for self-care calculation
- ✅ `_fetchPromptMotivation(String userId)` - Used internally
- ✅ `fetchAiInsight(String userId)` - Deprecated, but still used

**Used In:**
- `lib/providers/home_summary_provider.dart`
- `lib/screens/home_screen.dart`

---

### 13. `native_alarm_manager.dart`
**Status:** ✅ **Used in New UI** (Internal)

**Methods:**
- ✅ `scheduleNotification(...)` - Used by NotificationService
- ✅ `cancelNotification(int id)` - Used by NotificationService
- ✅ `cancelAllNotifications()` - Used by NotificationService

**Used In:**
- `lib/services/notification_service.dart` (internal)

---

### 14. `notification_service.dart`
**Status:** ✅ **Used in New UI**

**Methods:**
- ✅ `scheduleDailyReminder(TimeOfDay time, List<int> activeDays)` - Used in Settings Screen
- ✅ `cancelDailyReminder()` - Used in Settings Screen
- ✅ `updateReminderTime(TimeOfDay time)` - Used in Settings Screen
- ✅ `updateActiveDays(List<int> activeDays)` - Used in Settings Screen
- ✅ `testNotification()` - Used in Notification Test Screen (dev only)

**Used In:**
- `lib/screens/settings_screen.dart`
- `lib/screens/notification_test_screen.dart` (dev only)

---

### 15. `pin_auth_service.dart`
**Status:** ✅ **Used in New UI**

**Methods:**
- ✅ `setPin(String pin)` - Used in Pin Setup Screen
- ✅ `validatePin(String pin)` - Used in Pin Lock Screen
- ✅ `changePin(String oldPin, String newPin)` - Used in Change Pin Screen
- ✅ `setSecurityQuestions(...)` - Used in Security Questions Screen
- ✅ `validateSecurityAnswers(...)` - Used in Pin Recovery Screen
- ✅ `isPinSet()` - Used in Auth Wrapper
- ✅ `enablePrivacyLock()` - Used in Settings Screen
- ✅ `disablePrivacyLock()` - Used in Settings Screen
- ✅ `isPrivacyLockEnabled()` - Used in Auth Wrapper

**Used In:**
- `lib/providers/privacy_lock_provider.dart`
- `lib/screens/pin_setup_screen.dart`
- `lib/screens/pin_lock_screen.dart`
- `lib/screens/change_pin_screen.dart`
- `lib/screens/pin_recovery_screen.dart`
- `lib/screens/security_questions_screen.dart`
- `lib/screens/settings_screen.dart`
- `lib/screens/auth_wrapper.dart`

---

### 16. `streak_compassion_service.dart`
**Status:** ✅ **Used in New UI**

**Methods:**
- ✅ `updateStreak(String userId, bool entryCompleted)` - Used when entries are saved
- ✅ `getStreakData(String userId)` - Used in Home Screen
- ✅ `applyGrace(String userId)` - Used in Grace System

**Used In:**
- `lib/providers/streak_compassion_provider.dart`
- `lib/screens/home_screen.dart`

---

### 17. `support_ticket_service.dart`
**Status:** ✅ **Used in New UI**

**Methods:**
- ✅ `submitTicket({category, subject, message})` - Used in Help Support Screen
- ✅ `getUserTickets(String userId)` - Used in My Tickets Screen
- ✅ `getTicketById(String ticketId)` - Used in My Tickets Screen

**Used In:**
- `lib/screens/help_support_screen.dart`
- `lib/screens/my_tickets_screen.dart`
- `lib/screens/settings_screen.dart` (merged Help & Support section)

---

### 18. `sync/supabase_sync_service.dart`
**Status:** ✅ **Used in New UI** (Internal)

**Methods:**
- ✅ `syncEntry(Entry entry)` - Used internally by EntryService
- ✅ `syncAffirmations(...)` - Used internally
- ✅ `syncMeals(...)` - Used internally
- ✅ `syncSelfCare(...)` - Used internally
- ✅ `syncGratitude(...)` - Used internally
- ✅ `syncAllPending()` - Used by SyncWorker

**Used In:**
- `lib/services/entry_service.dart` (internal)
- `lib/services/sync/sync_worker.dart`

---

### 19. `sync/sync_worker.dart`
**Status:** ✅ **Used in New UI**

**Methods:**
- ✅ `processSyncQueue()` - Used in Splash Screen
- ✅ `addToQueue(String entryId, String operation)` - Used internally
- ✅ `retryFailedSyncs()` - Used internally

**Used In:**
- `lib/screens/splash_screen.dart`
- `lib/services/entry_service.dart` (internal)

---

### 20. `timezone_service.dart`
**Status:** ✅ **Used in New UI** (Internal)

**Methods:**
- ✅ `getUserTimezone(String userId)` - Used internally
- ✅ `convertToUserTimezone(DateTime utcTime, String userId)` - Used internally
- ✅ `getCurrentTimezone()` - Used internally

**Used In:**
- `lib/services/user_data_service.dart` (internal)

---

### 21. `user_data_service.dart`
**Status:** ✅ **Used in New UI**

**Methods:**
- ✅ `fetchUserData()` - Used in Profile Screen
- ✅ `updateUserProfile({displayName, avatarUrl})` - Used in Profile Screen
- ✅ `fetchUserStats(String userId)` - Used in Profile Screen
- ✅ `fetchUserPreferences(String userId)` - Used in Settings Screen
- ✅ `updateUserPreferences(Map<String, dynamic> preferences)` - Used in Settings Screen

**Used In:**
- `lib/providers/user_data_provider.dart`
- `lib/screens/profile_screen.dart`
- `lib/screens/settings_screen.dart`

---

### 22. `user_preference_sync_service.dart`
**Status:** ✅ **Used in New UI** (Internal)

**Methods:**
- ✅ `syncPreferences(String userId)` - Used internally
- ✅ `syncThemePreference(String userId)` - Used internally
- ✅ `syncFontSizePreference(String userId)` - Used internally
- ✅ `syncPaperStylePreference(String userId)` - Used internally

**Used In:**
- `lib/providers/theme_provider.dart` (internal)
- `lib/providers/font_size_provider.dart` (internal)
- `lib/providers/paper_style_provider.dart` (internal)

---

## 🔄 PROVIDERS (15 Total)

### 1. `analytics_provider.dart`
**Status:** ✅ **Used in New UI**

**Providers:**
- ✅ `analyticsPeriodProvider` - Weekly/Monthly toggle
- ✅ `selectedWeekProvider` - Week selection
- ✅ `weeklyInsightsListProvider` - List of available weeks
- ✅ `weeklyAnalyticsProvider` - Weekly analytics data
- ✅ `monthlyAnalyticsProvider` - Monthly analytics data

**Used In:**
- `lib/screens/analytics_screen.dart`

---

### 2. `auth_provider.dart`
**Status:** ✅ **Used in New UI**

**Providers:**
- ✅ `authRepositoryProvider` - Auth repository instance
- ✅ `currentUserProvider` - Current user stream
- ✅ `authControllerProvider` - Auth controller

**Used In:**
- `lib/screens/login_screen.dart`
- `lib/screens/register_screen.dart`
- `lib/screens/profile_screen.dart`
- `lib/screens/auth_wrapper.dart`

---

### 3. `date_provider.dart`
**Status:** ✅ **Used in New UI**

**Providers:**
- ✅ `selectedDateProvider` - Currently selected entry date

**Used In:**
- `lib/screens/new_diary_screen.dart`
- `lib/screens/history_screen.dart`

---

### 4. `entry_provider.dart`
**Status:** ✅ **Used in New UI**

**Providers:**
- ✅ `entryProvider` - Entry state management

**Methods:**
- ✅ `saveEntry(EntryData data)` - Save entry
- ✅ `loadEntry(DateTime date)` - Load entry
- ✅ `updateMood(int mood)` - Update mood
- ✅ `updateDiaryText(String text)` - Update diary text
- ✅ `addTag(String tag)` - Add tag
- ✅ `removeTag(String tag)` - Remove tag
- ✅ `saveAffirmations(List<String> affirmations)` - Save affirmations
- ✅ `savePriorities(List<String> priorities)` - Save priorities
- ✅ `saveMeals({breakfast, lunch, dinner, waterCups})` - Save meals
- ✅ `saveSelfCare(EntrySelfCare selfCare)` - Save self-care
- ✅ `saveGratitude(List<String> gratitude)` - Save gratitude
- ✅ `saveTomorrow(List<String> tomorrow)` - Save tomorrow notes
- ✅ `clearEntry()` - Clear entry

**Used In:**
- `lib/screens/new_diary_screen.dart`

---

### 5. `font_size_provider.dart`
**Status:** ✅ **Used in New UI**

**Providers:**
- ✅ `fontSizeProvider` - Font size state (Small, Medium, Large)

**Used In:**
- `lib/screens/settings_screen.dart`
- `lib/screens/new_diary_screen.dart` (if paper style is used)

---

### 6. `grace_system_provider.dart`
**Status:** ✅ **Used in New UI**

**Providers:**
- ✅ `graceSystemProvider` - Grace system state

**Used In:**
- `lib/screens/home_screen.dart`
- `lib/screens/new_diary_screen.dart`
- `lib/screens/settings_screen.dart`

---

### 7. `history_provider.dart`
**Status:** ✅ **Used in New UI**

**Providers:**
- ✅ `historyProvider` - History state management

**Methods:**
- ✅ `loadEntries(DateTime month)` - Load entries for month
- ✅ `searchEntries(String query)` - Search entries
- ✅ `filterByMood(int? mood)` - Filter by mood
- ✅ `toggleViewMode()` - Toggle calendar/list view
- ✅ `selectMonth(DateTime month)` - Select month

**Used In:**
- `lib/screens/history_screen.dart`

---

### 8. `home_summary_provider.dart`
**Status:** ✅ **Used in New UI**

**Providers:**
- ✅ `homeSummaryProvider` - Home summary data
- ✅ `aiInsightProvider` - AI insight (deprecated)
- ✅ `recentInsightsProvider` - Recent insights
- ✅ `yesterdayInsightProvider` - Yesterday's insight

**Used In:**
- `lib/screens/home_screen.dart`

---

### 9. `paper_style_provider.dart`
**Status:** ✅ **Used in New UI**

**Providers:**
- ✅ `paperStyleProvider` - Paper style state (Plain, Ruled, Grid)

**Used In:**
- `lib/screens/settings_screen.dart`
- `lib/screens/new_diary_screen.dart` (if paper style is used)

---

### 10. `privacy_lock_provider.dart`
**Status:** ✅ **Used in New UI**

**Providers:**
- ✅ `privacyLockProvider` - Privacy lock state

**Used In:**
- `lib/screens/settings_screen.dart`
- `lib/screens/auth_wrapper.dart`

---

### 11. `recent_entries_provider.dart`
**Status:** ✅ **Used in New UI**

**Providers:**
- ✅ `recentEntriesProvider` - Recent entries for home screen

**Used In:**
- `lib/screens/home_screen.dart`

---

### 12. `streak_compassion_provider.dart`
**Status:** ✅ **Used in New UI**

**Providers:**
- ✅ `streakCompassionProvider` - Streak and compassion state

**Used In:**
- `lib/screens/home_screen.dart`

---

### 13. `sync_status_provider.dart`
**Status:** ✅ **Used in New UI**

**Providers:**
- ✅ `syncStatusProvider` - Sync status state (syncing, saved, error)

**Used In:**
- `lib/screens/new_diary_screen.dart` (sync status icon)
- `lib/providers/entry_provider.dart` (internal)

---

### 14. `theme_provider.dart`
**Status:** ✅ **Used in New UI**

**Providers:**
- ✅ `themeProvider` - Theme mode (Light, Dark, System)

**Used In:**
- `lib/screens/settings_screen.dart`
- `lib/main.dart` (app theme)

---

### 15. `user_data_provider.dart`
**Status:** ✅ **Used in New UI**

**Providers:**
- ✅ `userDataProvider` - User data state
- ✅ `userStatsProvider` - User statistics
- ✅ `userPreferencesProvider` - User preferences
- ✅ `wellnessDataProvider` - Wellness data
- ✅ `gratitudeDataProvider` - Gratitude data
- ✅ `morningRitualsDataProvider` - Morning rituals data
- ✅ `analyticsDataProvider` - Analytics data

**Used In:**
- `lib/screens/profile_screen.dart`
- `lib/screens/home_screen.dart`

---

## 🖼️ WIDGETS (16 Total)

### 1. `app_drawer.dart`
**Status:** ❌ **DELETED** ✅ (Replaced by Bottom Navigation)

**Widgets:**
- ❌ `AppDrawer` - Old drawer navigation (deleted)

**Action Taken:** 🗑️ **DELETED** - Removed from `notification_test_screen.dart` and file deleted

---

### 2. `bottom_navigation_bar.dart`
**Status:** ✅ **Used in New UI**

**Widgets:**
- ✅ `AppBottomNavigationBar` - Bottom navigation bar
- ✅ `navigateToScreen(BuildContext context, int index)` - Navigation helper

**Used In:**
- `lib/screens/home_screen.dart`
- `lib/screens/history_screen.dart`
- `lib/screens/analytics_screen.dart`
- `lib/screens/profile_screen.dart`

---

### 3. `daily_insights_timeline.dart`
**Status:** ✅ **Used in New UI**

**Widgets:**
- ✅ `DailyInsightsTimeline` - Timeline of daily insights

**Used In:**
- `lib/screens/analytics_screen.dart`

---

### 4. `day_details_bottom_sheet.dart`
**Status:** ✅ **Used in New UI**

**Widgets:**
- ✅ `DayDetailsBottomSheet` - Bottom sheet showing day details

**Used In:**
- `lib/screens/analytics_screen.dart` (when clicking chart bars)

---

### 5. `dynamic_field_section.dart`
**Status:** ❌ **DELETED** ✅ (Replaced by inline implementation)

**Widgets:**
- ❌ `DynamicFieldSection` - Dynamic input fields (affirmations, priorities, gratitude, tomorrow) (deleted)

**Action Taken:** 🗑️ **DELETED** - File removed

---

### 6. `grace_system_info_card.dart`
**Status:** ✅ **Used in New UI**

**Widgets:**
- ✅ `GraceSystemInfoCard` - Grace system information card

**Used In:**
- `lib/screens/home_screen.dart` (if displayed)
- `lib/screens/settings_screen.dart` (Grace System section)

---

### 7. `habit_correlations_card.dart`
**Status:** ✅ **Used in New UI**

**Widgets:**
- ✅ `HabitCorrelationsCard` - Habit correlations visualization

**Used In:**
- `lib/screens/analytics_screen.dart`

---

### 8. `interactive_bar_chart.dart`
**Status:** ✅ **Used in New UI**

**Widgets:**
- ✅ `InteractiveBarChart` - Interactive bar chart for analytics

**Used In:**
- `lib/screens/analytics_screen.dart`

---

### 9. `mini_calendar_widget.dart`
**Status:** ✅ **Used in New UI**

**Widgets:**
- ✅ `MiniCalendarWidget` - Mini calendar for week selection

**Used In:**
- `lib/screens/analytics_screen.dart`

---

### 10. `paper_background.dart`
**Status:** ❌ **DELETED** ✅ (Removed from New Entry Screen)

**Widgets:**
- ❌ `PaperBackground` - Paper style background (deleted)

**Action Taken:** 🗑️ **DELETED** - File removed

---

### 11. `period_comparison_card.dart`
**Status:** ✅ **Used in New UI**

**Widgets:**
- ✅ `PeriodComparisonCard` - Period comparison visualization

**Used In:**
- `lib/screens/analytics_screen.dart`

---

### 12. `pin_number_pad.dart`
**Status:** ✅ **Used in New UI**

**Widgets:**
- ✅ `PinNumberPad` - PIN input number pad

**Used In:**
- `lib/screens/pin_setup_screen.dart`
- `lib/screens/pin_lock_screen.dart`
- `lib/screens/change_pin_screen.dart`
- `lib/screens/pin_recovery_screen.dart`

---

### 13. `saveable_section.dart`
**Status:** ❌ **DELETED** ✅ (Replaced by auto-save)

**Widgets:**
- ❌ `SaveableSection` - Section with save functionality (deleted)

**Action Taken:** 🗑️ **DELETED** - File removed

---

### 14. `streak_display_widget.dart`
**Status:** ❌ **DELETED** ✅ (Replaced by custom cards)

**Widgets:**
- ❌ `StreakDisplayWidget` - Old streak display widget (deleted)

**Action Taken:** 🗑️ **DELETED** - File removed

---

### 15. `week_chips_carousel.dart`
**Status:** ✅ **Used in New UI**

**Widgets:**
- ✅ `WeekChipsCarousel` - Week selection chips carousel

**Used In:**
- `lib/screens/analytics_screen.dart`

---

### 16. `yesterday_insight_card.dart`
**Status:** ✅ **Used in New UI**

**Widgets:**
- ✅ `YesterdayInsightCard` - Yesterday's insight card

**Used In:**
- `lib/screens/home_screen.dart`

---

## 📱 SCREENS (25 Total)

### Active Screens (Used in New UI)

1. ✅ **`home_screen.dart`** - Home Screen (redesigned)
2. ✅ **`new_diary_screen.dart`** - New Entry Screen (merged Morning Rituals, Wellness, Gratitude)
3. ✅ **`history_screen.dart`** - History Screen (redesigned)
4. ✅ **`analytics_screen.dart`** - Analytics Screen (redesigned)
5. ✅ **`profile_screen.dart`** - Profile Screen (redesigned)
6. ✅ **`settings_screen.dart`** - Settings Screen (redesigned, merged Help & Support)
7. ✅ **`splash_screen.dart`** - Splash Screen (theme updated)

### Auth Screens (Kept Separate)

8. ✅ **`login_screen.dart`** - Login Screen
9. ✅ **`register_screen.dart`** - Register Screen
10. ✅ **`auth_wrapper.dart`** - Auth Wrapper (privacy lock logic)

### Security Screens (Kept Separate)

11. ✅ **`pin_setup_screen.dart`** - PIN Setup Screen
12. ✅ **`pin_lock_screen.dart`** - PIN Lock Screen
13. ✅ **`change_pin_screen.dart`** - Change PIN Screen
14. ✅ **`pin_recovery_screen.dart** - PIN Recovery Screen
15. ✅ **`security_questions_screen.dart`** - Security Questions Screen

### Legal/Support Screens (Merged into Settings)

16. 🔄 **`help_support_screen.dart`** - **Merged into Settings Screen** (Help & Support section)
17. 🔄 **`my_tickets_screen.dart`** - **Merged into Settings Screen** (part of Help & Support)
18. 🔄 **`privacy_policy_screen.dart`** - **Merged into Settings Screen** (link in About section)
19. 🔄 **`terms_screen.dart`** - **Merged into Settings Screen** (link in About section)

### Removed/Merged Screens

20. ❌ **`diary_screen.dart`** - **DELETED** ✅ (functionality merged into New Entry Screen)
21. ❌ **`morning_rituals_screen.dart`** - **DELETED** ✅ (merged into New Entry Screen)
22. ❌ **`wellness_tracker_screen.dart`** - **DELETED** ✅ (merged into New Entry Screen)
23. ❌ **`gratitude_reflection_screen.dart`** - **DELETED** ✅ (merged into New Entry Screen)
24. ✅ **`yesterday_insight_screen.dart`** - **KEPT** (used when clicking Yesterday Insight card on Home Screen)

### Dev/Test Screens

25. ⏳ **`notification_test_screen.dart`** - **Dev Only** (not user-facing)

**Action Required:**
- 🗑️ Remove unused screens: `diary_screen.dart`, `morning_rituals_screen.dart`, `wellness_tracker_screen.dart`, `gratitude_reflection_screen.dart`, `yesterday_insight_screen.dart`
- 🔄 Keep merged screens but mark as deprecated: `help_support_screen.dart`, `my_tickets_screen.dart`, `privacy_policy_screen.dart`, `terms_screen.dart` (still accessible via Settings)

---

## 🎯 SUMMARY & ACTION ITEMS

### ✅ Fully Used Components
- **Services:** 22/22 (100%)
- **Providers:** 15/15 (100%)
- **Active Screens:** 15/25 (60%)
- **Widgets:** 12/16 (75%)

### ❌ Not Used Components (Verified)
- **Widgets:** 5/16
  - `app_drawer.dart` (replaced by bottom navigation)
  - `dynamic_field_section.dart` (replaced by inline implementation)
  - `paper_background.dart` (removed from New Entry Screen)
  - `saveable_section.dart` (replaced by auto-save)
  - `streak_display_widget.dart` (replaced by custom cards)

### ❌ Not Used / Can Be Removed
1. **Widgets:**
   - 🗑️ `app_drawer.dart` (replaced by bottom navigation)
   - 🗑️ `dynamic_field_section.dart` (replaced by inline implementation)
   - 🗑️ `paper_background.dart` (removed from New Entry Screen)
   - 🗑️ `saveable_section.dart` (replaced by auto-save)
   - 🗑️ `streak_display_widget.dart` (replaced by custom cards)

2. **Screens:**
   - 🗑️ `diary_screen.dart` (merged into New Entry Screen)
   - 🗑️ `morning_rituals_screen.dart` (merged into New Entry Screen)
   - 🗑️ `wellness_tracker_screen.dart` (merged into New Entry Screen)
   - 🗑️ `gratitude_reflection_screen.dart` (merged into New Entry Screen)
   - 🗑️ `yesterday_insight_screen.dart` (merged into Home Screen)

### 🔄 Merged Components (Keep but Deprecate)
- `help_support_screen.dart` (merged into Settings)
- `my_tickets_screen.dart` (merged into Settings)
- `privacy_policy_screen.dart` (merged into Settings)
- `terms_screen.dart` (merged into Settings)

### 📋 Next Steps
1. ✅ ~~Verify usage of partially used widgets~~ **COMPLETED**
2. 🗑️ Remove unused screens and widgets (5 widgets + 5 screens)
3. 📝 Update navigation routes to remove references to deleted screens
4. 🔍 Audit imports to ensure no broken references
5. ✅ Test all functionality after cleanup

---

**Last Updated:** December 2024  
**Status:** Comprehensive audit complete, ready for cleanup actions

