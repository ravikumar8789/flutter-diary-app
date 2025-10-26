# 4-Digit PIN Privacy Lock Implementation Plan

## 🎯 Overview
Implement a simple and secure 4-digit PIN lock system for the diary app that protects user data with local authentication.

## 🔐 PIN Lock Features

### **Core Functionality**
- **4-Digit PIN**: Numeric PIN with 4 digits (0000-9999)
- **Local Storage**: PIN hash stored locally using encrypted storage
- **Auto-Lock**: Configurable timeout when app is backgrounded
- **Lockout Protection**: Temporary lockout after failed attempts
- **Recovery**: Security questions for PIN reset

### **User Experience**
- **Setup**: Simple PIN creation with confirmation
- **Authentication**: Clean PIN entry screen with number pad
- **Settings**: Toggle privacy lock on/off, change PIN, set timeout
- **Recovery**: "Forgot PIN" with security questions

## 📱 User Flow

### **Initial Setup**
1. User enables "Privacy Lock" in Settings
2. App prompts to create 4-digit PIN
3. User enters PIN twice for confirmation
4. User sets 2 security questions for recovery
5. Privacy lock is now active

### **App Launch Flow**
```
App Start → Check Privacy Lock Status → 
If Enabled: Show PIN Lock Screen → 
Enter 4-digit PIN → 
Success: Navigate to Home → 
Failure: Show Error + Retry (max 5 attempts)
```

### **Auto-Lock Flow**
```
App Backgrounded → Start Timer → 
Timeout Reached → Lock App → 
Next Foreground: Show PIN Lock Screen
```

## 🏗️ Technical Architecture

### **Required Dependencies**
```yaml
dependencies:
  flutter_secure_storage: ^9.0.0  # Encrypted PIN storage
  crypto: ^3.0.3                  # PIN hashing (SHA-256)
  shared_preferences: ^2.2.2      # Settings storage
  flutter_riverpod: ^2.4.9        # State management
```

### **Storage Strategy**
- **PIN Storage**: Hashed PIN stored in flutter_secure_storage
- **Settings**: Privacy lock preferences in SharedPreferences
- **Security Questions**: Encrypted storage for recovery
- **No Cloud**: All data stored locally only

### **Data Structure**
```dart
// Privacy Lock Settings (SharedPreferences)
{
  "privacy_lock_enabled": bool,
  "auto_lock_timeout": int, // minutes (1, 5, 15, 30, never)
  "last_unlock_time": DateTime,
  "failed_attempts": int,
  "lockout_until": DateTime?
}

// PIN Data (flutter_secure_storage)
{
  "pin_hash": String, // SHA-256 hash of PIN
  "security_question_1": String, // encrypted
  "security_answer_1": String, // hashed
  "security_question_2": String, // encrypted
  "security_answer_2": String, // hashed
}
```

## 🔧 Implementation Components

### **1. Privacy Lock Provider**
```dart
// lib/providers/privacy_lock_provider.dart
class PrivacyLockNotifier extends Notifier<PrivacyLockState> {
  // Enable/disable privacy lock
  // Set PIN and security questions
  // Handle PIN validation
  // Manage auto-lock timer
  // Handle lockout logic
}
```

### **2. PIN Authentication Service**
```dart
// lib/services/pin_auth_service.dart
class PinAuthService {
  // Create PIN hash
  // Validate PIN
  // Set security questions
  // Verify security answers
  // Handle lockout logic
}
```

### **3. PIN Lock Screen**
```dart
// lib/screens/pin_lock_screen.dart
class PinLockScreen extends ConsumerStatefulWidget {
  // PIN entry interface
  // Number pad (0-9, backspace, enter)
  // Error handling
  // Recovery options
}
```

### **4. PIN Setup Screen**
```dart
// lib/screens/pin_setup_screen.dart
class PinSetupScreen extends ConsumerStatefulWidget {
  // PIN creation
  // PIN confirmation
  // Security questions setup
}
```

