# **DAILY ANALYSIS REFINEMENT - IMPLEMENTATION PLAN**

## **OVERVIEW**

Enhance daily AI analysis to:
1. Pass **full text content** from all entry tables (not just flags)
2. Generate **structured insights** with main insight + 4 sub-points
3. Store in `insight_details` JSONB column
4. Display engaging, meaningful insights in Flutter UI

---

## **PHASE 1: DATABASE CHANGES**

### **1.1 Add `insight_details` Column**

**File:** Run in Supabase SQL Editor

**Query:**
```sql
ALTER TABLE public.entry_insights 
ADD COLUMN IF NOT EXISTS insight_details jsonb;
```

**Verification:**
```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'entry_insights' 
AND column_name = 'insight_details';
```

**Expected Result:** Should return 1 row with `insight_details` (type: `jsonb`)

---

## **PHASE 2: EDGE FUNCTION CHANGES**

### **2.1 Update `ai-analyze-daily` Function**

**File:** `supabase/functions/ai-analyze-daily/index.ts`

**Current Code Reference:**
- Lines 101-130: Fetches related data (self-care, affirmations, priorities, meals, gratitude)
- Lines 173-183: Only uses flags/counts, not actual text
- Lines 193-212: Prompt only includes summaries, not full text
- Lines 256-273: Saves only `insight_text` and `summary`

**Changes Required:**

#### **2.1.1 Fetch Full Text Content**

**Location:** After line 130 (after fetching gratitude)

**Add:**
```typescript
// Fetch tomorrow notes
const { data: tomorrowNotes } = await supabase
  .from('entry_tomorrow_notes')
  .select('tomorrow_notes')
  .eq('entry_id', entry_id)
  .single()

// Fetch shower/bath notes
const { data: showerBath } = await supabase
  .from('entry_shower_bath')
  .select('took_shower, note')
  .eq('entry_id', entry_id)
  .single()
```

#### **2.1.2 Build Full Context String**

**Location:** Replace lines 158-188 (context building section)

**New Code:**
```typescript
// Build comprehensive context with ALL actual text content
const affirmationsText = affirmations?.affirmations 
  ? JSON.stringify(affirmations.affirmations).replace(/[\[\]"]/g, '')
  : 'None'

const prioritiesText = priorities?.priorities
  ? JSON.stringify(priorities.priorities).replace(/[\[\]"]/g, '')
  : 'None'

const gratitudeText = gratitude?.grateful_items
  ? JSON.stringify(gratitude.grateful_items).replace(/[\[\]"]/g, '')
  : 'None'

const tomorrowNotesText = tomorrowNotes?.tomorrow_notes
  ? JSON.stringify(tomorrowNotes.tomorrow_notes).replace(/[\[\]"]/g, '')
  : 'None'

const selfCareDetails = selfCare ? Object.entries(selfCare)
  .filter(([key, value]) => value === true && key !== 'entry_id')
  .map(([key]) => key.replace(/_/g, ' '))
  .join(', ') : 'None'

const mealsDetails = meals 
  ? `Breakfast: ${meals.breakfast || 'Not logged'}, Lunch: ${meals.lunch || 'Not logged'}, Dinner: ${meals.dinner || 'Not logged'}, Water: ${meals.water_cups || 0} cups`
  : 'No meals logged'

const showerBathNote = showerBath?.note || 'None'
```

#### **2.1.3 Update Prompt to Include Full Text**

**Location:** Replace lines 190-212 (prompt building)

**New Code:**
```typescript
const systemPrompt = 'You are a compassionate and insightful AI wellness assistant. Analyze diary entries with emotional intelligence and provide thoughtful, comprehensive insights. Always be supportive and non-judgmental. Your task is to generate a structured insight with a main 3-4 sentence insight and 4 specific sub-points that help users understand their day better.'

const userPrompt = `Yesterday's Complete Entry Analysis:

**Main Diary Entry:**
"${entry.diary_text}"

**Mood:** ${entry.mood_score || 'N/A'}/5

**Morning Ritual:**
- Affirmations: ${affirmationsText}
- Priorities: ${prioritiesText}

**Wellness Tracking:**
- Self-care activities completed: ${selfCareDetails}
- Meals: ${mealsDetails}
- Shower/Bath: ${showerBath?.took_shower ? 'Yes' : 'No'}${showerBathNote !== 'None' ? ` (Note: ${showerBathNote})` : ''}

