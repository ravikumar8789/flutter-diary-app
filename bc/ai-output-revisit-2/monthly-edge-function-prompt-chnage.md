# Monthly Analysis v3 — Change Plan
**Status:** Plan only — pending review before implementation  
**Files to change:** `supabase/functions/ai-analyze-monthly/index.ts` + `ai_prompt_templates` DB row

---

## Part 1 — Edge Function Changes (`index.ts`)

### 1. Remove local `extractTopics()` call
**Line 130** — delete this line:
```
const topics = extractTopics(entries).slice(0, 7)
```
The `extractTopics()` function itself can stay (not called, not harmful), or be deleted — doesn't matter.

---

### 2. Remove `{top_topics_list}` from prompt input builder
**Line 322** — delete this line:
```
.replace('{top_topics_list}', topics.join(', ') || 'None')
```

---

### 3. Parse `top_topics` from AI response
**Around line 375** (inside the `try { const parsed = JSON.parse(...) }` block) — add:
```ts
topTopics = Array.isArray(parsed.top_topics) ? parsed.top_topics : []
```
Also declare `let topTopics: string[] = []` alongside the other field declarations at line ~362.

---

### 4. Save AI-generated `top_topics` to DB
**Line 429** — change:
```ts
top_topics: topics.slice(0, 7),
```
to:
```ts
top_topics: topTopics.slice(0, 7),
```

---

### 5. Hardcoded fallback (lines 177–301)
The fallback still has the full v2 prompt and forces `next_month_goals: []`.  
**Decision needed:** Update fallback to v3 or leave as-is.  
Recommendation: Leave for now — fallback only fires if DB fetch fails (rare). Can be updated in a separate pass.

---

## Part 2 — Prompt Changes (v3 DB insert)

The base prompt is already in `monthly_analysis_improvement_report.md §5 and §6`.  
Two additions needed before inserting to DB:

### 1. Add `top_topics` to output schema
In `OUTPUT FORMAT RULES`, add `top_topics` to the schema object:
```
{
  "highlights": string,
  "growth_areas": string[],
  "achievements": string[],
  "next_month_goals": string[],
  "habit_analysis": string[],
  "key_moments": string[],
  "reflection_questions": string[],
  "strengths": string[],
  "top_topics": string[]
}
```

### 2. Update TOPICS RULE to make it an output field
Replace the current TOPICS RULE (which is ambiguously worded) with:
```
TOPICS RULE:
- Extract 5-7 top_topics — real meaningful themes, emotions, people, or events from the month.
- Read all fields: diary, gratitude, affirmations, priorities, tomorrow notes.
- Do NOT use frequency of words. Think about what this month was actually about.
- Do NOT include Hindi filler words, common verbs, or generic words.
```

### 3. Add `top_topics` to FIELD GUIDANCE
```
- top_topics: 5-7 single lowercase words or short phrases. Real themes, emotions, or people from the month.
```

### 4. Remove `{top_topics_list}` from user prompt input
In the user prompt (§6), delete this line from HABITS & STATISTICS:
```
- Top topics: {top_topics_list}
```

---

## Part 3 — DB Deployment Steps

1. Insert `monthly_analysis_v3` row with `is_active = false`
2. Verify insert and spot-check the prompt text
3. Set `monthly_analysis_v2` → `is_active = false`
4. Set `monthly_analysis_v3` → `is_active = true`
5. Deploy updated edge function

---

## Summary Table

| What | Where | Action |
|------|-------|--------|
| Remove `extractTopics()` call | `index.ts` line 130 | Delete line |
| Remove `{top_topics_list}` replace | `index.ts` line 322 | Delete line |
| Parse `top_topics` from AI | `index.ts` ~line 375 | Add parse + declare |
| Save AI `top_topics` to DB | `index.ts` line 429 | Update assignment |
| Add `top_topics` to schema | v3 system prompt | Add to OUTPUT FORMAT RULES |
| Update TOPICS RULE wording | v3 system prompt | Clarify as output field |
| Add `top_topics` to FIELD GUIDANCE | v3 system prompt | Add guidance line |
| Remove `{top_topics_list}` input | v3 user prompt | Delete line |

**No app-level changes needed.** `top_topics` is already `string[]` saved to the same column — only the data quality improves.

---

*Plan authored: March 22, 2026*
