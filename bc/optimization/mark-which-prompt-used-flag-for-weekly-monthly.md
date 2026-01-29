# Implementation Plan: Prompt Source Tracking for Weekly & Monthly Analysis

## Goal
Add prompt-source tracking (`table` vs `hardcode`) to weekly and monthly analysis functions, matching the daily implementation.

## Current State
- **Weekly**: Fetches template from `ai_prompt_templates` table, falls back to hardcoded v2 if not found. No tracking.
- **Monthly**: Same pattern as weekly.
- **Daily**: ✅ Already implemented with `promptSource` flag and `model_version` tracking.

## Implementation Steps

### 1. Weekly Analysis (`ai-analyze-weekly/index.ts`)

**Changes needed:**
- Add `let promptSource = 'hardcode'` before template fetch (line ~292).
- After successful template fetch + apply (line ~301-362), set `promptSource = 'table'`.
- On any template error (fetch or apply), keep `promptSource = 'hardcode'` (already default).
- When saving to `weekly_insights` (line ~541), update `model_version`:
  - `model_version: promptSource === 'table' ? 'gpt-4o-mini||table' : 'gpt-4o-mini||hardcode'`

**Key locations:**
- Template fetch: lines 293-299
- Template apply: lines 405-430 (string replacements)
- Save to DB: line ~541 (`model_version` field)

### 2. Monthly Analysis (`ai-analyze-monthly/index.ts`)

**Changes needed:**
- Add `let promptSource = 'hardcode'` before template fetch (line ~162).
- After successful template fetch + apply (line ~170-260), set `promptSource = 'table'`.
- On any template error (fetch or apply), keep `promptSource = 'hardcode'` (already default).
- When saving to `monthly_insights` (line ~441), update `model_version`:
  - `model_version: promptSource === 'table' ? 'gpt-4o-mini||table' : 'gpt-4o-mini||hardcode'`

**Key locations:**
- Template fetch: lines 163-168
- Template apply: lines 260-290 (string replacements)
- Save to DB: line ~441 (`model_version` field)

## Detection Logic

**Set `promptSource = 'table'` only when:**
1. Template fetch succeeds (`templateData` exists).
2. Template apply succeeds (all placeholders replaced without errors).

**Otherwise:**
- Keep `promptSource = 'hardcode'` (default).

## Output Format

- **Weekly**: `weekly_insights.model_version = 'gpt-4o-mini||table'` or `'gpt-4o-mini||hardcode'`
- **Monthly**: `monthly_insights.model_version = 'gpt-4o-mini||table'` or `'gpt-4o-mini||hardcode'`

## Notes

- **No DB schema changes** (field already exists).
- **No app changes** (app just reads the text value).
- **Error logging unchanged** (template errors already logged separately).
- **Same pattern as daily** (proven to work).

## Testing

After implementation:
1. Check `weekly_insights.model_version` after weekly analysis → should show `||table` or `||hardcode`.
2. Check `monthly_insights.model_version` after monthly analysis → should show `||table` or `||hardcode`.