**Gratitude Practice:**
${gratitudeText}

**Tomorrow's Planning:**
${tomorrowNotesText}

**Past 5 Days Context:**
- Mood trend: ${moodTrend}
- Consistency: ${consistencyScore}%
- Entries completed: ${(pastEntries?.length || 0) + 1}/5
- Key patterns: ${keyPatterns}

Please provide a structured response in JSON format:
{
  "main_insight": "3-4 sentence comprehensive insight about the day (emotional tone, key patterns, supportive observation)",
  "what_went_well": "1-1.5 lines about one specific positive thing from the data",
  "progress_area": "1-1.5 lines about what's lacking and one actionable step to improve",
  "self_care_balance": "1-1.5 lines about self-care activities and what could be added",
  "emotional_pattern": "1-1.5 lines about emotional patterns observed from diary and mood"
}

Keep it warm, specific, and actionable. Each point should reference actual data from the entry.`
```

#### **2.1.4 Update OpenAI Call**

**Location:** Lines 214-230 (OpenAI API call)

**Change:**
```typescript
// Increase max_tokens for structured response
max_tokens: 500  // Changed from 200
```

#### **2.1.5 Parse Structured Response**

**Location:** After line 238 (after getting response)

**Replace lines 249-250:**
```typescript
// Parse structured JSON response
let insightData: any
try {
  insightData = JSON.parse(responseText)
} catch (e) {
  // Fallback: if not JSON, treat as main insight only
  insightData = {
    main_insight: responseText,
    what_went_well: null,
    progress_area: null,
    self_care_balance: null,
    emotional_pattern: null
  }
}

const insightText = insightData.main_insight || responseText.trim()
const insightDetails = {
  what_went_well: insightData.what_went_well || null,
  progress_area: insightData.progress_area || null,
  self_care_balance: insightData.self_care_balance || null,
  emotional_pattern: insightData.emotional_pattern || null
}
```

#### **2.1.6 Update Save to Database**

**Location:** Lines 256-273 (upsert statement)

**Change:**
```typescript
const { error: insightError, data: savedInsight } = await supabase
  .from('entry_insights')
  .upsert({
    entry_id: entry_id,
    insight_text: insightText,  // Main 3-4 sentence insight
    summary: insightText,  // Keep for backward compatibility
    insight_details: insightDetails,  // NEW: Structured sub-points
    ai_generated: true,
    analysis_type: 'daily',
    status: 'success',
    sentiment_label: inferSentiment(insightText, entry.mood_score),
    model_version: 'gpt-4o-mini',
    cost_tokens_prompt: tokensUsed.prompt,
    cost_tokens_completion: tokensUsed.completion,
    processed_at: new Date().toISOString()
  }, {
    onConflict: 'entry_id'
  })
  .select()
```

---

### **2.2 Deploy Edge Function**

**Command:**
```bash
cd supabase
supabase functions deploy ai-analyze-daily
```

**Verification:**
- Check Supabase Dashboard → Edge Functions → `ai-analyze-daily`
- Should show latest deployment timestamp

---

## **PHASE 3: FLUTTER MODEL CHANGES**

### **3.1 Update `DailyInsight` Model**

**File:** `lib/models/analytics_models.dart`

**Current Code Reference:**
- Lines 400-450: `DailyInsight` class definition

**Add New Field:**
```dart
class DailyInsight {
  final String id;
  final String entryId;
  final String insightText;
  final String? sentimentLabel;
  final DateTime processedAt;
  final InsightDetails? insightDetails;  // NEW

  DailyInsight({
    required this.id,
    required this.entryId,
    required this.insightText,
    this.sentimentLabel,
    required this.processedAt,
    this.insightDetails,  // NEW
  });

  factory DailyInsight.fromJson(Map<String, dynamic> json) {
    return DailyInsight(
      id: json['id'] as String,
      entryId: json['entry_id'] as String,
      insightText: json['summary'] as String? ?? json['insight_text'] as String? ?? '',
      sentimentLabel: json['sentiment_label'] as String?,
      processedAt: DateTime.parse(json['processed_at'] as String),
      insightDetails: json['insight_details'] != null
          ? InsightDetails.fromJson(json['insight_details'] as Map<String, dynamic>)
          : null,  // NEW
    );
  }
}
```

### **3.2 Create `InsightDetails` Model**