## 🚀 Navigation System Changes

### **App Startup Flow**
```dart
// lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  await _initializeServices();
  
  // Check privacy lock status
  final privacyLockState = ref.read(privacyLockProvider);
  
  if (privacyLockState.enabled && !privacyLockState.isUnlocked) {
    // Navigate to PIN Lock Screen
    runApp(MaterialApp(home: PinLockScreen()));
  } else {
    // Navigate to Splash Screen (normal flow)
    runApp(MaterialApp(home: SplashScreen()));
  }
}
```

### **Route Protection**
```dart
// lib/navigation/route_guard.dart
class RouteGuard {
  static bool canAccessRoute(String route) {
    final privacyLock = ref.read(privacyLockProvider);
    
    if (privacyLock.enabled && !privacyLock.isUnlocked) {
      return false; // Redirect to PIN lock screen
    }
    return true;
  }
}
```

## 🔒 Security Features

### **1. PIN Security**
- **Hashing**: SHA-256 hash of PIN stored (never plain text)
- **Salt**: Random salt for each PIN hash
- **Validation**: Secure comparison of hashed values

### **2. Lockout Protection**
- **Failed Attempts**: Max 5 attempts before lockout
- **Lockout Duration**: 5 minutes, then 15 minutes, then 30 minutes
- **Reset**: Successful authentication or app reinstall

### **3. Auto-Lock Timer**
- **Options**: 1min, 5min, 15min, 30min, never
- **Trigger**: App backgrounded or screen timeout
- **Reset**: Any user interaction

### **4. Recovery System**
- **Security Questions**: 2 questions for PIN recovery
- **Encryption**: Questions and answers encrypted
- **Validation**: Must answer both questions correctly

## 📋 Settings Screen Integration

### **Privacy & Security Section**
```dart
// Enhanced settings with PIN lock options
SwitchListTile(
  title: Text('Privacy Lock'),
  subtitle: Text('Secure your diary with 4-digit PIN'),
  value: privacyLockEnabled,
  onChanged: (value) => _togglePrivacyLock(value),
),

// Change PIN
ListTile(
  title: Text('Change PIN'),
  subtitle: Text('Update your 4-digit PIN'),
  leading: Icon(Icons.lock_outline),
  onTap: () => _changePIN(),
),

// Auto-lock timeout
ListTile(
  title: Text('Auto-Lock Timeout'),
  subtitle: Text('${timeout} minutes'),
  onTap: () => _showTimeoutDialog(),
),

// Security Questions
ListTile(
  title: Text('Security Questions'),
  subtitle: Text('For PIN recovery'),
  onTap: () => _manageSecurityQuestions(),
),
```

## 🎨 UI/UX Design

### **PIN Lock Screen**
- **Background**: Blurred app screenshot or solid color
- **Logo**: App logo centered at top
- **PIN Display**: 4 dots showing entered digits
- **Number Pad**: 3x4 grid (1-9, 0, backspace, enter)
- **Error Message**: Clear error display for wrong PIN
- **Recovery**: "Forgot PIN?" link at bottom

### **PIN Setup Screen**
- **Step 1**: "Create your 4-digit PIN"
- **Step 2**: "Confirm your PIN"
- **Step 3**: "Set security questions"
- **Progress**: Step indicator at top
- **Validation**: Real-time PIN validation

### **Number Pad Design**
```
[ 1 ] [ 2 ] [ 3 ]
[ 4 ] [ 5 ] [ 6 ]
[ 7 ] [ 8 ] [ 9 ]
[ 0 ] [ ← ] [ ✓ ]
```

## 🔄 State Management

### **Privacy Lock States**
```dart
enum PrivacyLockState {
  disabled,     // Privacy lock is off
  locked,      // App is locked, needs PIN
  unlocked,    // App is unlocked and accessible
  lockout,     // Too many failed attempts, temporary lockout
  setup        // Initial PIN setup in progress
}
```

