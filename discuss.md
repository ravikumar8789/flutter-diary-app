## `populate-analysis-queue` function — complete workflow

### Step 1: Initialize
- Creates Supabase client
- No API calls

### Step 2: Get all users

> here why we are fetching all users, we have to make something ike that we have to fetch timezone of only those users whole data has to be queued or if we store all things in signle table we will reduce the calls.

### Step 3: Loop through each user

#### For each user:

**3.1 Get today's date in user timezone**
> i think this we have to do bcz we have to fetch users timezone.


**3.2 Get today's entry**
- Query: `SELECT id, diary_text, entry_date FROM entries WHERE user_id = ? AND entry_date = ?`
- API call: 1 GET request
- Result: Today's entry (if exists)


**3.3 If today's entry exists:**
- **3.3.1 Check entry completion**

  if w are doing that every 5 min we are catching the new entries we dont have to do this i think

- **3.3.2 If complete:**
  - **3.3.2.1 Check if insight exists**
    - Query: `SELECT id FROM entry_insights WHERE entry_id = ? AND status = 'success'`
    - API call: 1 GET request
    - Result: Insight exists or null

  - **3.3.2.2 Check if already queued**
    - Query: `SELECT id FROM analysis_queue WHERE user_id = ? AND analysis_type = 'daily' AND target_date = ? AND status IN ('pending', 'processing')`
    - API call: 1 GET request
    - Result: Already queued or null

  - **3.3.2.3 If not queued and no insight:**
    - **Calculate tomorrow midnight**
      - RPC call: `get_date_in_timezone(p_timezone, p_offset_days: 1)` (tomorrow)
      - API call: 1 POST request
      - JavaScript calculation for timezone offset
      - Result: ISO timestamp for tomorrow midnight UTC

    - **Insert into queue**
      - Query: `INSERT INTO analysis_queue (user_id, analysis_type, target_date, entry_id, status, next_retry_at)`
      - API call: 1 POST request

**3.4 Catch-up analysis (30-day scan)**
- Query: `SELECT id, entry_date, diary_text FROM entries WHERE user_id = ? AND entry_date < ? AND entry_date >= ? AND diary_text IS NOT NULL AND diary_text != ''`
- API call: 1 GET request
- Result: List of unanalyzed entries (last 30 days)

**3.5 For each unanalyzed entry:**
- **3.5.1 Check if insight exists**
  - Query: `SELECT id FROM entry_insights WHERE entry_id = ? AND status = 'success'`
  - API call: 1 GET request

- **3.5.2 Check if already queued**
  - Query: `SELECT id FROM analysis_queue WHERE user_id = ? AND analysis_type = 'daily' AND target_date = ? AND status IN ('pending', 'processing')`
  - API call: 1 GET request

- **3.5.3 Check entry completion**
  - RPC call: `check_entry_completion(entry_uuid)`
  - API call: 1 POST request

- **3.5.4 If all checks pass:**
  - **Calculate tomorrow midnight** (same as 3.3.2.3)
    - RPC call: 1 POST request
  - **Insert into queue**
    - Query: 1 POST request

**3.6 Weekly check (if Sunday midnight)**
- Check: `dayOfWeek === 0 && currentHour === 0`
- If true:
  - **3.6.1 Check if weekly insight exists**
    - Query: `SELECT id FROM weekly_insights WHERE user_id = ? AND week_start = ?`
    - API call: 1 GET request

  - **3.6.2 Check if weekly queued**
    - Query: `SELECT id FROM analysis_queue WHERE user_id = ? AND analysis_type = 'weekly' AND week_start = ? AND status IN ('pending', 'processing')`
    - API call: 1 GET request

  - **3.6.3 Count entries for week**
    - Query: `SELECT COUNT(id) FROM entries WHERE user_id = ? AND entry_date >= ? AND entry_date <= ?`
    - API call: 1 GET request

  - **3.6.4 If all checks pass:**
    - Calculate tomorrow midnight: 1 RPC call
    - Insert weekly job: 1 POST request

**3.7 Monthly check (if 1st of month)**
- Check: `getDate() === 1 && currentHour === 0`
- If true:
  - Similar to weekly (3 checks + insert)
  - API calls: 4 requests

### Step 4: Return summary
- Returns JSON with counts
- No API calls

---

## Total API calls calculation

### Per user (worst case):
- Base: 1 (timezone RPC)
- Today's entry: 1 (get entry)
- Today's checks: 1 (completion) + 1 (insight) + 1 (queue) = 3
- Tomorrow calculation: 1 (RPC)
- Insert: 1
- 30-day scan: 1 (get entries)
- Per unanalyzed entry (5 entries): 5 × (1 insight + 1 queue + 1 completion + 1 tomorrow + 1 insert) = 25
- Weekly (if Sunday): 4
- Monthly (if 1st): 4

**Total per user: 1 + 1 + 3 + 1 + 1 + 1 + 25 + 4 + 4 = 41 requests**

### For 8 users:
- Get users: 1
- Per user: 8 × 41 = 328
- **Total: 329 requests per run**

### Per hour (12 runs):
- **329 × 12 = 3,948 requests/hour**

---

## Main issues
1. Too many queries per user (41+)
2. RPC calls repeated (timezone, completion)
3. 30-day scan processes each entry individually
4. No caching (same calculations repeated)
5. No batching (queries run one by one)

This is why you see 940+ requests/hour.