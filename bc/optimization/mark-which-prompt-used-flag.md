## Daily Prompt Source Flag - Implementation Plan (Brief)

### Goal
Store which prompt source was used in `entry_insights.model_version`:
- `gpt-4o-mini||table`
- `gpt-4o-mini||hardcode`

### Current (daily)
`model_version` is always saved as `gpt-4o-mini`.

### Changes Needed (Daily Function)
1. **Add a flag** before OpenAI call:
   - `let promptSource = 'hardcode'`
2. **Set flag when table template is successfully applied**:
   - After successful template fetch + placeholder replacement, set `promptSource = 'table'`
3. **Use flag in save step**:
   - Change `model_version: 'gpt-4o-mini'` to:
     - `model_version: \`gpt-4o-mini||${promptSource}\``
4. **(Optional)** mirror to `ai_requests_log.model_used`:
   - `model_used: \`gpt-4o-mini||${promptSource}\``

### How It Detects Source
- If template fetch fails or apply fails → flag stays `hardcode`.
- Only set to `table` after:
  - template row exists, and
  - placeholders successfully replaced.

### Impact / Complexity
- **Minor change** (few lines).
- **No DB schema change**.
- **No app changes**.
