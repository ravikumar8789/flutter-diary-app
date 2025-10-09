# Plan 2 — UI Build (Static-first, Future-ready)

## Guardrails
- No backend/API calls for now; UI uses local dummy data.
- Architecture must allow easy swap to Supabase later by changing providers/repos only.
- State management with Riverpod; immutable models.
- Keep screens minimal and diary-themed as defined in Plan 1.

## Folder Structure (lib/)
- lib/
  - main.dart
  - app/
    - theme/
    - routing/
    - widgets/
  - features/
    - diary/
      - presentation/
      - application/
      - domain/
    - analytics/
    - profile/
    - auth/
  - core/
    - utils/
    - state/
  - data_repo/  (dummy data only for UI)
    - users.dart
    - entries.dart
    - affirmations.dart
    - priorities.dart
    - meals.dart
    - gratitude.dart
    - self_care.dart
    - shower_bath.dart
    - tomorrow_notes.dart
    - prompts.dart
    - streaks.dart

Notes:
- Each file exports typed lists/maps of mock records matching `tables.md` field names.
- Later, this folder is replaced by Supabase repositories while keeping the same domain models.

## Riverpod Architecture
- Providers
  - `authProvider` (simulated login state using dummy user credentials)
  - `entriesProvider` (AsyncValue<List<Entry>> from `data_repo/entries.dart`)
  - `entryDetailProvider(entryId)`
  - `insightsProvider(entryId)` (mock)
  - `weeklyInsightsProvider(week)` (mock)
  - `streaksProvider(userId)`
  - `promptsForDateProvider(date)`
  - `settingsProvider(userId)`
- State patterns
  - Use `StateNotifier`/`Notifier` for editable forms (affirmations, diary text, self-care checks).
  - All actions update local mock stores; persistence is in-memory or Hive (optional) for demo.
- Backend swap later
  - Replace `data_repo` with implementations using Supabase; keep provider interfaces unchanged.

## Screens & Widgets (Phase UI)
- App shell
  - `NavigationRail` on wide screens, `Drawer` on narrow.
  - Routes: Home, Diary, Analytics, Profile, Settings.
- Diary screen
  - `DefaultTabController` with tabs: Affirmations | Diary.
  - Affirmations tab: fixed line inputs, water cups, gratitude, self-care checklist, notes for tomorrow.
  - Diary tab: notepad textarea, mood slider (1–5), fixed tag chips, save indicator.
  - Autosave to in-memory store with debounce.
- Analytics screen
  - Static charts using mock data: 7-day streak, 14-day mood line, hydration trend.
- Profile
  - Show mock user info; settings toggles; no real network.

## Dummy Data Strategy (data_repo)
- Seed single user for now:
  - email: ravikumar9006997@gmail.com
  - password: raviravi1 (used only for local mock auth)
- Provide 14 days of sample `entries`, aligned with Plan 1 fields.
- Include one `entry_insights` per entry with fake sentiment/summary.
- Include `weekly_insights` rollups.
- Include `streaks` and `habits_daily` snapshots.
- All data as plain Dart lists/maps; keep shapes aligned with `tables.md`.

### Example Shapes (pseudocode)
```dart
class Entry {
  final String id;
  final String userId;
  final DateTime entryDate;
  final String diaryText;
  final int moodScore; // 1-5
  final List<String> tags; // fixed set
}

class EntryAffirmations { String entryId; List<String> lines; }
class EntryMeals { String entryId; String breakfast; String lunch; String dinner; int waterCups; }
class EntrySelfCare { String entryId; bool sleep; bool early; bool freshAir; bool learn; bool diet; bool podcast; bool meMoment; bool hydrated; bool readBook; bool exercise; }
```

## Dependency List (pubspec.yaml)
- riverpod: state management (prefer `flutter_riverpod`)
- hooks_riverpod: optional for hooks
- go_router: declarative navigation
- freezed + json_serializable + build_runner: models and mock data parsing
- intl: dates/formatting
- flutter_svg: icons (if needed)
- google_fonts: typography
- charts_flutter or fl_chart: simple charts
- device_info_plus + package_info_plus (optional)
- shared_preferences or hive (optional for mock persistence)

Exact additions:
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  go_router: ^14.2.0
  google_fonts: ^6.2.1
  fl_chart: ^0.66.2
  intl: ^0.19.0
  flutter_svg: ^2.0.10+1

dev_dependencies:
  build_runner: ^2.4.11
  freezed: ^2.5.7
  freezed_annotation: ^2.4.1
  json_serializable: ^6.9.3
  json_annotation: ^4.9.0
```

## Auth (Mock Only)
- Simple form capturing email/password; validate against `data_repo/users.dart`.
- On success, set `authProvider` to logged-in state with `userId`.
- Do not store secrets; this is only for offline demo.

## Backend Swap Plan
- Introduce repository interfaces in `domain/` (e.g., `EntriesRepository`).
- Provide two implementations:
  - `DummyEntriesRepository` (current), backed by `data_repo`.
  - `SupabaseEntriesRepository` (later), backed by REST/RPC.
- Providers depend on the interface; swapping the provider override switches the backend.

## Milestones
- M1: App shell + sidebar nav + routes
- M2: Diary screen with tabs and static forms
- M3: Autosave + local mock store + Riverpod wiring
- M4: Analytics with mock charts
- M5: Profile/settings mock

## Risks & Mitigations
- Scope creep → stick to fixed fields as defined.
- Visual drift → reuse design tokens and shared components.
- Migration pain → strict model parity with `tables.md` fields.

## Deliverables
- `lib/data_repo/*` with mock datasets
- Riverpod providers and models
- Screens and widgets to render the UI fully with static data
- README section explaining how to switch to Supabase later
