# Handle Offline — Analytics Screen Plan

**Goal:** On Analytics screen load, check connectivity. If offline, show a clear offline message and "Try again" button. Do not fetch analytics when offline (prevents SocketException). Works for both Week and Month views.

---

## 1. Problem

- Analytics screen fetches from Supabase (weekly/monthly insights, AI analysis).
- When offline, providers throw SocketException → many errors, poor UX.
- User sees loading/error states instead of a clear "you're offline" message.

---

## 2. Approach

**Screen-level connectivity guard:** Check connectivity before rendering analytics content. If offline, show offline UI and do not watch analytics providers (so no fetch, no SocketException).

---

## 3. Implementation

### 3.1 Add connectivity provider for Analytics screen

**File:** `lib/providers/analytics_provider.dart`

Add:

```dart
/// Connectivity check for Analytics screen. Returns true if online.
/// When false, screen shows offline UI and does not fetch.
final analyticsConnectivityProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  return await ConnectivityService().isOnline();
});
```

Import `ConnectivityService`.

---

### 3.2 Wrap Analytics screen content with connectivity check

**File:** `lib/screens/analytics_screen.dart`

**Current structure:**
```
body: Column([
  _buildPeriodHeader(...),
  if (weekly) _buildWeekNavigation(...),
  if (monthly) _buildMonthNavigation(...),
  _buildWeeklyContentWithSwipe / _buildMonthlyContent,
])
```

**New structure:**
```
body: Column([
  // Connectivity gate: if offline, show offline UI and return early
  _buildAnalyticsBody(context, period, info),
])
```

Add method `_buildAnalyticsBody`:

1. Watch `analyticsConnectivityProvider`.
2. **Loading:** Show subtle loading (or same header + loading for content area).
3. **Data: false (offline):** Return `_buildOfflineAnalyticsUI(context)`.
4. **Data: true (online):** Return existing content (period header, week/month nav, weekly/monthly content).
5. **Error:** Treat as offline, show `_buildOfflineAnalyticsUI(context)`.

---

### 3.3 Offline UI widget

**File:** `lib/screens/analytics_screen.dart`

Add `_buildOfflineAnalyticsUI(BuildContext context)`:

- Centered layout (or full content area).
- Card/Container with theme colors (surface, primary).
- Icon: `Icons.cloud_off` or `Icons.wifi_off` (size ~48–56).
- Title: "You're offline"
- Subtitle: "Analytics require an internet connection. Please check your connection and try again."
- "Try again" button: `ElevatedButton` or `FilledButton` with `onPressed` → `ref.invalidate(analyticsConnectivityProvider)`.
- Use `Theme.of(context).colorScheme`, `textTheme` for consistency.
- Optional: subtle gradient or soft background matching app theme (warm beige/cream).

**Theme matching:**
- `Theme.of(context).colorScheme.primary` for icon/button
- `Theme.of(context).colorScheme.surface` for card
- `Theme.of(context).colorScheme.onSurface` for text
- `Theme.of(context).textTheme.titleMedium` for title
- `Theme.of(context).textTheme.bodyMedium` for subtitle

---

### 3.4 Ensure providers are not watched when offline

When `analyticsConnectivityProvider` returns `false`, we render only `_buildOfflineAnalyticsUI`. The widgets that watch `weeklyAnalyticsProvider`, `monthlyAnalyticsProvider`, `weeklyInsightsListProvider`, `monthlyInsightsListProvider` are not built. Therefore those providers are not watched and do not run → no fetch, no SocketException.

---

## 4. UI Sketch (Offline State)

```
┌─────────────────────────────────────┐
│  [Analytics]     [Week | Month]     │  ← AppBar stays
├─────────────────────────────────────┤
│                                     │
│            [cloud_off icon]         │
│                                     │
│         You're offline              │
│                                     │
│   Analytics require an internet    │
│   connection. Please check your    │
│   connection and try again.        │
│                                     │
│        [ Try again ]                │
│                                     │
├─────────────────────────────────────┤
│  [Home] [Diary] [Analytics] [More]  │
└─────────────────────────────────────┘
```

---

## 5. Try Again behavior

- `ref.invalidate(analyticsConnectivityProvider)` → provider re-runs.
- If still offline → shows offline UI again.
- If online → shows analytics content; providers run and fetch.

---

## 6. Files to Modify

| File | Changes |
|------|---------|
| `lib/providers/analytics_provider.dart` | Add `analyticsConnectivityProvider` |
| `lib/screens/analytics_screen.dart` | Add connectivity gate; add `_buildOfflineAnalyticsUI`; wrap body content |

---

## 7. Execution Order

1. Add `analyticsConnectivityProvider` in analytics_provider.dart.
2. In analytics_screen.dart: add `_buildOfflineAnalyticsUI`.
3. Wrap the main body content in a connectivity check that shows offline UI when `analyticsConnectivityProvider` is false.

---

## 8. Verification

- [ ] Open Analytics screen offline → see offline UI, no SocketException.
- [ ] Tap "Try again" while offline → stays on offline UI.
- [ ] Go online, tap "Try again" → analytics load.
- [ ] Open Analytics screen online → normal behavior (week/month).
- [ ] UI matches app theme (colors, typography).
