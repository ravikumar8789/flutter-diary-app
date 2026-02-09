# Error Logging Optimization - Implementation Plan

## 🎯 **Goal**
Migrate from parameter-based error logging to model-based logging to:
- Reduce ~1,000 lines of duplicate code
- Improve maintainability (single source of truth)
- Follow DRY principles
- Ensure type safety

## ⚠️ **Critical Safety Requirement**
**Error logging must NEVER fail** - if error logging fails, it should fail silently to prevent infinite loops or app crashes. All error logging code must be wrapped in try-catch with fallback to console.

---

## 📋 **Implementation Phases**

### **Phase 1: Update Error Models** ✅ Foundation
**Files:** `lib/models/error_models.dart`

**Changes:**
1. Add `stackTrace` field to `ErrorContext`
2. Add factory constructor `ErrorContext.create()` for easy creation
3. Add `copyWith()` method for convenience
4. Update `toJson()` to include `stack_trace` and map correctly to DB schema
5. Add `fromException()` factory for automatic error extraction

**Why:** Models are the foundation - must be correct before service changes.

---

### **Phase 2: Refactor ErrorLoggingService** ✅ Core Service
**Files:** `lib/services/error_logging_service.dart`

**Changes:**
1. Add new `logError(ErrorContext error)` method that accepts model
2. Keep old parameter-based methods (deprecated) for backward compatibility
3. Update convenience methods (`logHighError`, etc.) to accept model OR parameters
4. Ensure all error logging is wrapped in try-catch (never throw)
5. Use model's `toJson()` instead of manual mapping

**Why:** Service must support both old and new patterns during migration.

---

### **Phase 3: Migrate Error Logging Calls** ✅ Application Code
**Files:** 52 files with 220 error logging calls

**Strategy:** Migrate file by file, category by category

**Order:**
1. Screens (13 files, 25 calls)
2. Services (24 files, 130 calls)
3. Providers (12 files, 37 calls)
4. Repositories (1 file, 12 calls)
5. Widgets (1 file, 5 calls)

**Why:** Systematic migration reduces risk, easier to test incrementally.

---

## 🔧 **Detailed Implementation Steps**

### **STEP 1: Update ErrorContext Model**

**File:** `lib/models/error_models.dart`

**Changes:**

```dart
class ErrorContext {
  final String errorCode;
  final String errorMessage;
  final String? stackTrace;  // ADD THIS
  final String severity;
  final DateTime timestamp;
  final String? userId;
  final String? sessionId;
  final Map<String, dynamic>? screenStack;
  final Map<String, dynamic>? errorContext;
  final int retryCount;
  final String? syncStatus;

  const ErrorContext({
    required this.errorCode,
    required this.errorMessage,
    this.stackTrace,  // ADD THIS
    required this.severity,
    required this.timestamp,
    this.userId,
    this.sessionId,
    this.screenStack,
    this.errorContext,
    this.retryCount = 0,
    this.syncStatus,
  });

  // ADD: Factory constructor for easy creation
  factory ErrorContext.create({
    required String errorCode,
    required String errorMessage,
    required ErrorSeverity severity,
    String? stackTrace,
    Map<String, dynamic>? errorContext,
    int retryCount = 0,
  }) {
    return ErrorContext(
      errorCode: errorCode,
      errorMessage: errorMessage,
      stackTrace: stackTrace,
      severity: severity.value,
      timestamp: DateTime.now(),
      errorContext: errorContext,
      retryCount: retryCount,
    );
  }

  // ADD: Factory from exception
  factory ErrorContext.fromException({
    required String errorCode,
    required ErrorSeverity severity,
    required Object exception,
    StackTrace? stackTrace,
    Map<String, dynamic>? errorContext,
  }) {
    return ErrorContext(
      errorCode: errorCode,
      errorMessage: exception.toString(),
      stackTrace: stackTrace?.toString(),
      severity: severity.value,
      timestamp: DateTime.now(),
      errorContext: errorContext,
    );
  }

  // ADD: CopyWith method
  ErrorContext copyWith({
    String? errorCode,
    String? errorMessage,
    String? stackTrace,
    String? severity,
    DateTime? timestamp,
    String? userId,
    String? sessionId,
    Map<String, dynamic>? screenStack,
    Map<String, dynamic>? errorContext,
    int? retryCount,
    String? syncStatus,
  }) {
    return ErrorContext(
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      stackTrace: stackTrace ?? this.stackTrace,
      severity: severity ?? this.severity,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
      sessionId: sessionId ?? this.sessionId,
      screenStack: screenStack ?? this.screenStack,
      errorContext: errorContext ?? this.errorContext,
      retryCount: retryCount ?? this.retryCount,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  // UPDATE: toJson to include stack_trace
  Map<String, dynamic> toJson() {
    return {
      'error_code': errorCode,
      'error_message': errorMessage,
      'stack_trace': stackTrace,  // ADD THIS
      'error_severity': severity,
      'created_at': timestamp.toIso8601String(),
      'user_id': userId,
      'session_id': sessionId,
      'screen_stack': screenStack,
      'error_context': errorContext,
      'retry_count': retryCount,
      'sync_status': syncStatus,
    };
  }
}
```

