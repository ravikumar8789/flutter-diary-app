# Premium Feature – UI Plan

## Structure

- **1 screen:** PremiumScreen (route from Profile)
- **1 widget:** PaywallContent (benefits + plan + pay)
- **1 content:** PremiumDetails (status, expiry – for Profile when premium)

---

## Behavior by Location

| Location | Premium | Non-Premium |
|----------|---------|-------------|
| **Weekly** | Show analysis (as now) | Show PaywallContent |
| **Monthly** | Show analysis (as now) | Show PaywallContent |
| **Profile / Premium** | Show PremiumDetails | Show PaywallContent |

---

## PaywallContent

- Benefits (weekly + monthly analysis)
- Plan selection (Monthly, Annual)
- Pay button
- Restore purchases

---

## PremiumDetails

- Status (active)
- Expiry date
- Manage subscription link

---

## Files

| File | Purpose |
|------|---------|
| `lib/screens/premium_screen.dart` | Route; shows PaywallContent or PremiumDetails |
| `lib/widgets/paywall_content.dart` | Benefits + plan + pay (reused on Weekly, Monthly, PremiumScreen) |
| `lib/services/premium_service.dart` | RevenueCat + premium logic |

---

## RLS – Must Implement (Option A)

**Update RLS on `weekly_insights` and `monthly_insights`** to add premium check. Current policy only checks `auth.uid() = user_id`. Add condition: user must exist in `user_premium` with `is_premium = true` and valid expiry. No row in `user_premium` = not premium = no access.
