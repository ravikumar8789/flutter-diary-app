# Error Code System Implementation Plan

## 🎯 **Project Overview**
Implement a comprehensive error code system for the Diary App to improve debugging, user support, and error tracking.

## 📋 **Error Code Structure**

### **Format:**
```
ERR[CATEGORY][SEQUENCE] - [FILE] - [METHOD]
```

### **Categories (5 Main Categories):**
1. **AUTH** - Authentication & Authorization errors (ERRAUTH001-ERRAUTH080)
2. **DATA** - Data sync, storage, and database errors (ERRDATA001-ERRDATA080)
3. **NET** - Network connectivity and API errors (ERRNET001-ERRNET080)
4. **UI** - User interface and interaction errors (ERRUI001-ERRUI080)
5. **SYS** - System, validation, and general errors (ERRSYS001-ERRSYS080)

### **Error Code Range:**
- **80 codes per category** (001-080)
- **Total: 400 error codes** across all categories
- **Future expansion:** Can add more categories or extend ranges

## 🔍 **Current Error Analysis**

### **Files with Error Handling (20 files):**
- `lib/providers/user_data_provider.dart` - 11 error locations
- `lib/providers/auth_provider.dart` - 6 error locations
- `lib/screens/login_screen.dart` - 6 error locations
- `lib/screens/profile_screen.dart` - 6 error locations
- `lib/services/user_data_service.dart` - 11 error locations
- `lib/screens/splash_screen.dart` - 3 error locations
- `lib/services/sync/supabase_sync_service.dart` - 32 error locations
- `lib/services/sync/sync_worker.dart` - 10 error locations
- `lib/services/entry_service.dart` - 2 error locations
- `lib/screens/new_diary_screen.dart` - 3 error locations
- `lib/providers/entry_provider.dart` - 33 error locations
- `lib/providers/sync_status_provider.dart` - 2 error locations
- `lib/models/entry_models.dart` - 1 error location
- `lib/widgets/dynamic_field_section.dart` - 2 error locations
- `lib/utils/snackbar_utils.dart` - 22 error locations
- `lib/screens/register_screen.dart` - 5 error locations
- `lib/services/auth_service.dart` - 11 error locations
- `lib/screens/settings_screen.dart` - 6 error locations
- `lib/screens/diary_screen.dart` - 1 error location
- `lib/theme/app_theme.dart` - 1 error location

### **Error Types Found:**
- **174 try-catch blocks** across the codebase
- **41 UI error displays** (dialogs, snackbars, alerts)
- **22 predefined error messages** in SnackbarUtils
- **Multiple error handling patterns**

## 🚀 **Implementation Phases**

### **Phase 1: Error Code Database Creation**
**Duration:** 1-2 days
**Priority:** High

#### **Tasks:**
1. **Scan All Error Locations**
   - Identify all try-catch blocks
   - Map all error messages
   - Catalog all UI error displays
   - Document error handling patterns

2. **Create Error Code Database**
   - Assign unique codes to each error
   - Categorize errors by type
   - Create `error_codes.md` file
   - Document error descriptions and solutions

3. **Error Code Assignment Strategy**
   - **AUTH001-080:** Authentication errors
   - **DATA001-080:** Data sync/storage errors
   - **NET001-080:** Network connectivity errors
   - **UI001-080:** User interface errors
   - **SYS001-080:** System/validation errors

#### **Deliverables:**
- `error/error_codes.md` - Complete error code database
- Error categorization document
- Error mapping spreadsheet

### **Phase 2: Error Code Integration**
**Duration:** 2-3 days
**Priority:** High

#### **Tasks:**
1. **Update SnackbarUtils**
   - Add error code parameter to all methods
   - Update error message display format
   - Add error code to snackbar content

2. **Update Dialog Boxes**
   - Add error codes to AlertDialog titles
   - Include error codes in dialog content
   - Update confirmation dialogs

3. **Update Error Handling**
   - Add error codes to all catch blocks
   - Update error messages with codes
   - Standardize error display format

#### **Code Changes:**
```dart
// Before
SnackbarUtils.showError(context, 'Invalid credentials');

// After
SnackbarUtils.showError(context, 'Invalid credentials', 'ERRAUTH001');
```

```dart
// Before
AlertDialog(
  title: Text('Error'),
  content: Text('Something went wrong'),
)

// After
AlertDialog(
  title: Text('Error ERRAUTH001'),
  content: Text('Invalid credentials'),
)
```