**File:** `lib/models/analytics_models.dart`

**Location:** Add after `DailyInsight` class (around line 450)

**New Code:**
```dart
/// Structured insight details from AI analysis
class InsightDetails {
  final String? whatWentWell;
  final String? progressArea;
  final String? selfCareBalance;
  final String? emotionalPattern;

  InsightDetails({
    this.whatWentWell,
    this.progressArea,
    this.selfCareBalance,
    this.emotionalPattern,
  });

  factory InsightDetails.fromJson(Map<String, dynamic> json) {
    return InsightDetails(
      whatWentWell: json['what_went_well'] as String?,
      progressArea: json['progress_area'] as String?,
      selfCareBalance: json['self_care_balance'] as String?,
      emotionalPattern: json['emotional_pattern'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'what_went_well': whatWentWell,
      'progress_area': progressArea,
      'self_care_balance': selfCareBalance,
      'emotional_pattern': emotionalPattern,
    };
  }

  bool get hasData => 
    whatWentWell != null || 
    progressArea != null || 
    selfCareBalance != null || 
    emotionalPattern != null;
}
```

### **3.3 Update `EntryInsights` Model**

**File:** `lib/models/analytics_models.dart`

**Current Code Reference:**
- Lines 1-72: `EntryInsights` class

**Add Field:**
```dart
class EntryInsights {
  // ... existing fields ...
  final Map<String, dynamic>? insightDetails;  // NEW

  EntryInsights({
    // ... existing parameters ...
    this.insightDetails,  // NEW
  });

  factory EntryInsights.fromJson(Map<String, dynamic> json) {
    return EntryInsights(
      // ... existing fields ...
      insightDetails: json['insight_details'] != null
          ? Map<String, dynamic>.from(json['insight_details'] as Map)
          : null,  // NEW
    );
  }
}
```

---

## **PHASE 4: FLUTTER SERVICE CHANGES**

### **4.1 Update `AIService.getYesterdayInsight()`**

**File:** `lib/services/ai_service.dart`

**Current Code Reference:**
- Lines 13-50: `getYesterdayInsight()` method

**Update SELECT Query:**
```dart
final response = await _supabase
  .from('entry_insights')
  .select('''
    id, 
    entry_id,
    summary, 
    insight_text,
    insight_details,  // NEW
    sentiment_label, 
    sentiment_score,
    topics,
    processed_at, 
    status,
    entries!inner(entry_date, user_id)
  ''')
  .eq('entries.user_id', userId)
  .eq('entries.entry_date', yesterdayStr)
  .eq('status', 'success')
  .maybeSingle();
```

**Update Return Statement:**
```dart
return DailyInsight(
  id: response['id'] as String,
  entryId: response['entry_id'] as String,
  insightText: response['summary'] as String? ?? response['insight_text'] as String? ?? '',
  sentimentLabel: response['sentiment_label'] as String?,
  processedAt: DateTime.parse(response['processed_at'] as String),
  insightDetails: response['insight_details'] != null
      ? InsightDetails.fromJson(response['insight_details'] as Map<String, dynamic>)
      : null,  // NEW
);
```

### **4.2 Update Other Methods (Optional - for consistency)**

**File:** `lib/services/ai_service.dart`

**Methods to Update:**
- `getRecentInsights()` (lines 176-219) - Add `insight_details` to SELECT
- `getDailyInsightsTimeline()` (lines 222-279) - Add `insight_details` to SELECT

**Pattern:** Add `insight_details` to SELECT query and parse in `fromJson` if needed

---

## **PHASE 5: FLUTTER UI CHANGES**

### **5.1 Update `YesterdayInsightScreen`**

**File:** `lib/screens/yesterday_insight_screen.dart`

**Current Code Reference:**
- Lines 100-196: Main content display

**Add Structured Details Display:**

**Location:** After main insight text (around line 120)

