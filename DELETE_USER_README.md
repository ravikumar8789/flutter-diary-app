# Complete User Deletion Guide

## Overview
This guide provides SQL queries to completely delete a user and all their data from your platform.

## Files Created

### 1. `delete_user_simple.sql` - Direct SQL Query
**Use when:** You want a simple, straightforward query to copy-paste and run directly.

**How to use:**
1. Replace `'USER_ID_HERE'` with the actual user UUID
2. Run each DELETE statement in order
3. Requires admin/service role for `auth.users` deletion

### 2. `delete_user_complete.sql` - Transaction with Error Handling
**Use when:** You want error handling and logging of what was deleted.

**How to use:**
1. Replace `'USER_ID_HERE'` with the actual user UUID
2. Run the entire DO block
3. Check the NOTICE messages for deletion counts

### 3. `delete_user_function.sql` - Reusable Function
**Use when:** You want a reusable function that can be called multiple times.

**How to use:**
1. First, run the CREATE FUNCTION statement to create the function
2. Then call it: `SELECT delete_user_complete('USER_ID_HERE');`
3. Returns JSON with success status and deletion counts

## What Gets Deleted

### Automatically Deleted (via CASCADE):
- ✅ `analysis_queue`
- ✅ `analytics_events`
- ✅ `attachments`
- ✅ `auth_providers`
- ✅ `data_deletions`
- ✅ `data_exports`
- ✅ `entries` (and all entry_* tables: entry_affirmations, entry_gratitude, entry_insights, entry_meals, entry_priorities, entry_self_care, entry_shower_bath, entry_tomorrow_notes)
- ✅ `habits_daily`
- ✅ `invoices`
- ✅ `monthly_insights`
- ✅ `notification_tokens`
- ✅ `notifications`
- ✅ `prompt_assignments`
- ✅ `streak_freeze_usage`
- ✅ `streaks`
- ✅ `subscriptions`
- ✅ `support_tickets`
- ✅ `user_profiles`
- ✅ `user_settings`
- ✅ `weekly_insights`

### Manually Deleted (NO ACTION or SET NULL constraints):
- ✅ `ai_requests_log` - Must delete before entries
- ✅ `ai_errors_log` - Set to NULL by default, but we delete them
- ✅ `error_logs` - Must delete before users

### Final Deletions:
- ✅ `public.users` - Main user table
- ✅ `auth.users` - Supabase auth table (requires admin/service role)

## Important Notes

1. **Irreversible:** This deletion is permanent and cannot be undone. Make sure you have backups if needed.

2. **Permissions:** Deleting from `auth.users` requires admin privileges or service role key. Regular authenticated users cannot delete from auth schema.

3. **Order Matters:** The queries delete in the correct order to avoid foreign key constraint violations.

4. **Testing:** Test on a non-production database first!

5. **Backup:** Consider backing up user data before deletion for compliance/audit purposes.

## Example Usage

### Using Simple Query:
```sql
-- Replace with actual UUID
DELETE FROM ai_requests_log WHERE user_id = '123e4567-e89b-12d3-a456-426614174000';
DELETE FROM ai_errors_log WHERE user_id = '123e4567-e89b-12d3-a456-426614174000';
DELETE FROM error_logs WHERE user_id = '123e4567-e89b-12d3-a456-426614174000';
DELETE FROM users WHERE id = '123e4567-e89b-12d3-a456-426614174000';
DELETE FROM auth.users WHERE id = '123e4567-e89b-12d3-a456-426614174000';
```

### Using Function:
```sql
-- Create function first (one time)
-- Then call it:
SELECT delete_user_complete('123e4567-e89b-12d3-a456-426614174000');
```

## Verification

After deletion, verify with:
```sql
-- Check if user exists in public.users
SELECT * FROM users WHERE id = 'USER_ID_HERE';

-- Check if user exists in auth.users
SELECT * FROM auth.users WHERE id = 'USER_ID_HERE';

-- Check related data (should all be empty)
SELECT COUNT(*) FROM entries WHERE user_id = 'USER_ID_HERE';
SELECT COUNT(*) FROM streaks WHERE user_id = 'USER_ID_HERE';
-- etc.
```
