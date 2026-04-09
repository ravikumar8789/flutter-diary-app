# Supabase + RevenueCat Integration – Documentation

## Overview

Integration connects RevenueCat (subscription/payment) with Supabase (backend) via webhooks. When a user purchases premium, RevenueCat sends a webhook to our Edge Function, which updates the `user_premium` table.

**Flow:** User purchases → RevenueCat → Webhook → Supabase Edge Function → `user_premium` table

---

## 1. Supabase Setup

### 1.1 user_premium Table

Created table to store premium status per user.

| Column | Type | Purpose |
|--------|------|---------|
| user_id | uuid PK, FK→users | Supabase user ID (= RevenueCat app_user_id) |
| is_premium | boolean | Quick access check |
| premium_expires_at | timestamptz | Subscription period end |
| grace_period_expires_at | timestamptz | Billing-issue grace period |
| entitlement_id | text | 'premium' |
| product_id | text | premium_monthly, premium_annual |
| store | text | play_store, app_store |
| last_event_id | text | Idempotency (skip duplicate webhooks) |
| source | text | 'revenuecat' |
| created_at, updated_at | timestamptz | Audit |

**RLS:** Enabled on `user_premium`.

### 1.2 Edge Function Secret

- **Supabase Dashboard** → Project Settings → Edge Functions → Secrets
- Added: `REVENUECAT_WEBHOOK_SECRET` = your chosen secret (e.g. `Bearer rc_secret_xyz` or plain string)
- Same value must be set in RevenueCat webhook Authorization header

### 1.3 Function Config (verify_jwt = false)

- Created `supabase/config.toml` with:
```toml
[functions.revenuecat-webhook]
verify_jwt = false
```
- Required because RevenueCat sends custom Authorization header, not Supabase JWT

---

## 2. RevenueCat Dashboard Setup

### 2.1 Project & App

- Created project
- Added Android app (or Test Store only for testing without Play Console)

### 2.2 Entitlement

- **Product catalog** → **Entitlements** → **+ New entitlement**
- Identifier: `premium`

### 2.3 Products (Test Store)

- **Product catalog** → **Products** → **+ New** (Test Store)
- `premium_monthly` – Subscription, 1 month
- `premium_annual` – Subscription, 1 year

### 2.4 Attach Products to Entitlement

- Opened `premium` entitlement → **Attach**
- Attached `premium_monthly` and `premium_annual`

### 2.5 Offering

- **Product catalog** → **Offerings** → **+ New offering**
- Identifier: `default` (or `premium` if default exists)
- Packages: Monthly (`$rc_monthly`), Annual (`$rc_annual`)
- Set as current offering

### 2.6 Webhook

- **Integrations** → **Webhooks** → **+ New**
- **URL:** `https://YOUR_PROJECT_REF.supabase.co/functions/v1/revenuecat-webhook`
- **Authorization header:** Same value as `REVENUECAT_WEBHOOK_SECRET`
- **Environment:** Sandbox (or Both)
- **Name:** e.g. Supabase

---

## 3. Edge Function: revenuecat-webhook

**Path:** `supabase/functions/revenuecat-webhook/index.ts`

### 3.1 Logic

1. Verify `Authorization` header matches `REVENUECAT_WEBHOOK_SECRET`
2. Parse `event` from JSON body
3. Check if `app_user_id` exists in `users` table (FK) → skip if not
4. Idempotency: skip if `last_event_id` already processed
5. Determine grant/revoke from `event.type` and `entitlement_ids`
6. Upsert `user_premium`

### 3.2 Event Types Handled

| Event | Action |
|-------|--------|
| INITIAL_PURCHASE, RENEWAL, PRODUCT_CHANGE, TEST | Grant premium |
| EXPIRATION | Revoke premium |
| CANCELLATION | Keep premium until period end |

### 3.3 Deploy Command

```bash
supabase functions deploy revenuecat-webhook
```

---

## 4. Issues Faced & Solutions

### Issue 1: 401 Invalid JWT

**Symptom:** Webhook returns `{"code":401,"message":"Invalid JWT"}`

**Cause:** Supabase expects a valid JWT in the Authorization header. RevenueCat sends a custom secret.

**Solution:** Add `verify_jwt = false` for `revenuecat-webhook` in `supabase/config.toml`. Redeploy.

---

### Issue 2: 500 {"error":"[object Object]"}

**Symptom:** Webhook returns 500 with unhelpful error message.

**Causes:**
1. **FK violation** – `app_user_id` from test webhook (random UUID) doesn't exist in `users` table
2. **Error serialization** – `String(e)` on Error object yields `[object Object]`

**Solutions:**
1. Check if user exists in `users` before upsert. If not, return `200` with `skipped: 'user_not_found'`
2. Use `e instanceof Error ? e.message : JSON.stringify(e)` for error response

---

### Issue 3: No Row in user_premium After Test Webhook

**Symptom:** Webhook returns `{"ok":true,"skipped":"user_not_found"}` but no row in `user_premium`.

**Cause:** RevenueCat test webhook uses random UUIDs. Those users don't exist in `users`.

**Solution:** Expected. For real purchases, `Purchases.logIn(supabaseUserId)` ensures `app_user_id` = real user. To test with DB insert: send curl with a real `users.id` in `app_user_id`.

---

## 5. Testing

### 5.1 RevenueCat Test Webhook

- **Integrations** → **Webhooks** → Your webhook → **Send test**
- With random UUID: expect `200` + `{"ok":true,"skipped":"user_not_found"}`
- With real user UUID: expect `200` + `{"ok":true}` and row in `user_premium`

### 5.2 Manual curl (Real User)

```bash
curl -X POST "https://YOUR_PROJECT.supabase.co/functions/v1/revenuecat-webhook" \
  -H "Content-Type: application/json" \
  -H "Authorization: YOUR_SECRET" \
  -d '{"event":{"id":"test-123","app_user_id":"REAL_USER_UUID","type":"INITIAL_PURCHASE","entitlement_ids":["premium"],"expiration_at_ms":1772998992466,"product_id":"premium_monthly","store":"PLAY_STORE"}}'
```

Replace `REAL_USER_UUID` with a valid `users.id`.

---

## 6. Checklist

| Item | Status |
|------|--------|
| user_premium table | ✅ |
| RLS on user_premium | ✅ |
| REVENUECAT_WEBHOOK_SECRET in Supabase | ✅ |
| config.toml (verify_jwt = false) | ✅ |
| revenuecat-webhook Edge Function | ✅ |
| RevenueCat entitlement `premium` | ✅ |
| RevenueCat products (monthly, annual) | ✅ |
| RevenueCat offering | ✅ |
| RevenueCat webhook URL + auth | ✅ |
| Webhook test (200 response) | ✅ |

---

## 7. Next Steps (App Level)

- [x] Configure RevenueCat SDK on app start (`PremiumService.configure()` in main.dart)
- [x] Call `Purchases.logIn(supabaseUserId)` after login (splash screen)
- [x] Call `PremiumService.logOut()` on auth sign out
- [ ] Payment screen / paywall
- [ ] Premium check before weekly/monthly analysis

### .env

Add to `.env`:

```
REVENUECAT_API_KEY=your_public_sdk_key
```

Or platform-specific:

```
REVENUECAT_ANDROID_KEY=your_android_key
REVENUECAT_IOS_KEY=your_ios_key
```

Get keys from RevenueCat Dashboard → Project Settings → API keys.
