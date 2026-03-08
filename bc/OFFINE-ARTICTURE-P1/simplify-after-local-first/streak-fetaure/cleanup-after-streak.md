# Streak Feature Cleanup Report

**Date:** 2025-02-27

## Summary

Removed dead code and unused imports related to the streak feature after consolidating to today-only habits_daily and streak table as source of truth.

---

## Removed

### 1. data_providers.dart
- `habitsProvider` — unused provider
- `HabitsQueryParams` — only used by habitsProvider
- `analytics_models` import — no longer needed

### 2. data_fetch_service.dart
- `fetchBatch()` — never called
- `BatchData` class — only used by fetchBatch
- `fetchAllHabitsDaily()` — deprecated, returned empty list

### 3. data_prefetch_service.dart
- `prefetch7DaysData()` — never called
- `prefetchTodayData()` — never called
- `_fetchEntriesWithJoins()` — only used by prefetch7DaysData
- `_fetchHabits()` — only used by prefetch7DaysData

### 4. user_data_service.dart
- `sqflite` import — unused
- `uuid` import — unused

---

## Kept (still in use)

- `fetchHabitsDaily` — used by analytics_service
- `fetchHabitsForDate` — used by home_summary_service
- `storeEntriesWithRelatedData` — DataPrefetchService wrapper (not called; EntryStorageHelper used directly elsewhere)

---

## Impact

- No feature impact
- No breaking changes
- Analytics and home summary continue to work