### **PIN Entry States**
```dart
enum PinEntryState {
  idle,        // No PIN entry in progress
  entering,    // PIN being entered
  validating,  // PIN validation in progress
  success,     // PIN correct
  failure,     // PIN incorrect
  lockout      // Account locked due to failed attempts
}
```

## 🧪 Testing Strategy

### **Unit Tests**
- PIN hashing and validation
- Security question verification
- Auto-lock timer logic
- Lockout mechanism

### **Integration Tests**
- End-to-end PIN setup flow
- PIN authentication flow
- Auto-lock functionality
- Recovery process

### **Security Tests**
- PIN storage encryption
- Lockout behavior
- Data persistence across app restarts
- Recovery security

## 📊 Implementation Phases

### **Phase 1: Core PIN System**
- PIN setup and validation
- Basic lock screen
- Settings integration
- Local storage

### **Phase 2: Security Features**
- Lockout protection
- Auto-lock timer
- Security questions
- Recovery system

### **Phase 3: UI/UX Polish**
- Enhanced PIN entry screen
- Error handling
- Loading states
- Accessibility

### **Phase 4: Testing & Security**
- Comprehensive testing
- Security audit
- Performance optimization
- Bug fixes

## 🔐 Security Considerations

### **Data Protection**
- PIN never stored in plain text
- All sensitive data encrypted locally
- No cloud synchronization of privacy data
- Secure key storage using platform APIs

### **User Privacy**
- Clear privacy policy for PIN feature
- User consent for data collection
- Option to disable without data loss
- Transparent data handling

## 📱 Platform-Specific Implementation

### **Android**
- flutter_secure_storage uses Android Keystore
- Secure storage for PIN hash
- Biometric capability detection (future)

### **iOS**
- flutter_secure_storage uses iOS Keychain
- Secure storage for PIN hash
- Touch ID integration (future)

## 🎯 Success Metrics

### **User Adoption**
- % of users who enable PIN lock
- PIN lock usage patterns
- Feature retention rate

### **Security Effectiveness**
- Failed PIN attempts
- Lockout frequency
- Recovery usage

### **User Experience**
- PIN entry success rate
- Time to authenticate
- User satisfaction scores

## 🚀 Implementation Steps

### **Step 1: Dependencies**
```bash
flutter pub add flutter_secure_storage crypto shared_preferences
```

### **Step 2: Core Services**
1. Create `PinAuthService` for PIN operations
2. Create `PrivacyLockProvider` for state management
3. Implement PIN hashing and validation

### **Step 3: UI Components**
1. Create `PinLockScreen` with number pad
2. Create `PinSetupScreen` for initial setup
3. Update settings screen integration

### **Step 4: Navigation**
1. Update app startup flow
2. Implement route protection
3. Add auto-lock functionality

### **Step 5: Security Features**
1. Implement lockout protection
2. Add security questions
3. Create recovery system

### **Step 6: Testing & Polish**
1. Comprehensive testing
2. Security audit
3. UI/UX improvements
4. Performance optimization

## 📋 File Structure
```
lib/
├── providers/
│   └── privacy_lock_provider.dart
├── services/
│   └── pin_auth_service.dart
├── screens/
│   ├── pin_lock_screen.dart
│   └── pin_setup_screen.dart
├── widgets/
│   └── pin_number_pad.dart
└── utils/
    └── pin_validation.dart
```

## 🎯 Key Benefits

### **Simplicity**
- Easy to use 4-digit PIN
- Familiar number pad interface
- Quick setup process

### **Security**
- Local-only storage
- Encrypted PIN hashing
- Lockout protection
- Recovery options

### **User Experience**
- Fast authentication
- Clear error messages
- Intuitive interface
- Reliable functionality

---

## 🚀 Ready to Implement

This focused plan provides everything needed to implement a secure, user-friendly 4-digit PIN lock system. The implementation is straightforward, secure, and provides excellent user experience while protecting user data effectively.

**Next Step**: Start with Phase 1 - Core PIN System implementation!