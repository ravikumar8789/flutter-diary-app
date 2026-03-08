# Payment Feature – Discussion 1

## Summary of Discussion

### Payment Gateway
- **Apple & Google require** native IAP (App Store / Play Store) for digital goods. No third-party gateway allowed for in-app premium.
- **Stripe, Razorpay, PayPal** – cannot be used for in-app digital subscriptions (store policy violation).
- **Blinkit uses Razorpay** – allowed because it sells physical goods (groceries). Digital goods = different rule.

### How It Works
- When user taps "Buy" → Play Store / App Store opens → user pays → that's mandatory for all apps.
- **RevenueCat is NOT a payment gateway.** Apple and Google are the payment gateways. RevenueCat is middleware that wraps StoreKit/Play Billing.

### RevenueCat vs Direct IAP
- **Both** use the same underlying flow (native store billing).
- **RevenueCat** – easier: handles receipt validation, webhooks, analytics. Free up to ~$2.5K/month.
- **Direct IAP** – more control, more code. Use Flutter `in_app_purchase` package.

### RevenueCat Role
- Integration layer (less boilerplate)
- Receipt verification
- Webhooks to sync premium status to Supabase
- Analytics

---

## Our Decision

| Component | Choice |
|-----------|--------|
| **Payment** | Google Play Billing (built-in, no extra gateway) |
| **Integration** | RevenueCat (wraps Play Billing, webhooks, verification) |

**No other payment gateway needed.**

---

## To Be Discussed Later
- Premium features (daily free, weekly/monthly premium)
- Subscription model (monthly access)
- Security layers (server-side verification, Play Integrity)
- Purchase screen / benefits
- iOS (when added – RevenueCat handles App Store too)
