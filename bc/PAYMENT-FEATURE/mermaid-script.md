%%{init: {"flowchart": {"htmlLabels": false}} }%%
flowchart TB
    subgraph ENV[".env"]
        N1[REVENUECAT_API_KEY]
        N2[REVENUECAT_ANDROID_KEY]
        N3[REVENUECAT_IOS_KEY]
    end

    subgraph MAIN["main.dart - App Start"]
        M1[dotenv.load]
        M2[Supabase.initialize url anonKey]
        M3[PremiumService.configure]
        M1 --> M2
        M2 --> M3
        M3 -->|apiKey from _getApiKey| C1
    end

    subgraph RC_CONFIGURE["RevenueCat SDK Configure"]
        C1[Purchases.configure PurchasesConfiguration apiKey]
        C2[_isConfigured true]
        C1 --> C2
    end

    subgraph SPLASH["splash_screen.dart - Online Path"]
        S1[auth.currentUser]
        S2[user.id Supabase UUID]
        S3[PremiumService.logIn user.id]
        S1 -->|user not null| S2
        S2 --> S3
        S3 -->|app_user_id user.id| L1
    end

    subgraph RC_LOGIN["RevenueCat logIn"]
        L1[Purchases.logIn supabaseUserId]
        L2[Links device to app_user_id Supabase user_id]
        L1 --> L2
    end

    subgraph SPLASH_FETCH["Splash - 5 Parallel Fetches"]
        F1[fetchAndMergeUserProfile]
        F2[fetchAndMergeUserSettings]
        F3[fetchAndMergeStreaks]
        F4[fetchAndMergeEntriesWithJoins]
        F5[fetchAndStoreYesterdayInsight]
    end

    S3 --> F1
    S3 --> F2
    S3 --> F3
    S3 --> F4
    S3 --> F5

    subgraph PROFILE["profile_screen.dart"]
        P1[_buildProfileContent]
        P2[_buildPremiumSection]
        P3[ref.watch premiumProvider]
        P2 --> P3
    end

    subgraph PREMIUM_PROVIDER["premium_provider.dart"]
        PP1[PremiumService.getCustomerInfo]
        PP2[PremiumState isPremium customerInfo premiumExpiresAt productId]
        PP1 -->|CustomerInfo| PP2
    end

    subgraph RC_GET_CUSTOMER["RevenueCat getCustomerInfo"]
        G1[Purchases.getCustomerInfo]
        G2[Returns from RevenueCat API or local cache]
        G3[CustomerInfo entitlements.active premium]
        G1 --> G2
        G2 --> G3
    end

    P3 --> PP1
    PP1 --> G1

    subgraph PROFILE_UI["Profile UI Decision"]
        U1{state.isPremium}
        U2[Show Premium card]
        U3[Show Upgrade to Premium card]
        U1 -->|true| U2
        U1 -->|false| U3
        PP2 --> U1
    end

    subgraph NAV_TO_PREMIUM["Tap Premium Card"]
        V1[Navigator.push PremiumScreen]
        U2 --> V1
        U3 --> V1
    end

    subgraph PREMIUM_SCREEN["premium_screen.dart"]
        PS1[ref.watch premiumProvider]
        PS2{state.isPremium}
        PS3[_PremiumDetailsContent]
        PS4[PaywallContent]
        PS1 --> PS2
        PS2 -->|true| PS3
        PS2 -->|false| PS4
    end

    V1 --> PS1

    subgraph PREMIUM_DETAILS_UI["PremiumDetails Variables"]
        D1[premiumExpiresAt ent.expirationDate]
        D2[productId ent.productIdentifier]
        D3[Status Active]
        D4[expiresStr dd/mm/yyyy]
    end

    PS3 --> D1

    subgraph PAYWALL["paywall_content.dart"]
        W1[_loadOfferings]
        W2[PremiumService.getCurrentOffering]
        W3[_offering.availablePackages]
        W4[_selectedPackage Package]
        W1 --> W2
        W2 --> W3
        W3 --> W4
    end

    PS4 --> W1

    subgraph RC_OFFERINGS["RevenueCat getOfferings"]
        O1[Purchases.getOfferings]
        O2[Offerings current all default]
        O3[Offering.availablePackages monthly annual]
        O1 --> O2
        O2 --> O3
    end

    W2 --> O1

    subgraph PURCHASE_FLOW["User Taps Subscribe"]
        X1[PremiumService.purchasePackage]
        X1 --> Y1
    end

    subgraph RC_PURCHASE["RevenueCat purchasePackage"]
        Y1[Purchases.purchasePackage package]
        Y2[Google Play App Store]
        Y3[Receipt sent to RevenueCat]
        Y4[RevenueCat updates customer record]
        Y5[PurchaseResult.customerInfo]
        Y1 --> Y2
        Y2 --> Y3
        Y3 --> Y4
        Y4 --> Y5
    end

    W4 --> X1

    subgraph RC_WEBHOOK["RevenueCat Webhook async"]
        H1[Purchase event triggers webhook]
        H2[POST to Supabase Edge Function]
        H3[body event id app_user_id type entitlement_ids]
        H4[Authorization REVENUECAT_WEBHOOK_SECRET]
        H1 --> H2
        H2 --> H3
        H2 --> H4
    end

    Y4 --> H1

    subgraph SUPABASE_WEBHOOK["Supabase revenuecat-webhook Edge Function"]
        E1[Verify Authorization header]
        E2[Parse event from JSON]
        E3[app_user_id exists in users]
        E4[last_event_id already processed]
        E5[Determine grant revoke from event.type]
        E6[Upsert user_premium]
        E1 --> E2
        E2 --> E3
        E3 -->|yes| E4
        E4 -->|no| E5
        E5 --> E6
    end

    subgraph EVENT_TYPES["Event types handled"]
        EV1[INITIAL_PURCHASE RENEWAL PRODUCT_CHANGE TEST grant]
        EV2[EXPIRATION revoke]
        EV3[CANCELLATION keep until period end]
    end

    H2 --> E1

    subgraph USER_PREMIUM["Supabase user_premium table"]
        T1[user_id PK FK users]
        T2[is_premium]
        T3[premium_expires_at]
        T4[grace_period_expires_at]
        T5[entitlement_id premium]
        T6[product_id]
        T7[store]
        T8[last_event_id]
    end

    E6 --> T1

    subgraph RESTORE_FLOW["User Taps Restore"]
        R1[PremiumService.restorePurchases]
        R2[PremiumService.invalidateCache]
        R3[ref.invalidate premiumProvider]
        R1 --> R2
        R2 --> R3
    end

    subgraph RC_RESTORE["RevenueCat restorePurchases"]
        RS1[Purchases.restorePurchases]
        RS2[Sync with Store]
        RS3[Returns CustomerInfo]
        RS1 --> RS2
        RS2 --> RS3
    end

    R1 --> RS1

    subgraph CACHE_REFRESH["Cache refresh points"]
        CR1[After purchase ref.invalidate premiumProvider]
        CR2[After restore invalidateCache and ref.invalidate]
        CR3[Pop from PremiumScreen ref.invalidate]
    end

    Y5 --> CR1

    subgraph SOURCE_OF_TRUTH["Source of Truth"]
        SOT1[UI Premium Check RevenueCat CustomerInfo]
        SOT2[Backend RLS Supabase user_premium]
        SOT3[App does NOT read user_premium for UI]
    end

    subgraph LOGOUT["AuthService.signOut"]
        LO1[PremiumService.logOut]
        LO2[_client.auth.signOut]
        LO1 --> LO2
    end

    subgraph RC_LOGOUT["RevenueCat logOut"]
        RL1[Purchases.logOut]
        RL2[Generates new anonymous app_user_id]
        RL1 --> RL2
    end

    LO1 --> RL1
