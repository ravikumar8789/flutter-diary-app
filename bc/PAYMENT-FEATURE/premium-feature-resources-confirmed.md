# Premium Feature – Resources Confirmed

## Payment & Integration (Fixed)

| Component | Choice |
|-----------|--------|
| **Payment** | Google Play Billing (built-in, no extra gateway) |
| **Integration** | RevenueCat (wraps Play Billing, webhooks, verification) |

No `in_app_purchase` package needed. RevenueCat SDK handles Play Billing internally.

---

## Subscription Model (Fixed)

| Analysis | Access |
|----------|--------|
| Daily | Free |
| Weekly | Paid (Premium) |
| Monthly | Paid (Premium) |

**Model:** Subscription (not pay-per-analysis). User pays → gets access to weekly + monthly analysis for that month. Renew next month to continue. Frame as "Premium access" not "pay per report."

**Annual plan** (e.g. 12 months) for better value, less renewal fatigue.

---

## Dependencies

```yaml
dependencies:
  purchases_flutter: ^7.0.0  # or latest – RevenueCat Flutter SDK
```

---

## Future Reference
- RevenueCat account + dashboard required
- Google Play Console – create subscription products
- Link Play Console app in RevenueCat dashboard

---

## Tables

### Existing (Use)
- `users` – app_user_id mapping
- `weekly_insights` – premium-gated content
- `monthly_insights` – premium-gated content

### New (Create)
- `user_premium` – RevenueCat webhook data, premium status ✅ Done (RLS enabled)

### user_premium Schema

| Column | Type | Nullable | Purpose |
|--------|------|----------|---------|
| user_id | uuid | NO | PK, FK → users(id) ON DELETE CASCADE |
| is_premium | boolean | NO | Quick access check (default false) |
| premium_expires_at | timestamptz | YES | When subscription period ends |
| grace_period_expires_at | timestamptz | YES | Billing-issue grace period end |
| entitlement_id | text | YES | Entitlement ID (e.g. 'premium') |
| product_id | text | YES | Product ID (e.g. 'premium_monthly', 'premium_annual') |
| store | text | YES | 'play_store' \| 'app_store' |
| last_event_id | text | YES | RevenueCat event ID for idempotency |
| source | text | YES | 'revenuecat' \| 'manual' (default 'revenuecat') |
| created_at | timestamptz | NO | First grant time |
| updated_at | timestamptz | NO | Last update time |

**Premium check:** `is_premium = true` AND (`premium_expires_at > now()` OR `grace_period_expires_at > now()`)

**Idempotency:** `last_event_id` – if webhook event_id equals this, skip processing.

```sql
CREATE TABLE public.user_premium (
  user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  is_premium boolean NOT NULL DEFAULT false,
  premium_expires_at timestamptz,
  grace_period_expires_at timestamptz,
  entitlement_id text DEFAULT 'premium',
  product_id text,
  store text CHECK (store IN ('play_store', 'app_store')),
  last_event_id text,
  source text DEFAULT 'revenuecat' CHECK (source IN ('revenuecat', 'manual')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_user_premium_expires ON public.user_premium(premium_expires_at) 
  WHERE is_premium = true;
```

---

## Edge Function (Implement Later)
- RevenueCat webhook handler – receive webhooks, update `user_premium`
- Premium-gated content – check `user_premium` before serving weekly/monthly analysis

---

## Subscription Timing (Handle Later)
- **Past weeks:** Premium user gets access to all existing weekly/monthly analysis (backdating allowed).
- **Monthly timing:** User buying mid-month (e.g. 24th) may miss next month's monthly analysis (generated after their expiry). Consider on-demand generation or extended first period. Handle later.

---

## Cleanup (After Feature Implemented)
Remove these tables if still unused: `subscriptions`, `plans`, `invoices`