**Testing:** Unit test model creation and serialization.

---

### **STEP 2: Refactor ErrorLoggingService**

**File:** `lib/services/error_logging_service.dart`

**Changes:**

```dart
import '../models/error_models.dart';  // ADD IMPORT

class ErrorLoggingService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // NEW: Primary method using model
  static Future<void> logError(ErrorContext error) async {
    try {
      // Auto-populate missing fields
      final enrichedError = error.copyWith(
        userId: error.userId ?? _supabase.auth.currentUser?.id,
        sessionId: error.sessionId ?? _generateSessionId(),
        screenStack: error.screenStack ?? _getCurrentScreenStack(),
        syncStatus: error.syncStatus ?? _getCurrentSyncStatus(),
      );

      // Collect additional context
      final additionalContext = _collectErrorContext(
        errorCode: enrichedError.errorCode,
        errorMessage: enrichedError.errorMessage,
        additionalContext: enrichedError.errorContext,
      );

      // Merge additional context into error_context field
      final finalError = enrichedError.copyWith(
        errorContext: {
          ...?enrichedError.errorContext,
          ...additionalContext,
        },
      );

      // Insert using model's toJson
      await _supabase.from('error_logs').insert(finalError.toJson());
    } catch (e) {
      // CRITICAL: Never throw - error logging must never fail
      if (kDebugMode) {
        print('ERROR: Failed to log error to Supabase: $e');
        print('Original error: ${error.errorCode} - ${error.errorMessage}');
      }
      // Silently fail - don't break app
    }
  }

  // DEPRECATED: Keep for backward compatibility during migration
  @Deprecated('Use ErrorContext model instead')
  static Future<void> logError({
    required String errorCode,
    required String errorMessage,
    String? stackTrace,
    required String severity,
    String? userId,
    String? sessionId,
    Map<String, dynamic>? screenStack,
    Map<String, dynamic>? errorContext,
    int retryCount = 0,
    String? syncStatus,
  }) async {
    // Convert to model and call new method
    final error = ErrorContext(
      errorCode: errorCode,
      errorMessage: errorMessage,
      stackTrace: stackTrace,
      severity: severity,
      timestamp: DateTime.now(),
      userId: userId,
      sessionId: sessionId,
      screenStack: screenStack,
      errorContext: errorContext,
      retryCount: retryCount,
      syncStatus: syncStatus,
    );
    await logError(error);
  }

  // UPDATED: Convenience methods - accept model OR parameters
  static Future<void> logCriticalError(
    ErrorContext? error, {
    String? errorCode,
    String? errorMessage,
    String? stackTrace,
    Map<String, dynamic>? errorContext,
  }) async {
    if (error != null) {
      await logError(error.copyWith(severity: ErrorSeverity.critical.value));
    } else {
      await logError(
        ErrorContext.create(
          errorCode: errorCode!,
          errorMessage: errorMessage!,
          severity: ErrorSeverity.critical,
          stackTrace: stackTrace,
          errorContext: errorContext,
        ),
      );
    }
  }

  static Future<void> logHighError(
    ErrorContext? error, {
    String? errorCode,
    String? errorMessage,
    String? stackTrace,
    Map<String, dynamic>? errorContext,
  }) async {
    if (error != null) {
      await logError(error.copyWith(severity: ErrorSeverity.high.value));
    } else {
      await logError(
        ErrorContext.create(
          errorCode: errorCode!,
          errorMessage: errorMessage!,
          severity: ErrorSeverity.high,
          stackTrace: stackTrace,
          errorContext: errorContext,
        ),
      );
    }
  }

  static Future<void> logMediumError(
    ErrorContext? error, {
    String? errorCode,
    String? errorMessage,
    String? stackTrace,
    Map<String, dynamic>? errorContext,
  }) async {
    if (error != null) {
      await logError(error.copyWith(severity: ErrorSeverity.medium.value));
    } else {
      await logError(
        ErrorContext.create(
          errorCode: errorCode!,
          errorMessage: errorMessage!,
          severity: ErrorSeverity.medium,
          stackTrace: stackTrace,
          errorContext: errorContext,
        ),
      );
    }
  }

  static Future<void> logLowError(
    ErrorContext? error, {
    String? errorCode,
    String? errorMessage,
    String? stackTrace,
    Map<String, dynamic>? errorContext,
  }) async {
    if (error != null) {
      await logError(error.copyWith(severity: ErrorSeverity.low.value));
    } else {
      await logError(
        ErrorContext.create(
          errorCode: errorCode!,
          errorMessage: errorMessage!,
          severity: ErrorSeverity.low,
          stackTrace: stackTrace,
          errorContext: errorContext,
        ),
      );
    }
  }

  // Keep all helper methods unchanged
  // ... _collectErrorContext, _generateSessionId, etc.
}
```