#### **Deliverables:**
- Updated SnackbarUtils with error codes
- Updated all dialog boxes
- Standardized error handling

### **Phase 3: Error Code Display System**
**Duration:** 1-2 days
**Priority:** Medium

#### **Tasks:**
1. **Error Code Display Format**
   - Design error code display in UI
   - Create error code styling
   - Add error code to error messages

2. **Error Code Visibility**
   - Show error codes to users
   - Add error code to crash reports
   - Include error codes in logs

3. **Error Code Documentation**
   - Create user-facing error code guide
   - Add error code help system
   - Create error reporting mechanism

#### **Deliverables:**
- Error code display system
- User error code guide
- Error reporting mechanism

### **Phase 4: Error Reporting & Analytics**
**Duration:** 2-3 days
**Priority:** Medium

#### **Tasks:**
1. **Error Logging System**
   - Implement error code logging
   - Add error analytics
   - Create error tracking

2. **Error Reporting**
   - Add error report functionality
   - Create error feedback system
   - Implement error code search

3. **Error Analytics**
   - Track error frequency
   - Monitor error patterns
   - Generate error reports

#### **Deliverables:**
- Error logging system
- Error reporting functionality
- Error analytics dashboard

## 📊 **Error Code Database Structure**

### **AUTH Errors (ERRAUTH001-ERRAUTH080)**
```
ERRAUTH001 - login_screen.dart - _login() - Invalid credentials
ERRAUTH002 - login_screen.dart - _login() - Email not verified
ERRAUTH003 - register_screen.dart - _register() - User already exists
ERRAUTH004 - register_screen.dart - _register() - Weak password
ERRAUTH005 - auth_provider.dart - signIn() - Network error
ERRAUTH006 - auth_provider.dart - signOut() - Logout failed
ERRAUTH007 - profile_screen.dart - _performLogout() - Logout error
ERRAUTH008 - login_screen.dart - _login() - Invalid email format
ERRAUTH009 - register_screen.dart - _register() - Email validation failed
ERRAUTH010 - auth_provider.dart - signUp() - Registration failed
```

### **DATA Errors (ERRDATA001-ERRDATA080)**
```
ERRDATA001 - sync_worker.dart - processSyncQueue() - Sync failed
ERRDATA002 - supabase_sync_service.dart - syncEntry() - Cloud sync error
ERRDATA003 - local_entry_service.dart - upsertEntry() - Local save failed
ERRDATA004 - entry_provider.dart - updateDiaryText() - Save failed
ERRDATA005 - database_manager.dart - _initDatabase() - DB initialization failed
ERRDATA006 - sync_worker.dart - _isOnline() - Connection check failed
ERRDATA007 - supabase_sync_service.dart - fetchEntryFromCloud() - Fetch failed
ERRDATA008 - local_entry_service.dart - getEntryByDate() - Query failed
ERRDATA009 - entry_service.dart - loadEntryForDate() - Load failed
ERRDATA010 - sync_worker.dart - retrySync() - Retry failed
```

### **NET Errors (ERRNET001-ERRNET080)**
```
ERRNET001 - connectivity_service.dart - startMonitoring() - No connection
ERRNET002 - sync_worker.dart - _isOnline() - Connection timeout
ERRNET003 - supabase_sync_service.dart - syncEntry() - API timeout
ERRNET004 - user_data_service.dart - fetchUserData() - Network error
ERRNET005 - connectivity_service.dart - isOnline() - Connectivity check failed
ERRNET006 - sync_worker.dart - processSyncQueue() - Network unavailable
ERRNET007 - supabase_sync_service.dart - fetchEntryFromCloud() - API error
ERRNET008 - user_data_service.dart - _fetchUserProfile() - Server error
ERRNET009 - connectivity_service.dart - onConnectivityChanged() - Connection lost
ERRNET010 - sync_worker.dart - _isOnline() - DNS resolution failed
```