**New Code:**
```dart
// Main insight (existing)
Text(
  insight.insightText,
  style: Theme.of(context).textTheme.bodyLarge,
),

const SizedBox(height: 24),

// Structured details (NEW)
if (insight.insightDetails != null && insight.insightDetails!.hasData) ...[
  _buildDetailCard(
    context,
    icon: Icons.star,
    title: 'What went well',
    content: insight.insightDetails!.whatWentWell ?? '',
    color: Colors.green,
  ),
  const SizedBox(height: 12),
  _buildDetailCard(
    context,
    icon: Icons.trending_up,
    title: 'Progress area',
    content: insight.insightDetails!.progressArea ?? '',
    color: Colors.blue,
  ),
  const SizedBox(height: 12),
  _buildDetailCard(
    context,
    icon: Icons.favorite,
    title: 'Self-care balance',
    content: insight.insightDetails!.selfCareBalance ?? '',
    color: Colors.purple,
  ),
  const SizedBox(height: 12),
  _buildDetailCard(
    context,
    icon: Icons.psychology,
    title: 'Emotional pattern',
    content: insight.insightDetails!.emotionalPattern ?? '',
    color: Colors.orange,
  ),
],
```

**Add Helper Method:**

**Location:** At end of class (around line 190)

**New Code:**
```dart
Widget _buildDetailCard(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String content,
  required Color color,
}) {
  if (content.isEmpty) return const SizedBox.shrink();
  
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
```

### **5.2 Update `YesterdayInsightCard` (Home Screen)**

**File:** `lib/widgets/yesterday_insight_card.dart`

**Current Code Reference:**
- Displays preview on home screen

**Optional Enhancement:**
- Show first sub-point as preview if available
- Or keep current simple preview (main insight only)

**Recommendation:** Keep preview simple, full details on detail screen

---

## **PHASE 6: TESTING & VERIFICATION**

### **6.1 Database Verification**

**Query:**
```sql
SELECT 
  id,
  entry_id,
  insight_text,
  insight_details,
  status
FROM entry_insights
WHERE status = 'success'
ORDER BY processed_at DESC
LIMIT 5;
```

**Expected:** Should see `insight_details` JSONB with 4 fields

### **6.2 Edge Function Testing**

**Manual Test:**
```bash
# Trigger analysis for a test entry
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/ai-analyze-daily \
  -H "Authorization: Bearer YOUR_SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "entry_id": "TEST_ENTRY_ID",
    "user_id": "TEST_USER_ID"
  }'
```

**Check Logs:**
- Supabase Dashboard → Edge Functions → `ai-analyze-daily` → Logs
- Should see structured JSON in response

### **6.3 Flutter App Testing**

**Steps:**
1. Create a new entry with all sections filled
2. Wait for analysis (or trigger manually)
3. Check home screen - should show main insight
4. Tap to open detail screen - should show 4 sub-points
5. Verify all data is displayed correctly

---

## **PHASE 7: DEPLOYMENT ORDER**

### **Step 1: Database**
```sql
ALTER TABLE public.entry_insights 
ADD COLUMN IF NOT EXISTS insight_details jsonb;
```

### **Step 2: Edge Function**
```bash
cd supabase
supabase functions deploy ai-analyze-daily
```

### **Step 3: Flutter Models**
- Update `analytics_models.dart`
- Add `InsightDetails` class
- Update `DailyInsight` class

### **Step 4: Flutter Services**
- Update `ai_service.dart`
- Add `insight_details` to queries

### **Step 5: Flutter UI**
- Update `yesterday_insight_screen.dart`
- Add structured display

### **Step 6: Test**
- Create test entry
- Verify analysis works
- Check UI displays correctly

---

## **PHASE 8: ROLLBACK PLAN**

**If Issues Occur:**

1. **Database:** Column is nullable, won't break existing code
2. **Edge Function:** Revert to previous version
   ```bash
   supabase functions deploy ai-analyze-daily --version PREVIOUS_VERSION
   ```
3. **Flutter:** Code handles null `insightDetails` gracefully

---

## **SUMMARY**

**Files Modified:**
1. ✅ Database: Add `insight_details` column
2. ✅ `supabase/functions/ai-analyze-daily/index.ts` - Enhanced prompt + structured response
3. ✅ `lib/models/analytics_models.dart` - Add `InsightDetails` model
4. ✅ `lib/services/ai_service.dart` - Update queries
5. ✅ `lib/screens/yesterday_insight_screen.dart` - Display structured insights

**Key Changes:**
- Pass full text content to AI (not just flags)
- Generate structured JSON response
- Store in `insight_details` JSONB
- Display 4 engaging sub-points in UI

**Backward Compatibility:**
- ✅ Existing `insight_text` still works
- ✅ Null `insight_details` handled gracefully
- ✅ Old insights still display (just main insight)

---

## **END OF PLAN**