**Testing:** Test both old and new methods work, ensure no exceptions thrown.

---

### **STEP 3: Migration Pattern**

**Before (Current):**
```dart
await ErrorLoggingService.logHighError(
  errorCode: 'ERRSYS184',
  errorMessage: 'Prefetch failed: ${e.toString()}',
  stackTrace: StackTrace.current.toString(),
  errorContext: {
    'user_id': userId,
    'operation': 'prefetch',
  },
);
```

**After (New):**
```dart
await ErrorLoggingService.logHighError(
  ErrorContext.create(
    errorCode: 'ERRSYS184',
    errorMessage: 'Prefetch failed: ${e.toString()}',
    severity: ErrorSeverity.high,
    stackTrace: StackTrace.current.toString(),
    errorContext: {
      'user_id': userId,
      'operation': 'prefetch',
    },
  ),
);
```

**Or using fromException:**
```dart
await ErrorLoggingService.logHighError(
  ErrorContext.fromException(
    errorCode: 'ERRSYS184',
    severity: ErrorSeverity.high,
    exception: e,
    stackTrace: StackTrace.current,
    errorContext: {
      'user_id': userId,
      'operation': 'prefetch',
    },
  ),
);
```

---

## 📁 **Migration Order by Category**

### **Category 1: Screens (13 files, 25 calls)**
**Priority:** Medium (user-facing, testable)

1. `lib/screens/analytics_screen.dart` (3 calls)
2. `lib/screens/home_screen.dart` (2 calls)
3. `lib/screens/login_screen.dart` (2 calls)
4. `lib/screens/profile_screen.dart` (3 calls)
5. `lib/screens/register_screen.dart` (1 call)
6. `lib/screens/security_questions_screen.dart` (1 call)
7. `lib/screens/splash_screen.dart` (2 calls)
8. `lib/screens/pin_lock_screen.dart` (1 call)
9. `lib/screens/pin_recovery_screen.dart` (3 calls)
10. `lib/screens/pin_setup_screen.dart` (1 call)
11. `lib/screens/change_pin_screen.dart` (2 calls)
12. `lib/screens/help_support_screen.dart` (1 call)
13. `lib/screens/my_tickets_screen.dart` (1 call)

**Test:** Run app, trigger errors, verify logs in Supabase.

---

### **Category 2: Services (24 files, 130 calls)**
**Priority:** High (core functionality)

