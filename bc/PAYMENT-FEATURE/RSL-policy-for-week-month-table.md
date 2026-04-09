# RLS Policy for weekly_insights and monthly_insights

## Goal
Block non-premium users from reading weekly/monthly insights at the database level. Premium check via `user_premium` table.

## Tables
- `weekly_insights`
- `monthly_insights`

## Premium Condition
User has valid premium in `user_premium`:
- `is_premium = true`
- AND (`premium_expires_at IS NULL` OR `premium_expires_at > now()` OR `grace_period_expires_at > now()`)

## Implementation

### 1. Create migration file
`supabase/migrations/008_premium_rls_weekly_monthly.sql`

### 2. Enable RLS (if not already)
```sql
ALTER TABLE public.weekly_insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monthly_insights ENABLE ROW LEVEL SECURITY;
```

### 3. Drop existing SELECT policies (if any)
Check current policies first. Drop any that allow SELECT without premium check.

### 4. Create SELECT policies
```sql
-- weekly_insights
CREATE POLICY "Premium users can view own weekly insights"
  ON public.weekly_insights FOR SELECT
  USING (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM public.user_premium up
      WHERE up.user_id = auth.uid()
        AND up.is_premium = true
        AND (
          up.premium_expires_at IS NULL
          OR up.premium_expires_at > now()
          OR (up.grace_period_expires_at IS NOT NULL AND up.grace_period_expires_at > now())
        )
    )
  );

-- monthly_insights (same logic)
CREATE POLICY "Premium users can view own monthly insights"
  ON public.monthly_insights FOR SELECT
  USING (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM public.user_premium up
      WHERE up.user_id = auth.uid()
        AND up.is_premium = true
        AND (
          up.premium_expires_at IS NULL
          OR up.premium_expires_at > now()
          OR (up.grace_period_expires_at IS NOT NULL AND up.grace_period_expires_at > now())
        )
    )
  );
```

### 5. Service role (Edge Functions)
Edge Functions use service role key → bypass RLS. No policy needed for INSERT/upsert.

## Notes
- App (anon + JWT) → RLS applies → non-premium gets no rows
- Old app: shows "Coming Soon" in AI Insights card (not paywall)
- New app: client-side shows PaywallContent before fetch; RLS is backup
