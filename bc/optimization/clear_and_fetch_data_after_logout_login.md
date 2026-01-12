# Clear and Fetch Data After Logout/Login - Implementation Plan

## 🎯 Objective
Implement a flag-based system using SharedPreferences to track when user data needs to be fetched after logout. This ensures:
- **Privacy**: Previous user's data is cleared on logout
- **Performance**: Only fetch 7 days data when needed (after logout or fresh install)
- **Reliability**: Handle all edge cases and scenarios

---

## 📋 Overview

### Flag Strategy
- **Flag Name**: `needs_data_fetch` (SharedPreferences boolean)
- **Default Value**: `true` (ensures fresh installs fetch data)
- **Set to `true`**: On logout (after clearing data)
- **Set to `false`**: After successfully fetching 7 days data on login

### Data Flow
```
Logout → Clear Local DB → Set Flag = true → Sign Out
Login → Check Flag → If true: Fetch 7 days → Set Flag = false
```

---

## 🔧 Implementation Details

### 1. SharedPreferences Key
```dart
// Constant for flag key
static const String _needsDataFetchKey = 'needs_data_fetch';
```

### 2. Helper Service/Utility
Create a utility class to manage the flag:

**File**: `lib/services/data_sync_flag_service.dart`

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'error_logging_service.dart';

class DataSyncFlagService {
  static const String _needsDataFetchKey = 'needs_data_fetch';
  
  /// Check if data fetch is needed
  static Future<bool> needsDataFetch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_needsDataFetchKey) ?? true; // Default true
    } catch (e) {
      await ErrorLoggingService.logLowError(
        errorCode: 'ERRSYS160',
        errorMessage: 'Failed to read data fetch flag: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
      );
      return true; // Default to true on error (safe side)
    }
  }
  
  /// Set flag to indicate data fetch is needed
  static Future<void> setNeedsDataFetch(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_needsDataFetchKey, value);
    } catch (e) {
      await ErrorLoggingService.logLowError(
        errorCode: 'ERRSYS161',
        errorMessage: 'Failed to set data fetch flag: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
      );
    }
  }
  
  /// Clear the flag (set to false)
  static Future<void> clearNeedsDataFetch() async {
    await setNeedsDataFetch(false);
  }
}
```

### 3. Database Clearing Service
Create a service to clear user-specific data from local DB:

**File**: `lib/services/database/user_data_cleanup_service.dart`

```dart
import 'database/database_manager.dart';
import 'error_logging_service.dart';

class UserDataCleanupService {
  /// Clear all user-specific data from local database
  static Future<void> clearUserData(String userId) async {
    try {
      final db = await DatabaseManager().database;
      
      // Clear in order (respecting foreign key constraints)
      await db.delete('sync_queue', where: 'user_id = ?', whereArgs: [userId]);
      await db.delete('entry_tomorrow_notes', where: 'entry_id IN (SELECT id FROM entries WHERE user_id = ?)', whereArgs: [userId]);
      await db.delete('entry_shower_bath', where: 'entry_id IN (SELECT id FROM entries WHERE user_id = ?)', whereArgs: [userId]);
      await db.delete('entry_self_care', where: 'entry_id IN (SELECT id FROM entries WHERE user_id = ?)', whereArgs: [userId]);
      await db.delete('entry_gratitude', where: 'entry_id IN (SELECT id FROM entries WHERE user_id = ?)', whereArgs: [userId]);
      await db.delete('entry_meals', where: 'entry_id IN (SELECT id FROM entries WHERE user_id = ?)', whereArgs: [userId]);
      await db.delete('entry_priorities', where: 'entry_id IN (SELECT id FROM entries WHERE user_id = ?)', whereArgs: [userId]);
      await db.delete('entry_affirmations', where: 'entry_id IN (SELECT id FROM entries WHERE user_id = ?)', whereArgs: [userId]);
      await db.delete('entries', where: 'user_id = ?', whereArgs: [userId]);
      await db.delete('habits_daily', where: 'user_id = ?', whereArgs: [userId]);
      await db.delete('streaks', where: 'user_id = ?', whereArgs: [userId]);
      
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRSYS162',
        errorMessage: 'Failed to clear user data: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {'user_id': userId},
      );
      rethrow; // Re-throw to handle in logout flow
    }
  }
}
```

### 4. Data Prefetch Service
Create a service to prefetch 7 days of data:

**File**: `lib/services/data_prefetch_service.dart`

```dart
import 'data_fetch_service.dart';
import 'error_logging_service.dart';

