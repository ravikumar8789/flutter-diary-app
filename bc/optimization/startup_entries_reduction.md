# Startup Entries Reduction - Implementation Notes

Date: January 2026

Goal
- Reduce duplicate startup and entry-related API calls without changing core behavior.
- No database changes are required.

Changes implemented
1) Entry save path (`lib/providers/entry_provider.dart`)
   - Avoids refetching entry from cloud during batch save when state already has it.
   - Adds save-in-progress lock and queued save scheduling.
   - Skips save if no pending changes.

2) Cloud entry fetch dedup (`lib/services/sync/supabase_sync_service.dart`)
   - In-flight request map ensures identical entry fetches share one network call.

3) Background refetch dedup (`lib/repositories/data_repository.dart`)
   - Stale-while-revalidate background refetch is now deduplicated per key.

4) Startup prefetch consolidation (`lib/screens/splash_screen.dart`)
   - Skips prefetchTodayData when 7-day prefetch already ran.
   - Home summary cache invalidation happens once after prefetch steps.

5) Streak recalculation coalescing (`lib/services/user_data_service.dart`)
   - Prevents overlapping recalculation runs for the same user.

Notes
- No schema or RPC changes.
- Existing error logging remains unchanged.