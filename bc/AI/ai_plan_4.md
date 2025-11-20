# **AI ANALYSIS TRIGGER CONDITIONS**

## **📅 DAILY ANALYSIS (`ai-analyze-daily`)**

### **When It Gets Triggered:**
1. **Automatic trigger** (only way currently):
   - After user saves diary entry text
   - Location: `lib/services/entry_service.dart` line 104

### **Conditions Required:**
✅ **Flutter Side (EntryService):**
- Entry must sync successfully to Supabase
- Entry text length >= 50 characters
- User must be online (network check passes)

✅ **Edge Function Side (ai-analyze-daily):**
- Insight doesn't already exist for this entry (`status='success'`)
- Entry exists in database
- Entry belongs to the user (user_id matches)
- Entry text length >= 50 characters

### **Flow:**
```
User saves entry → Entry syncs → 
IF (sync success AND text >= 50 chars) → 
triggerDailyAnalysis(entryId) → 
Edge Function executes
```

---

## **📊 WEEKLY ANALYSIS (`ai-analyze-weekly`)**

### **When It Gets Triggered:**
1. **Manual trigger only** (currently):
   - Must be called explicitly: `AIService.triggerWeeklyAnalysis(userId, weekStart)`
   - **No automatic trigger exists yet**

### **Conditions Required:**
✅ **Flutter Side:**
- Must be called manually (no automatic trigger)
- Requires: `userId` and `weekStart` (DateTime)

✅ **Edge Function Side (ai-analyze-weekly):**
- Weekly insight doesn't already exist for that week (`status='success'`)
- At least 1 entry exists for that week
- Valid `user_id` and `week_start` provided

### **Flow:**
```
Manual call → triggerWeeklyAnalysis(userId, weekStart) → 
Edge Function executes
```

---

## **🚫 WHAT PREVENTS EXECUTION**

### **Daily Analysis Won't Run If:**
- ❌ Entry text < 50 characters
- ❌ Entry sync fails
- ❌ User is offline
- ❌ Insight already exists (deduplication)
- ❌ Entry not found in database
- ❌ User not authenticated

### **Weekly Analysis Won't Run If:**
- ❌ Not called manually (no automatic trigger)
- ❌ Weekly insight already exists for that week
- ❌ No entries found for that week
- ❌ Invalid user_id or week_start

---

## **💡 SUMMARY**

| Function | Trigger Type | Conditions |
|----------|-------------|------------|
| **Daily** | Automatic (after entry save) | Text >= 50 chars, sync success, online |
| **Weekly** | Manual only | Must call explicitly, week has entries |

---

**Note**: Weekly analysis has no automatic trigger. You need to add:
- Cron job (Supabase scheduled function)
- Background task (Flutter)
- Manual UI button
- Or trigger on specific events (e.g., Sunday night)