**Sub-category 2.1: Core Services (High Priority)**
1. `lib/services/error_logging_service.dart` (already done in Phase 2)
2. `lib/services/sync/supabase_sync_service.dart` (22 calls) - **CRITICAL**
3. `lib/services/user_data_service.dart` (15 calls) - **CRITICAL**
4. `lib/services/data_fetch_service.dart` (12 calls) - **CRITICAL**
5. `lib/services/data_prefetch_service.dart` (13 calls)
6. `lib/services/database/local_entry_service.dart` (9 calls) - **CRITICAL**
7. `lib/services/database/database_manager.dart` (2 calls) - **CRITICAL**
8. `lib/services/auth_service.dart` (6 calls) - **CRITICAL**
9. `lib/services/pin_auth_service.dart` (5 calls) - **CRITICAL**

**Sub-category 2.2: Feature Services (Medium Priority)**
10. `lib/services/notification_service.dart` (24 calls)
11. `lib/services/grace_system_service.dart` (6 calls)
12. `lib/services/entry_service.dart` (3 calls)
13. `lib/services/analytics_service.dart` (6 calls)
14. `lib/services/home_summary_service.dart` (7 calls)
15. `lib/services/ai_service.dart` (9 calls)
16. `lib/services/history_service.dart` (5 calls)
17. `lib/services/support_ticket_service.dart` (2 calls)
18. `lib/services/user_preference_sync_service.dart` (2 calls)
19. `lib/services/timezone_service.dart` (3 calls)
20. `lib/services/sync/sync_worker.dart` (1 call)
21. `lib/services/connectivity_service.dart` (1 call)
22. `lib/services/app_lifecycle_service.dart` (2 calls)
23. `lib/services/database/user_data_cleanup_service.dart` (1 call)
24. `lib/services/data_sync_flag_service.dart` (3 calls)

**Test:** Test each service individually, verify error logs.

---

### **Category 3: Providers (12 files, 37 calls)**
**Priority:** Medium (state management)

1. `lib/providers/entry_provider.dart` (11 calls)
2. `lib/providers/grace_system_provider.dart` (4 calls)
3. `lib/providers/data_providers.dart` (3 calls)
4. `lib/providers/recent_entries_provider.dart` (1 call)
5. `lib/providers/history_provider.dart` (4 calls)
6. `lib/providers/user_data_provider.dart` (1 call)
7. `lib/providers/analytics_provider.dart` (7 calls)
8. `lib/providers/theme_provider.dart` (1 call)
9. `lib/providers/paper_style_provider.dart` (1 call)
10. `lib/providers/font_size_provider.dart` (1 call)
11. `lib/providers/auth_provider.dart` (4 calls)
12. `lib/providers/privacy_lock_provider.dart` (2 calls)
13. `lib/providers/sync_status_provider.dart` (1 call)

**Test:** Test provider error handling, verify state recovery.

---

### **Category 4: Repositories (1 file, 12 calls)**
**Priority:** Medium

1. `lib/repositories/data_repository.dart` (12 calls)

**Test:** Test cache operations, verify errors don't break caching.

---

### **Category 5: Widgets (1 file, 5 calls)**
**Priority:** Low (UI only)

1. `lib/widgets/month_chips_carousel.dart` (5 calls)

**Test:** Test UI error handling, verify graceful degradation.

---

## 🔄 **Migration Pattern for Each File**

### **Step-by-Step for Each File:**

1. **Add import:**
   ```dart
   import '../models/error_models.dart';
   ```

2. **Find error logging call:**
   ```dart
   await ErrorLoggingService.logHighError(
     errorCode: 'ERRSYS184',
     errorMessage: 'Prefetch failed: ${e.toString()}',
     stackTrace: StackTrace.current.toString(),
     errorContext: {...},
   );
   ```

3. **Replace with model:**
   ```dart
   await ErrorLoggingService.logHighError(
     ErrorContext.create(
       errorCode: 'ERRSYS184',
       errorMessage: 'Prefetch failed: ${e.toString()}',
       severity: ErrorSeverity.high,
       stackTrace: StackTrace.current.toString(),
       errorContext: {...},
     ),
   );
   ```

4. **Or use fromException (if exception available):**
   ```dart
   await ErrorLoggingService.logHighError(
     ErrorContext.fromException(
       errorCode: 'ERRSYS184',
       severity: ErrorSeverity.high,
       exception: e,
       stackTrace: StackTrace.current,
       errorContext: {...},
     ),
   );
   ```

5. **Test:** Verify error is logged correctly in Supabase.

---

## ✅ **Testing Strategy**

