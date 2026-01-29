## Daily Analysis - Table Prompt Usage Plan (v2)

### Goal
- Make `ai-analyze-daily` use `ai_prompt_templates` like weekly/monthly.
- If table prompt fails at any step, log the failure and fallback to hardcoded v2.
- Keep existing flow, parsing, storage, and app behavior unchanged.

### Current State (daily)
- Daily uses hardcoded v2 prompts only.
- JSON parsing + error logging already exists.
- No table lookup for daily.

### Target State
- Primary: Use active daily prompt from `ai_prompt_templates`.
- Fallback: Use hardcoded v2 prompt (same as now) if template fetch or replacement fails.
- Logging: Log any table-fetch or template-replacement failures (function keeps working).

---

## Implementation Steps

### 1) Fetch template from table (like weekly/monthly)
Add the same query used by weekly/monthly:
- `analysis_type = 'daily'`
- `is_active = true`
- `.single()` for the active row

Example:
```
const { data: templateData, error: templateError } = await supabase
  .from('ai_prompt_templates')
  .select('*')
  .eq('analysis_type', 'daily')
  .eq('is_active', true)
  .single()
```

### 2) Log template fetch failures (do not stop flow)
If `templateError` or no `templateData`, log and fallback:
- errorCode: `ERRAI_DAILY_TEMPLATE_FETCH_001`
- failedAtStep: `fetch_prompt_template`
- errorDetails: include supabase error message/code (if any)
- requestBody: `{ entry_id, user_id }`

### 3) Build prompt from template (safe replacement)
If template exists:
- `systemPrompt = templateData.system_prompt`
- `userPrompt = templateData.user_prompt_template` and replace placeholders

If replacement fails:
- Log and fallback to hardcoded v2
- errorCode: `ERRAI_DAILY_TEMPLATE_APPLY_001`
- failedAtStep: `apply_prompt_template`
- errorDetails: include which placeholder failed (if known)

Replacement placeholders to support:
- `{entry_date}`
- `{mood_score}`
- `{diary_text}`
- `{affirmations_text}`
- `{priorities_text}`
- `{gratitude_text}`
- `{self_care_details}`
- `{meals_details}`
- `{shower_bath_status}`
- `{tomorrow_notes_text}`
- `{mood_trend}`
- `{consistency_score}`
- `{entries_count}`
- `{key_patterns}`

### 4) Keep hardcoded v2 as fallback
Use current hardcoded v2 prompt if:
- template fetch fails
- template is missing
- string replacement fails

### 5) Keep existing parse + logging
- Keep JSON parse fallback + `ERRAI_DAILY_PARSE_001` logging.
- Keep OpenAI call, save, and request logs unchanged.

---

## Error Logging Additions (Daily)
Add two new logs:

1) Template fetch error  
   - `ERRAI_DAILY_TEMPLATE_FETCH_001`  
   - `failedAtStep: fetch_prompt_template`

2) Template replacement error  
   - `ERRAI_DAILY_TEMPLATE_APPLY_001`  
   - `failedAtStep: apply_prompt_template`

Both should log and then fallback to hardcoded v2.

---

## No Changes Needed
- DB schema (ai_prompt_templates already exists)
- App/UI (no changes)
- Storage (entry_insights unchanged)

---

## Completion Criteria
- Daily uses table prompt when available.
- If table prompt fails, function logs error and continues with hardcoded v2.
- No regression in existing daily insight flow.