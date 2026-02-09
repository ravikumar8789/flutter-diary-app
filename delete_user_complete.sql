-- Complete User Deletion Query
-- Usage: Replace 'USER_ID_HERE' with the actual user UUID
-- This query deletes a user and ALL their data from the platform

DO $$
DECLARE
    target_user_id UUID := 'USER_ID_HERE'; -- Replace with actual user ID
    deleted_count INTEGER;
BEGIN
    -- Step 1: Delete AI request logs (NO ACTION constraint - must delete manually)
    DELETE FROM ai_requests_log WHERE user_id = target_user_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % rows from ai_requests_log', deleted_count;
    
    -- Step 2: Delete AI error logs (SET NULL constraint - but we want to delete them)
    DELETE FROM ai_errors_log WHERE user_id = target_user_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % rows from ai_errors_log', deleted_count;
    
    -- Step 3: Delete error logs (NO ACTION constraint - must delete manually)
    DELETE FROM error_logs WHERE user_id = target_user_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % rows from error_logs', deleted_count;
    
    -- Step 4: Delete from public.users (this will CASCADE delete most related data)
    -- Tables that will be auto-deleted via CASCADE:
    --   - analysis_queue, analytics_events, attachments, auth_providers
    --   - data_deletions, data_exports, entries (and all entry_* tables via CASCADE)
    --   - habits_daily, invoices, monthly_insights, notification_tokens
    --   - notifications, prompt_assignments, streak_freeze_usage, streaks
    --   - subscriptions, support_tickets, user_profiles, user_settings, weekly_insights
    DELETE FROM users WHERE id = target_user_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    IF deleted_count > 0 THEN
        RAISE NOTICE 'Deleted user from public.users';
        
        -- Step 5: Delete from auth.users (Supabase auth table)
        -- Note: This requires admin privileges or service role key
        DELETE FROM auth.users WHERE id = target_user_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        
        IF deleted_count > 0 THEN
            RAISE NOTICE 'Deleted user from auth.users';
            RAISE NOTICE 'User deletion completed successfully!';
        ELSE
            RAISE WARNING 'User deleted from public.users but not found in auth.users';
        END IF;
    ELSE
        RAISE WARNING 'User with ID % not found in public.users', target_user_id;
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error deleting user: %', SQLERRM;
END $$;