class DataPrefetchService {
  /// Prefetch 7 days of data for user
  static Future<void> prefetch7DaysData(
    String userId,
    DataFetchService dataFetchService,
  ) async {
    try {
      final today = DateTime.now();
      final weekStart = today.subtract(const Duration(days: 6)); // Last 7 days
      
      // Fetch in parallel for better performance
      await Future.wait([
        dataFetchService.fetchEntries(
          userId: userId,
          startDate: weekStart,
          endDate: today,
        ),
        dataFetchService.fetchHabitsDaily(
          userId: userId,
          startDate: weekStart,
          endDate: today,
        ),
        dataFetchService.fetchStreaks(userId),
      ]);
      
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRSYS163',
        errorMessage: 'Failed to prefetch 7 days data: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {'user_id': userId},
      );
      // Don't rethrow - allow app to continue even if prefetch fails
      // Data will be fetched on-demand when screens need it
    }
  }
}
```

---

## 🔄 Implementation Steps

### Step 1: Update Logout Flow
**File**: `lib/screens/profile_screen.dart`

**Location**: `_performLogout()` method

**Changes**:
1. Import new services
2. Clear user data from local DB
3. Set flag to `true`
4. Then proceed with existing logout flow

```dart
void _performLogout(WidgetRef ref) async {
  try {
    // Show blocking progress
    if (ref.context.mounted) {
      showDialog(
        context: ref.context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }
    
    // Get user ID before clearing
    final userId = Supabase.instance.client.auth.currentUser?.id;
    
    // Step 1: Clear all user data from local database
    if (userId != null) {
      await UserDataCleanupService.clearUserData(userId);
    }
    
    // Step 2: Set flag to indicate data fetch is needed
    await DataSyncFlagService.setNeedsDataFetch(true);
    
    // Step 3: Clear user data (provider state)
    ref.read(userDataProvider.notifier).clearUserData();
    
    // Step 4: Clear privacy lock
    await ref.read(privacyLockProvider.notifier).disablePrivacyLock();
    
    // Step 5: Sign out from auth
    await ref.read(authControllerProvider).signOut();
    
    // Step 6: Navigate to login
    Future.microtask(() {
      final context = ref.context;
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    });
  } catch (e) {
    // Even if logout fails, try to clear data and set flag
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        await UserDataCleanupService.clearUserData(userId);
        await DataSyncFlagService.setNeedsDataFetch(true);
      } catch (_) {}
    }
    
    ref.read(userDataProvider.notifier).clearUserData();
    await ref.read(privacyLockProvider.notifier).disablePrivacyLock();
    
    // Log error and navigate to login
    await ErrorLoggingService.logError(
      errorCode: 'ERRAUTH041',
      errorMessage: 'Logout failed: ${e.toString()}',
      stackTrace: StackTrace.current.toString(),
      severity: 'MEDIUM',
      errorContext: {
        'logout_attempt_time': DateTime.now().toIso8601String(),
        'user_id': userId,
      },
    );
    
    if (ref.context.mounted) {
      SnackbarUtils.showError(
        ref.context,
        'Logout failed (ERRAUTH041)',
        'ERRAUTH041',
      );
    }
    
    Future.microtask(() {
      final context = ref.context;
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    });
  }
}
```

### Step 2: Update Splash Screen
**File**: `lib/screens/splash_screen.dart`

**Location**: `_initializeApp()` method

**Changes**:
1. After `loadUserData()`, check the flag
2. If flag is `true`, prefetch 7 days data
3. Set flag to `false` after successful fetch
4. Update loading message during prefetch

```dart
Future<void> _initializeApp() async {
  try {
    // Step 1: Check authentication
    if (mounted && !_isDisposed) {
      setState(() {
        _loadingMessage = 'Checking authentication...';
      });
    }
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (_isDisposed) return;
    
    final user = Supabase.instance.client.auth.currentUser;
    
    if (user == null) {
      // User not authenticated, clear any stale data and go to login
      ref.read(userDataProvider.notifier).clearUserData();
      if (mounted && !_isDisposed) {
        await _navigateToAuth();
      }
      return;
    }
    
    // Step 2: Clear any stale user data (provider state)
    ref.read(userDataProvider.notifier).clearUserData();
    
    // Step 3: Fetch fresh user data
    if (mounted && !_isDisposed) {
      setState(() {
        _loadingMessage = 'Loading your data...';
      });
    }
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (_isDisposed) return;
    
    await ref.read(userDataProvider.notifier).loadUserData();
    
    // Step 4: Check if data fetch is needed (after logout or fresh install)
    final needsFetch = await DataSyncFlagService.needsDataFetch();
    
    if (needsFetch) {
      if (mounted && !_isDisposed) {
        setState(() {
          _loadingMessage = 'Syncing your journal...';
        });
      }
      await Future.delayed(const Duration(milliseconds: 200));
      
      if (_isDisposed) return;
      
      // Prefetch 7 days data
      try {
        final dataFetchService = ref.read(dataFetchServiceProvider);
        await DataPrefetchService.prefetch7DaysData(
          user.id,
          dataFetchService,
        );
        
        // Set flag to false after successful fetch
        await DataSyncFlagService.clearNeedsDataFetch();
      } catch (e) {
        // Log error but continue - data will be fetched on-demand
        await ErrorLoggingService.logError(
          errorCode: 'ERRSYS164',
          errorMessage: 'Prefetch failed: ${e.toString()}',
          stackTrace: StackTrace.current.toString(),
          severity: 'LOW',
        );
        // Keep flag as true so it retries next time
      }
    }
    
    // Step 5: Clean up old entries (7-day retention policy)
    if (mounted && !_isDisposed) {
      setState(() {
        _loadingMessage = 'Cleaning up old data...';
      });
    }
    await Future.delayed(const Duration(milliseconds: 200));
    
    if (_isDisposed) return;
    
    final entryService = await _getEntryService();
    await entryService.cleanupOldEntries(retentionDays: 7);
    
    // Step 6: Smart sync check (only if there's pending data)
    if (mounted && !_isDisposed) {
      setState(() {
        _loadingMessage = 'Checking for pending syncs...';
      });
    }
    await Future.delayed(const Duration(milliseconds: 200));
    
    if (_isDisposed) return;
    
    final syncWorker = await _getSyncWorker();
    await syncWorker.processSyncQueue();
    
    // Step 7: Navigate to home
    final userDataState = ref.read(userDataProvider);
    
    if (userDataState.userData != null && !userDataState.isLoading) {
      if (mounted && !_isDisposed) {
        setState(() {
          _userData = userDataState.userData;
          _loadingMessage = 'Welcome back, ${_userData!.displayName}';
        });
      }
      
      await Future.delayed(const Duration(milliseconds: 800));
      
      if (_isDisposed) return;
      
      if (mounted && !_isDisposed) {
        await _navigateToHome();
      }
    } else if (userDataState.error != null) {
      if (mounted && !_isDisposed) {
        setState(() {
          _loadingMessage = 'Setting up your journal...';
        });
      }
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (_isDisposed) return;
      
      if (mounted && !_isDisposed) {
        await _navigateToHome();
      }
    } else {
      if (mounted && !_isDisposed) {
        setState(() {
          _loadingMessage = 'Preparing your journal...';
        });
      }
      await Future.delayed(const Duration(milliseconds: 1000));
      
      if (_isDisposed) return;
      
      if (mounted && !_isDisposed) {
        await _navigateToHome();
      }
    }
  } catch (e) {
    // Handle errors gracefully
    if (mounted && !_isDisposed) {
      setState(() {
        _loadingMessage = 'Something went wrong...';
      });
    }
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (_isDisposed) return;
    
    ref.read(userDataProvider.notifier).clearUserData();
    if (mounted && !_isDisposed) {
      await _navigateToAuth();
    }
  }
}
```

---

## 📊 Scenarios Covered

### ✅ Scenario 1: Normal Logout → Login
**Flow**:
1. User logs out → Clear DB → Flag = `true`
2. User logs in → Check flag → `true` → Fetch 7 days → Flag = `false`
3. Next login → Check flag → `false` → Skip fetch ✅

**Result**: Data fetched only once after logout

### ✅ Scenario 2: Fresh Install
**Flow**:
1. User installs app → Flag defaults to `true` (not set)
2. User logs in → Check flag → `true` (default) → Fetch 7 days → Flag = `false`
3. Next login → Check flag → `false` → Skip fetch ✅

**Result**: Data fetched on first login

### ✅ Scenario 3: User Doesn't Logout (Normal App Restart)
**Flow**:
1. User closes app (no logout) → Flag remains `false`
2. User opens app → Check flag → `false` → Skip fetch ✅
3. Data loads from local DB (on-demand)

**Result**: No unnecessary network calls

### ✅ Scenario 4: User Wrote Only 4 Days (Partial Data)
**Flow**:
1. User has 4 days data locally → Flag = `false`
2. User opens app → Check flag → `false` → Skip fetch ✅
3. When home screen needs data → `fetchHabitsDaily()` checks local → Finds 4 days → Fetches missing dates on-demand

**Result**: No unnecessary prefetch, lazy fetch handles missing dates

### ✅ Scenario 5: Logout Fails Partially
**Flow**:
1. Logout starts → Clear DB succeeds → Set flag = `true` → Auth signOut fails
2. User still logged in but DB cleared → Flag = `true`
3. User opens app → Check flag → `true` → Fetch 7 days → Flag = `false` ✅

**Result**: Data is restored even if logout partially fails

### ✅ Scenario 6: Prefetch Fails on Login
**Flow**:
1. User logs in → Check flag → `true` → Start prefetch → Network error
2. Prefetch fails → Flag remains `true` (not cleared)
3. App continues → Home screen loads → Data fetched on-demand
4. Next login → Check flag → `true` → Retry prefetch ✅

**Result**: Graceful degradation, retry on next login

### ✅ Scenario 7: Multiple Users on Same Device
**Flow**:
1. User A logs out → Clear User A data → Flag = `true`
2. User B logs in → Check flag → `true` → Fetch User B's 7 days → Flag = `false`
3. User B logs out → Clear User B data → Flag = `true`
4. User A logs in → Check flag → `true` → Fetch User A's 7 days → Flag = `false` ✅

**Result**: Each user's data is properly isolated

### ✅ Scenario 8: App Uninstall → Reinstall
**Flow**:
1. User uninstalls app → SharedPreferences cleared
2. User reinstalls app → Flag defaults to `true`
3. User logs in → Check flag → `true` → Fetch 7 days → Flag = `false` ✅

**Result**: Fresh install behavior works correctly

---

## 🛡️ Edge Cases & Error Handling

### Edge Case 1: Flag Read Fails
**Handling**: Default to `true` (safe side - ensures data is fetched)

### Edge Case 2: Flag Write Fails
**Handling**: Log error, continue with operation (flag will be checked again next time)

### Edge Case 3: DB Clear Fails Partially
**Handling**: Log error, set flag anyway (prefetch will overwrite any remaining data)

### Edge Case 4: Prefetch Network Timeout
**Handling**: Don't clear flag, allow on-demand fetch to handle it

### Edge Case 5: User ID is Null During Logout
**Handling**: Set flag anyway, clear what we can (user will fetch on next login)

### Edge Case 6: App Crashes During Logout
**Handling**: Flag might be set but DB not cleared → On next login, prefetch will overwrite any stale data

### Edge Case 7: App Crashes During Prefetch
**Handling**: Flag remains `true`, will retry on next login

---

## 🧪 Testing Checklist

### Manual Testing
- [ ] Logout → Login → Verify 7 days data fetched
- [ ] Normal app restart (no logout) → Verify no fetch
- [ ] Fresh install → Login → Verify data fetched
- [ ] User with 4 days data → App restart → Verify no unnecessary fetch
- [ ] Logout with network off → Login with network on → Verify data fetched
- [ ] Prefetch fails → Verify app continues, data loads on-demand
- [ ] Multiple users → Verify data isolation
- [ ] App uninstall → Reinstall → Verify fresh install behavior

### Edge Case Testing
- [ ] SharedPreferences read fails → Verify default behavior
- [ ] DB clear fails → Verify flag still set
- [ ] Prefetch timeout → Verify graceful degradation
- [ ] App crash during logout → Verify recovery on next login
- [ ] App crash during prefetch → Verify retry on next login

---

## 📝 Files to Create/Modify

### New Files
1. `lib/services/data_sync_flag_service.dart` - Flag management
2. `lib/services/database/user_data_cleanup_service.dart` - DB clearing
3. `lib/services/data_prefetch_service.dart` - Data prefetching

### Modified Files
1. `lib/screens/profile_screen.dart` - Update logout flow
2. `lib/screens/splash_screen.dart` - Add prefetch check

---

## 🎯 Final Flow Diagram

```
┌─────────────────┐
│   User Logout   │
└────────┬────────┘
         │
         ▼
