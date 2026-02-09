-- Simple User Deletion Query (Direct SQL)
-- Replace 'USER_ID_HERE' with the actual user UUID

-- Step 1: Delete AI request logs (NO ACTION constraint)
DELETE FROM ai_requests_log WHERE user_id = 'USER_ID_HERE';

-- Step 2: Delete AI error logs (SET NULL constraint - but we delete them)
DELETE FROM ai_errors_log WHERE user_id = 'USER_ID_HERE';

-- Step 3: Delete error logs (NO ACTION constraint)
DELETE FROM error_logs WHERE user_id = 'USER_ID_HERE';

-- Step 4: Delete from public.users (CASCADE will delete most related data automatically)
DELETE FROM users WHERE id = 'USER_ID_HERE';

-- Step 5: Delete from auth.users (Supabase auth - requires admin/service role)
DELETE FROM auth.users WHERE id = 'USER_ID_HERE';
