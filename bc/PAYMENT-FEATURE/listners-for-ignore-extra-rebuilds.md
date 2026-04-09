# Premium Provider: keepAlive to Reduce Extra Rebuilds

## Goal
Keep premium state in memory between screen navigations to avoid unnecessary `getCustomerInfo()` calls and loading flicker when switching Profile ↔ PremiumScreen or Profile ↔ other tabs.

## Why
- `FutureProvider.autoDispose` disposes when no listeners
- User leaves Profile → provider disposed → re-fetch when they return
- `ref.keepAlive()` prevents disposal until app is killed
- Fewer RevenueCat calls, smoother UX

## Implementation

| Step | File | Change |
|------|------|--------|
| 1 | `lib/providers/premium_provider.dart` | Add `ref.keepAlive()` at the start of the provider callback (after user null check) |
| 2 | `lib/providers/auth_provider.dart` | Add `PremiumService.logOut()` before `authRepository.signOut()`, then `_ref.invalidate(premiumProvider)` |
| 3 | `lib/providers/auth_provider.dart` | Add `PremiumService.logIn(response.user!.id)` in `signIn()` after `signInWithPassword` succeeds |

## Edge Case: User Logout / Account Switch

With `keepAlive`, the provider keeps its last result. If user A logs out and user B logs in, the provider would return user A's premium state to user B.

**Fix:** Call `PremiumService.logOut()` (clears RevenueCat user link) before Supabase sign out, then invalidate `premiumProvider`.

## Code Change

```dart
final premiumProvider =
    FutureProvider.autoDispose<PremiumState>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    return PremiumState(isPremium: false);
  }

  ref.keepAlive();  // <-- Add this

  try {
    // ... rest unchanged
```

## Code Change (Step 2)

In `auth_provider.dart` `signOut()`:

```dart
Future<void> signOut() async {
  try {
    await PremiumService.logOut();  // Clear RevenueCat user link first
    await _ref.read(authRepositoryProvider).signOut();
    _ref.invalidate(premiumProvider);
  } catch (e) {
    // ...
  }
}
```

Add imports: `premium_service.dart`, `premium_provider.dart`.

## Code Change (Step 3) – signIn

When user logs in via LoginScreen, we navigate to Home without running Splash. Splash is the only place that called `PremiumService.logIn(user.id)` on cold start. So we must call it in `signIn()`:

```dart
Future<void> signIn(String email, String password) async {
  try {
    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.user != null) {
      await PremiumService.logIn(response.user!.id);
    }
  } catch (e) {
    // ...
  }
}
```

## Flow Simulation – Premium / RevenueCat

| Scenario | logIn | logOut | Status |
|----------|-------|--------|--------|
| **Offline** (cold start) | Splash skips (online only) | — | OK – RevenueCat cache |
| **Online** (cold start) | Splash calls | — | OK |
| **Login** (via LoginScreen) | signIn calls | — | OK |
| **Logout** | — | signOut calls | OK |
| **Register** | — | — | OK – user verifies then logs in |

## Notes
- `ref.invalidate(premiumProvider)` still works — forces re-fetch
- Memory cost: negligible (PremiumState is small)
