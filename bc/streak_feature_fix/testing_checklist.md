# Streak Feature - Testing Checklist

## ✅ Fixed Issues (Test These Scenarios)

1. **Normal App Restart:** Set streak to 5, restart app → Should remain 5 (not reset to 1)
2. **Manual Supabase Update:** Manually set streak to 6 in Supabase, restart app → App should show 6
3. **Current > Longest:** Manually set `current: 9` when `longest: 6`, restart app → `longest` should auto-update to 9
4. **Best Streak Preservation:** When streak resets to 0, `longest` should remain at highest value
5. **Fresh Data Fetch:** App should always fetch latest data from Supabase on launch (not stale cache)
6. **Cache Invalidation:** After manual DB updates, app restart should show updated values
7. **Same Day Updates:** Same-day streak changes should sync correctly to Supabase
8. **Grace Days:** Grace days should work correctly and not affect streak calculation on restart

## 🎯 Test Duration: 3-4 days
Test all scenarios above over multiple days to ensure streak calculations remain accurate.