### **UI Errors (ERRUI001-ERRUI080)**
```
ERRUI001 - new_diary_screen.dart - _clearContent() - Nothing to clear
ERRUI002 - profile_screen.dart - _performLogout() - Logout confirmation
ERRUI003 - morning_rituals_screen.dart - _onMoodChanged() - Mood save failed
ERRUI004 - wellness_tracker_screen.dart - _onMealsChanged() - Meals save failed
ERRUI005 - gratitude_reflection_screen.dart - _onGratitudeChanged() - Gratitude save failed
ERRUI006 - dynamic_field_section.dart - _addField() - Field addition failed
ERRUI007 - dynamic_field_section.dart - _removeField() - Field removal failed
ERRUI008 - new_diary_screen.dart - _loadEntryData() - Data load failed
ERRUI009 - morning_rituals_screen.dart - _loadEntryData() - Affirmations load failed
ERRUI010 - wellness_tracker_screen.dart - _loadEntryData() - Wellness data load failed
```

### **SYS Errors (ERRSYS001-ERRSYS080)**
```
ERRSYS001 - database_manager.dart - _initDatabase() - DB creation failed
ERRSYS002 - entry_provider.dart - updateDiaryText() - Validation failed
ERRSYS003 - user_data_provider.dart - loadUserData() - User data fetch failed
ERRSYS004 - sync_status_provider.dart - setError() - Status update failed
ERRSYS005 - database_manager.dart - clearOldEntries() - Cleanup failed
ERRSYS006 - entry_provider.dart - updateAffirmations() - Affirmations validation failed
ERRSYS007 - user_data_provider.dart - fetchWellnessData() - Wellness data fetch failed
ERRSYS008 - sync_status_provider.dart - setSyncing() - Status sync failed
ERRSYS009 - database_manager.dart - closeDatabase() - DB close failed
ERRSYS010 - entry_provider.dart - updatePriorities() - Priorities validation failed
```

## 🛠️ **Technical Implementation**

### **1. Error Code Service**
```dart
class ErrorCodeService {
  static const Map<String, String> errorCodes = {
    'ERRAUTH001': 'Invalid credentials',
    'ERRAUTH002': 'Email not verified',
    'ERRDATA001': 'Sync failed',
    // ... more codes
  };
  
  static String getErrorMessage(String code) {
    return errorCodes[code] ?? 'Unknown error';
  }
  
  static void logError(String code, String details) {
    // Log error with code and details
  }
}
```

### **2. Enhanced SnackbarUtils**
```dart
class SnackbarUtils {
  static void showError(BuildContext context, String message, String errorCode) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            Text('Error Code: $errorCode', style: TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 5),
      ),
    );
  }
}
```

### **3. Enhanced AlertDialog**
```dart
Widget buildErrorDialog(String title, String message, String errorCode) {
  return AlertDialog(
    title: Text('$title ($errorCode)'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        SizedBox(height: 8),
        Text('Error Code: $errorCode', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('OK'),
      ),
    ],
  );
}
```

## 📈 **Success Metrics**

### **Phase 1 Success Criteria:**
- ✅ All error locations identified and cataloged
- ✅ Error code database created with 400+ codes
- ✅ Error categorization completed

### **Phase 2 Success Criteria:**
- ✅ All error messages display error codes
- ✅ SnackbarUtils updated with error codes
- ✅ All dialogs show error codes

### **Phase 3 Success Criteria:**
- ✅ Error codes visible to users
- ✅ Error reporting system functional
- ✅ User error code guide created

### **Phase 4 Success Criteria:**
- ✅ Error logging system operational
- ✅ Error analytics dashboard created
- ✅ Error reporting mechanism working

## 🎯 **Benefits**

### **For Users:**
- Clear error identification with codes
- Easy error reporting to support
- Better understanding of issues
- Improved user experience

### **For Developers:**
- Instant error location identification
- Faster debugging and resolution
- Better error tracking and analytics
- Improved code maintainability

### **For Support:**
- Direct error identification from user reports
- Faster issue resolution
- Better error pattern analysis
- Improved customer service

## 📅 **Timeline**

- **Week 1:** Phase 1 - Error Code Database Creation
- **Week 2:** Phase 2 - Error Code Integration
- **Week 3:** Phase 3 - Error Code Display System
- **Week 4:** Phase 4 - Error Reporting & Analytics

## 🔧 **Tools & Resources**

### **Required Tools:**
- Code analysis tools for error scanning
- Error tracking system
- Analytics dashboard
- User feedback system

### **Documentation:**
- Error code database
- User error code guide
- Developer error handling guide
- Support error resolution guide

---

**Next Steps:**
1. Review and approve this implementation plan
2. Begin Phase 1 - Error Code Database Creation
3. Start scanning and cataloging all error locations
4. Create the initial error code database
