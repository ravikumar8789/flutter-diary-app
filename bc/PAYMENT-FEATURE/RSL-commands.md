# RLS Commands – Execute One by One in Supabase SQL Editor

**Optional – Check existing policies first:**
```sql
SELECT tablename, policyname FROM pg_policies WHERE tablename IN ('weekly_insights', 'monthly_insights');
```
If any policies exist, drop them before creating new ones (use `DROP POLICY "policy_name" ON table_name`).

---

## Step 1: Enable RLS on weekly_insights
```sql
ALTER TABLE public.weekly_insights ENABLE ROW LEVEL SECURITY;
```

## Step 2: Enable RLS on monthly_insights
```sql
ALTER TABLE public.monthly_insights ENABLE ROW LEVEL SECURITY;
```

## Step 3: Drop existing policy on weekly_insights
```sql
DROP POLICY IF EXISTS "weekly_insights_owner" ON public.weekly_insights;
DROP POLICY IF EXISTS "Premium users can view own weekly insights" ON public.weekly_insights;
```

## Step 4: Create SELECT policy for weekly_insights
```sql
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
```

## Step 5: Drop existing policy on monthly_insights
```sql
DROP POLICY IF EXISTS "Users can view own monthly insights" ON public.monthly_insights;
DROP POLICY IF EXISTS "Premium users can view own monthly insights" ON public.monthly_insights;
```

## Step 6: Create SELECT policy for monthly_insights
```sql
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

---

**Note:** Steps 3 and 5 drop the existing policies (`weekly_insights_owner`, `Users can view own monthly insights`) before creating the new premium-gated ones.