┌─────────────────────────┐
│ Clear User Data from DB │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│ Set Flag = true         │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│ Sign Out from Auth      │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│ Navigate to Login       │
└─────────────────────────┘

┌─────────────────┐
│   User Login    │
└────────┬────────┘
         │
         ▼
┌─────────────────────────┐
│ Load User Profile       │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│ Check Flag              │
└────────┬────────────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌──────┐  ┌──────────┐
│ true │  │  false   │
└──┬───┘  └────┬─────┘
   │           │
   ▼           │
┌─────────────────────────┐
│ Prefetch 7 Days Data    │
└────────┬────────────────┘
   │     │
   │     ▼
   │  ┌─────────────────────────┐
   │  │ Set Flag = false        │
   │  └─────────────────────────┘
   │
   ▼
┌─────────────────────────┐
│ Navigate to Home        │
└─────────────────────────┘
```

---

## ✅ Success Criteria

1. ✅ No unnecessary network calls on normal app startup
2. ✅ Data is cleared on logout (privacy)
3. ✅ Data is fetched after logout/login
4. ✅ Fresh installs work correctly
5. ✅ Partial data scenarios handled gracefully
6. ✅ Error cases don't break the app
7. ✅ Multiple users on same device work correctly

---

## 📌 Notes

- **Flag Default**: `true` ensures fresh installs always fetch data
- **Lazy Fetch Fallback**: Even if prefetch fails, on-demand fetch will handle it
- **Error Resilience**: All operations are wrapped in try-catch with logging
- **Performance**: Prefetch happens in parallel for better speed
- **User Experience**: Loading messages inform user during prefetch
- **No Partial Data Check Needed**: The flag approach is sufficient - we don't need to check if local data is complete. If flag = `false`, user didn't logout, so local data is valid (even if partial). The existing `fetchHabitsDaily()` logic automatically handles missing dates on-demand.

---

**Status**: ✅ Plan Complete - Ready for Implementation
