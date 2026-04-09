# Google Play Console Migration Plan

Use this document when migrating from RevenueCat Test Store to Google Play Console for production.

---

## Prerequisites

- [ ] $25 one-time Play Developer account fee paid
- [ ] App tested with Test Store
- [ ] Product IDs match: `premium_monthly`, `premium_annual`

---

## Part 1: Google Play Console

### 1.1 Create Developer Account

1. Go to [Google Play Console](https://play.google.com/console/)
2. Sign up – **Individual** (no D-U-N-S) or **Business** (requires D-U-N-S)
3. Pay $25 one-time fee

### 1.2 Create App

1. **All apps** → **Create app**
2. App name, default language, app or game, free/paid
3. Declarations (content rating, target audience, etc.)

### 1.3 Create Subscription Products

1. **Monetize** → **Products** → **Subscriptions** → **Create subscription**

**Product 1 – Monthly**

| Field | Value |
|-------|--------|
| Product ID | `premium_monthly` |
| Name | Premium Monthly |
| Description | Access to weekly and monthly analysis |

- Add **Base plan**: monthly, set price, auto-renewing
- Activate

**Product 2 – Annual**

| Field | Value |
|-------|--------|
| Product ID | `premium_annual` |
| Name | Premium Annual |
| Description | Access to weekly and monthly analysis |

- Add **Base plan**: yearly, set price, auto-renewing
- Activate

### 1.4 Upload Build

- **Release** → **Testing** → **Internal testing** (or Closed)
- Upload signed AAB/APK
- Complete store listing, content rating, etc.

---

## Part 2: Google Cloud – Service Account

### 2.1 Enable APIs

1. [Google Cloud Console](https://console.cloud.google.com/)
2. Select project linked to Play Console
3. **APIs & Services** → **Library** – enable:
   - Google Play Android Developer API
   - Google Play Developer Reporting API
   - Cloud Pub/Sub API

### 2.2 Create Service Account

1. **IAM & Admin** → **Service Accounts** → **Create**
2. Name: `revenuecat`
3. Roles: **Pub/Sub Editor**, **Monitoring Viewer**
4. **Keys** → **Add key** → **Create new key** → JSON
5. Download JSON file

### 2.3 Add to Play Console

1. **Users and permissions** → **Invite new users**
2. Email: service account email from JSON
3. **Account permissions:**
   - Manage orders and subscriptions
   - View financial data, orders, and cancellation survey response
   - View app information and download bulk reports (read-only)
4. **App permissions:** Add your app
5. Invite

---

## Part 3: RevenueCat

### 3.1 Add Android App (if not added)

1. Project → **+ New** → **Google Play Store**
2. App name, package name (must match Play Console)

### 3.2 Upload Service Credentials

1. Project → Android app → **Service credentials**
2. Upload JSON key file
3. Save
4. Wait up to 36 hours for validation (or use product description edit workaround)

### 3.3 Import Products

1. **Product catalog** → **Products**
2. Import from Google Play (after credentials valid)
3. Or add manually: `premium_monthly`, `premium_annual`
4. Attach both to `premium` entitlement

### 3.4 Get Production API Key

1. **Project Settings** → **API Keys**
2. Copy **Public API key** for Google Play (Android) app

---

## Part 4: App Code

### 4.1 Switch API Key

**Option A – Build flavor / env**

```dart
const apiKey = kReleaseMode 
  ? "goog_xxxxxxxx"  // Production – from RevenueCat
  : "test_onWmlqbJAtZBIHStfxnbFboguIS";  // Test Store
```

**Option B – dart-define**

```bash
flutter run --dart-define=REVENUECAT_API_KEY=goog_xxxx
```

### 4.2 Verify Constants

- Product IDs: `premium_monthly`, `premium_annual`
- Entitlement: `premium`
- Offering: `default`

No changes needed if already using constants.

---

## Part 5: Webhook

- No changes – same URL, same handler
- RevenueCat sends `environment: "PRODUCTION"` for real purchases
- Webhook handles both SANDBOX and PRODUCTION

---

## Part 6: Testing

1. Add testers in **Internal testing** track
2. Install app from Play Store (internal link)
3. Make test purchase (use license testers in Play Console)
4. Verify webhook fires, `user_premium` updates
5. Verify premium content unlocks

---

## Checklist

| Step | Done |
|------|------|
| Play Developer account | |
| App created in Play Console | |
| Subscriptions: premium_monthly, premium_annual | |
| Signed AAB uploaded | |
| Google Cloud APIs enabled | |
| Service account created + JSON downloaded | |
| Service account invited in Play Console | |
| JSON uploaded to RevenueCat | |
| RevenueCat credentials validated | |
| Products imported/attached in RevenueCat | |
| Production API key copied | |
| App code: API key switched for release | |
| Internal test purchase | |
| Webhook + user_premium verified | |

---

## Rollback

If issues: switch API key back to Test Store key, redeploy. No other changes needed.