### **Unit Tests:**
1. Test `ErrorContext.create()` factory
2. Test `ErrorContext.fromException()` factory
3. Test `ErrorContext.toJson()` matches DB schema
4. Test `ErrorContext.copyWith()` works correctly
5. Test `ErrorLoggingService.logError()` with model
6. Test backward compatibility (old methods still work)

### **Integration Tests:**
1. Test error logging doesn't throw exceptions
2. Test errors are logged to Supabase correctly
3. Test all fields are populated correctly
4. Test error logging failure doesn't break app

### **Manual Testing:**
1. Trigger errors in each category
2. Verify logs appear in Supabase `error_logs` table
3. Verify all fields are populated
4. Verify app continues working after errors

---

## 🛡️ **Safety Measures**

### **1. Error Logging Must Never Fail**
- All `logError()` calls wrapped in try-catch
- Fallback to console logging if Supabase fails
- Never throw exceptions from error logging

### **2. Backward Compatibility**
- Keep old parameter-based methods (deprecated)
- Support both old and new patterns during migration
- Remove deprecated methods only after full migration

### **3. Gradual Migration**
- Migrate one file at a time
- Test after each file
- Rollback plan: revert file if issues found

### **4. Validation**
- Verify model `toJson()` matches DB schema exactly
- Test with real Supabase connection
- Verify all error fields are logged correctly

---

## 📊 **Expected Results**

### **Code Reduction:**
- **Before:** ~1,200 lines (220 calls × ~6 lines each)
- **After:** ~440 lines (220 calls × ~2 lines each)
- **Savings:** ~760 lines removed

### **Maintainability:**
- Single source of truth (ErrorContext model)
- Easy to update error structure (change model once)
- Type safety (compile-time checks)

### **Performance:**
- Minimal impact (same operations, just organized better)
- Slightly better (less object creation per call)

---

## 📝 **Implementation Checklist**

### **Phase 1: Models** ✅
- [ ] Add `stackTrace` field to `ErrorContext`
- [ ] Add `ErrorContext.create()` factory
- [ ] Add `ErrorContext.fromException()` factory
- [ ] Add `ErrorContext.copyWith()` method
- [ ] Update `toJson()` to include `stack_trace`
- [ ] Test model serialization

### **Phase 2: Service** ✅
- [ ] Add `logError(ErrorContext)` method
- [ ] Keep old methods (deprecated) for compatibility
- [ ] Update convenience methods to accept model
- [ ] Ensure all logging wrapped in try-catch
- [ ] Test backward compatibility
- [ ] Test new model-based logging

### **Phase 3: Migration** ✅
- [ ] Screens (13 files)
- [ ] Core Services (9 files)
- [ ] Feature Services (15 files)
- [ ] Providers (12 files)
- [ ] Repositories (1 file)
- [ ] Widgets (1 file)

### **Phase 4: Cleanup** ✅
- [ ] Remove deprecated methods
- [ ] Update documentation
- [ ] Final testing
- [ ] Verify all 220 errors migrated

---

## 🚨 **Rollback Plan**

If issues found during migration:

1. **Immediate:** Revert specific file changes
2. **Partial:** Keep old methods, migrate gradually
3. **Full:** Revert all changes, use old pattern

**Safety:** Old methods remain functional, so rollback is safe.

---

## 📋 **File-by-File Migration List**

### **Screens (13 files)**
1. ✅ `lib/screens/analytics_screen.dart` - 3 calls
2. ✅ `lib/screens/home_screen.dart` - 2 calls
3. ✅ `lib/screens/login_screen.dart` - 2 calls
4. ✅ `lib/screens/profile_screen.dart` - 3 calls
5. ✅ `lib/screens/register_screen.dart` - 1 call
6. ✅ `lib/screens/security_questions_screen.dart` - 1 call
7. ✅ `lib/screens/splash_screen.dart` - 2 calls
8. ✅ `lib/screens/pin_lock_screen.dart` - 1 call
9. ✅ `lib/screens/pin_recovery_screen.dart` - 3 calls
10. ✅ `lib/screens/pin_setup_screen.dart` - 1 call
11. ✅ `lib/screens/change_pin_screen.dart` - 2 calls
12. ✅ `lib/screens/help_support_screen.dart` - 1 call
13. ✅ `lib/screens/my_tickets_screen.dart` - 1 call

