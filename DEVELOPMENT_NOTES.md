# Diary App - Development Notes

## Overview
A minimalistic, AI-based digital journal/diary app built with Flutter, Riverpod, and Supabase.

## Current Status: UI Phase (Static Data)

### Completed Screens

1. **Login Screen** (`lib/screens/login_screen.dart`)
   - Email and password fields with validation
   - Navigation to Register screen
   - Forgot password link (placeholder)
   - Responsive design for mobile and tablet

2. **Register Screen** (`lib/screens/register_screen.dart`)
   - Full name, email, password, and confirm password fields
   - Form validation
   - Navigation back to Login screen
   - Responsive design

3. **Home Screen** (`lib/screens/home_screen.dart`)
   - Welcome message
   - Quick stats cards (Streak, Entries, Mood, Weekly progress)
   - Navigation buttons to all screens (for testing)
   - Responsive grid layout

4. **Diary Screen** (`lib/screens/diary_screen.dart`)
   - Two tabs: Affirmations and Diary
   - Date selector with calendar picker
   - **Affirmations Tab:**
     - 5 affirmation fields
     - 6 priority fields
   - **Diary Tab:**
     - Mood selector (5 moods)
     - Diary text area
     - Meals (breakfast, lunch, dinner)
     - Water intake slider (0-8 cups)
     - 6 gratitude fields
     - Self-care checklist (10 items)
     - 4 tomorrow notes fields
   - Save button (shows snackbar)

5. **Analytics Screen** (`lib/screens/analytics_screen.dart`)
   - Weekly summary cards
   - Mood trends line chart (using fl_chart)
   - Self-care progress bars
   - Common topics/tags display
   - Responsive layout

6. **History Screen** (`lib/screens/history_screen.dart`)
   - List/Calendar view toggle
   - Filter by tags
   - Entry cards with mood icons
   - Entry detail bottom sheet
   - Search functionality (placeholder)

7. **Profile Screen** (`lib/screens/profile_screen.dart`)
   - Avatar with camera icon
   - User stats (Entries, Streak, Days)
   - Personal information section
   - Preferences section
   - Account actions
   - Logout and Delete account dialogs

8. **Settings Screen** (`lib/screens/settings_screen.dart`)
   - Notifications settings (reminder time, days)
   - Appearance (theme, font size, paper style)
   - Privacy & Security (privacy lock, change password)
   - Journaling preferences (streak compassion, export format)
   - Data management (export, clear cache)
   - About section (version, terms, privacy policy)

### Theme
Custom minimalistic theme in `lib/theme/app_theme.dart`:
- **Primary Color:** Soft sage green (#6B8E6F)
- **Secondary Color:** Light sage (#A4C3A2)
- **Background:** Off-white (#FAF9F6)
- **Accent:** Warm beige (#E8DFD0)
- **Font:** Inter (Google Fonts) for UI, Crimson Text for headings

### Database Schema Alignment
All screens are designed according to the Supabase database schema:
- `entries` table with all child tables
- `user_profiles` and `user_settings`
- Analytics and insights tables
- Ready for backend integration

### Dependencies
```yaml
flutter_riverpod: ^2.6.1  # State management
supabase_flutter: ^2.9.1  # Backend
google_fonts: ^6.2.1      # Typography
intl: ^0.19.0             # Date formatting
fl_chart: ^0.70.1         # Charts
```

## Next Steps

### Phase 1: Complete UI Testing
- [ ] Test all screens on different devices
- [ ] Test responsiveness (rotate screen, different sizes)
- [ ] Confirm UI/UX meets requirements
- [ ] Get approval from user

### Phase 2: Add Drawer Navigation
- [ ] Create drawer widget with navigation items
- [ ] Replace home screen navigation buttons with drawer
- [ ] Add user info to drawer header
- [ ] Implement drawer navigation logic

### Phase 3: Backend Integration
- [ ] Setup Supabase configuration
- [ ] Implement authentication (login, register, logout)
- [ ] Create Riverpod providers for state management
- [ ] Implement CRUD operations for entries
- [ ] Connect all forms to Supabase
- [ ] Add proper error handling

### Phase 4: Advanced Features
- [ ] AI insights integration
- [ ] Weekly reports
- [ ] Notification system
- [ ] Data export functionality
- [ ] Search and filtering
- [ ] Image attachments

## How to Test

1. Run the app:
   ```bash
   flutter run
   ```

2. The app will start on the Login screen
3. Click "Sign In" or "Sign Up" to navigate to Home screen
4. Use the navigation buttons on Home screen to test all screens

## Responsive Design
- Mobile: 1-2 column layouts
- Tablet (>600px): 3-4 column layouts, wider forms (max 500-800px)
- All forms constrained for readability
- Touch targets sized appropriately

## Notes
- All data is currently static (hardcoded)
- No actual authentication yet
- No database connections yet
- Focus is on UI/UX testing
- Ready for backend integration once approved

