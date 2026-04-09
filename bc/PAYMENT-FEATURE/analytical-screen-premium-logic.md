# Analytics Screen: Premium Gate for Weekly/Monthly

## Goal
Show PaywallContent to non-premium users when online. Premium users see analytics as now.

## Flow

| State | Action |
|-------|--------|
| **Offline** | Keep current offline UI (no change) |
| **Online + premium** | Show analytics (fetch as now) |
| **Online + non-premium** | Show PaywallContent (no fetch) |

## Premium Source
`premiumProvider` → RevenueCat `getCustomerInfo()` (cache or API). Same as Profile, PremiumScreen.

## Implementation

**File:** `lib/screens/analytics_screen.dart`

**In `_buildAnalyticsBody`**, when `isOnline == true`:
1. Add `ref.watch(premiumProvider)`
2. Loading → show loading
3. `isPremium` → show analytics content (current behavior)
4. `!isPremium` → show `PaywallContent`
5. Error → show paywall (fail closed) or error UI

## Notes
- Non-premium: no analytics fetch (providers not watched)
- Offline: no premium check; keep offline UI
- Reuse `PaywallContent` from `lib/widgets/paywall_content.dart`