### **Services (24 files)**
14. ✅ `lib/services/error_logging_service.dart` - Core service (Phase 2)
15. ✅ `lib/services/sync/supabase_sync_service.dart` - 22 calls
16. ✅ `lib/services/user_data_service.dart` - 15 calls
17. ✅ `lib/services/data_fetch_service.dart` - 12 calls
18. ✅ `lib/services/data_prefetch_service.dart` - 13 calls
19. ✅ `lib/services/database/local_entry_service.dart` - 9 calls
20. ✅ `lib/services/database/database_manager.dart` - 2 calls
21. ✅ `lib/services/auth_service.dart` - 6 calls
22. ✅ `lib/services/pin_auth_service.dart` - 5 calls
23. ✅ `lib/services/notification_service.dart` - 24 calls
24. ✅ `lib/services/grace_system_service.dart` - 6 calls
25. ✅ `lib/services/entry_service.dart` - 3 calls
26. ✅ `lib/services/analytics_service.dart` - 6 calls
27. ✅ `lib/services/home_summary_service.dart` - 7 calls
28. ✅ `lib/services/ai_service.dart` - 9 calls
29. ✅ `lib/services/history_service.dart` - 5 calls
30. ✅ `lib/services/support_ticket_service.dart` - 2 calls
31. ✅ `lib/services/user_preference_sync_service.dart` - 2 calls
32. ✅ `lib/services/timezone_service.dart` - 3 calls
33. ✅ `lib/services/sync/sync_worker.dart` - 1 call
34. ✅ `lib/services/connectivity_service.dart` - 1 call
35. ✅ `lib/services/app_lifecycle_service.dart` - 2 calls
36. ✅ `lib/services/database/user_data_cleanup_service.dart` - 1 call
37. ✅ `lib/services/data_sync_flag_service.dart` - 3 calls

### **Providers (12 files)**
38. ✅ `lib/providers/entry_provider.dart` - 11 calls
39. ✅ `lib/providers/grace_system_provider.dart` - 4 calls
40. ✅ `lib/providers/data_providers.dart` - 3 calls
41. ✅ `lib/providers/recent_entries_provider.dart` - 1 call
42. ✅ `lib/providers/history_provider.dart` - 4 calls
43. ✅ `lib/providers/user_data_provider.dart` - 1 call
44. ✅ `lib/providers/analytics_provider.dart` - 7 calls
45. ✅ `lib/providers/theme_provider.dart` - 1 call
46. ✅ `lib/providers/paper_style_provider.dart` - 1 call
47. ✅ `lib/providers/font_size_provider.dart` - 1 call
48. ✅ `lib/providers/auth_provider.dart` - 4 calls
49. ✅ `lib/providers/privacy_lock_provider.dart` - 2 calls
50. ✅ `lib/providers/sync_status_provider.dart` - 1 call

### **Repositories (1 file)**
51. ✅ `lib/repositories/data_repository.dart` - 12 calls

### **Widgets (1 file)**
52. ✅ `lib/widgets/month_chips_carousel.dart` - 5 calls

---

## 🎯 **Success Criteria**

1. ✅ All 220 error logging calls use `ErrorContext` model
2. ✅ No duplicate code (single source of truth)
3. ✅ Error logging never throws exceptions
4. ✅ All errors logged correctly to Supabase
5. ✅ Code reduced by ~760 lines
6. ✅ Type safety improved
7. ✅ Backward compatibility maintained during migration
8. ✅ All tests pass

---

## 📌 **Notes**

- **Safety First:** Error logging must never fail - all code wrapped in try-catch
- **Gradual Migration:** One file at a time, test after each
- **Backward Compatible:** Old methods work during migration
- **Test Thoroughly:** Verify errors logged correctly after each change
- **Rollback Ready:** Can revert any file if issues found

---

## 🚀 **Ready to Implement**

All planning complete. Ready to execute:
1. Phase 1: Update models
2. Phase 2: Refactor service
3. Phase 3: Migrate all files
4. Phase 4: Cleanup and verify

**Total Estimated Time:** 2-3 hours for full migration
**Risk Level:** Low (backward compatible, gradual migration)
