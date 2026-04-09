# Premium: Check expiry + isPremium (Offline-Accurate, Edge-Case Safe)

## Goal
Show premium status correctly when offline, including after subscription expiry. Use cached `expirationDate` to treat expired users as non-premium. Handle all edge cases so no loopholes remain.

---

## Logic (Decision Tree)

```
1. No user → not premium
2. getCustomerInfo() null/throws → not premium
3. ent = entitlements.active['premium']
   - ent == null → not premium
4. Parse expirationDate:
   - Parse fails → FALLBACK: trust active (isPremium = true) — avoid wrong revocation
5. exp == null → lifetime → premium
6. exp > now → premium
7. exp <= now (expired):
   - billingIssueDetectedAt != null → grace period possible → trust active (premium)
   - else → expired → not premium
```

---

## Edge Cases Handled

| Edge case | Handling |
|-----------|----------|
| **Lifetime (null expiry)** | `exp == null` → premium |
| **Parse failure** | `exp == null` → premium (never revoke on bad data) |
| **Grace period** | Expired + `billingIssueDetectedAt != null` → premium (trust active) |
| **Empty/whitespace expiry** | Treat as null → lifetime |
| **Device clock back** | Accept; server (user_premium RLS) is authority when online |
| **Timezone** | RevenueCat uses ISO8601; parse handles; `DateTime.now()` sufficient |

---

## Implementation

### File: `lib/providers/premium_provider.dart`

Replace lines 45–51 with:

```dart
final ent = info.entitlements.active['premium'];
if (ent == null) {
  return PremiumState(isPremium: false, customerInfo: info);
}

final expStr = ent.expirationDate?.trim();
DateTime? exp;
if (expStr != null && expStr.isNotEmpty) {
  exp = DateTime.tryParse(expStr);
}

final now = DateTime.now();
final isPremium = exp == null
    ? true
    : exp.isAfter(now)
        ? true
        : ent.billingIssueDetectedAt != null;

return PremiumState(isPremium: isPremium, customerInfo: info);
```

**Logic:** `exp == null` (lifetime or parse fail) → premium. `exp > now` → premium. `exp <= now` and no billing issue → not premium. `exp <= now` and billing issue → grace period → premium.

---

### No other changes

Profile, PremiumScreen, PaywallContent all use `premiumProvider`.

---

## Notes

- Single source of truth: `premiumProvider`
- `premiumExpiresAt` and `productId` getters unchanged
- Grace period: Flutter SDK has `billingIssueDetectedAt` only; when expired + billing issue, trust active
