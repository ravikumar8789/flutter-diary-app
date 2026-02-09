-- Create a reusable function for user deletion
-- Usage: SELECT delete_user_complete('USER_ID_HERE');

CREATE OR REPLACE FUNCTION delete_user_complete(target_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
    deleted_counts JSONB := '{}'::JSONB;
    deleted_count INTEGER;
BEGIN
    -- Step 1: Delete AI request logs (NO ACTION constraint)
    DELETE FROM ai_requests_log WHERE user_id = target_user_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    deleted_counts := jsonb_set(deleted_counts, '{ai_requests_log}', to_jsonb(deleted_count));
    
    -- Step 2: Delete AI error logs (SET NULL constraint)
    DELETE FROM ai_errors_log WHERE user_id = target_user_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    deleted_counts := jsonb_set(deleted_counts, '{ai_errors_log}', to_jsonb(deleted_count));
    
    -- Step 3: Delete error logs (NO ACTION constraint)
    DELETE FROM error_logs WHERE user_id = target_user_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    deleted_counts := jsonb_set(deleted_counts, '{error_logs}', to_jsonb(deleted_count));
    
    -- Step 4: Delete from public.users (CASCADE will auto-delete related data)
    DELETE FROM users WHERE id = target_user_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    deleted_counts := jsonb_set(deleted_counts, '{users}', to_jsonb(deleted_count));
    
    IF deleted_count = 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'User not found in public.users',
            'user_id', target_user_id,
            'deleted_counts', deleted_counts
        );
    END IF;
    
    -- Step 5: Delete from auth.users (Supabase auth)
    DELETE FROM auth.users WHERE id = target_user_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    deleted_counts := jsonb_set(deleted_counts, '{auth_users}', to_jsonb(deleted_count));
    
    result := jsonb_build_object(
        'success', true,
        'message', 'User deleted successfully',
        'user_id', target_user_id,
        'deleted_counts', deleted_counts
    );
    
    RETURN result;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM,
            'user_id', target_user_id,
            'deleted_counts', deleted_counts
        );
END;
$$;

-- Grant execute permission (adjust as needed for your security model)
-- GRANT EXECUTE ON FUNCTION delete_user_complete(UUID) TO authenticated;
