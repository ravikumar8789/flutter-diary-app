# History Screen Backend Integration Plan

## 📋 Overview
Complete backend integration for History Screen with Riverpod state management, removing all mock data, and implementing real database queries.

---

## 🎯 Goals
1. ✅ Fetch entries + AI insights for current month on screen load
2. ✅ Implement pagination (load previous months on button click)
3. ✅ Update card display (remove emojis, show all stat chips)
4. ✅ Integrate Riverpod for state management
5. ✅ Remove all mock data
6. ✅ Optimize data fetching with proper joins

---

## 📊 Database Schema Mapping

### Tables Involved:
- `entries` - Main entry data (date, diary_text, mood_score, tags)
- `entry_insights` - AI insights (topics, sentiment, insight_text, insight_details)
- `entry_self_care` - 10 boolean fields (sleep, exercise, etc.)
- `entry_meals` - Meals (breakfast, lunch, dinner, water_cups)
- `entry_affirmations` - Affirmations array
- `entry_gratitude` - Gratitude items array

### Card Display → Database Fields:
| Card Element | Database Source | Calculation |
|-------------|----------------|-------------|
| Date | `entries.entry_date` | Direct |
| Diary Preview | `entries.diary_text` | First 100 chars |
| Word Count | `entries.diary_text` | Split by space, count |
| Self-Care | `entry_self_care` | Count `true` values (X/10) |
| Water Cups | `entry_meals.water_cups` | Direct (X cups) |
| Meals | `entry_meals` | Count non-null (breakfast, lunch, dinner) → X/3 |
| Tags | `entry_insights.topics` | Array field |
| Mood | `entries.mood_score` | Direct (1-5) |
| Sentiment | `entry_insights.sentiment_label` | Direct |
| Has Insights | `entry_insights.status = 'success'` | Boolean check |

---

## 🏗️ Architecture

### 1. Service Layer

#### New Service: `HistoryService`
**Location:** `lib/services/history_service.dart`

**Responsibilities:**
- Fetch entries for date range (with pagination)
- Fetch related data (insights, self-care, meals, etc.)
- Combine data into unified format
- Handle offline-first approach

**Key Methods:**
```dart
class HistoryService {
  // Fetch entries for a month with all related data
  Future<List<HistoryEntry>> getEntriesForMonth(
    String userId,
    DateTime month, // First day of month
  ) async {
    // 1. Get date range for month
    // 2. Fetch entries from LocalEntryService.getEntriesInRange()
    // 3. Fetch insights from AIService (or local if available)
    // 4. Fetch related data (self-care, meals, etc.) in parallel
    // 5. Combine into HistoryEntry objects
  }

  // Fetch entry with full details (for bottom sheet)
  Future<HistoryEntry?> getEntryByDate(
    String userId,
    DateTime date,
  ) async {
    // Similar to EntryService.loadEntryForDate but returns HistoryEntry
  }
}
```

#### Data Model: `HistoryEntry`
**Location:** `lib/models/history_entry_model.dart`

**Structure:**
```dart
class HistoryEntry {
  final Entry entry;
  final DailyInsight? insight; // From entry_insights
  final EntrySelfCare? selfCare;
  final EntryMeals? meals;
  final EntryAffirmations? affirmations;
  final EntryGratitude? gratitude;
  
  // Computed properties for card display
  int get wordCount => entry.diaryText?.split(' ').length ?? 0;
  int get selfCareCount => _countSelfCare();
  int get mealsCount => _countMeals();
  List<String> get tags => insight?.topics ?? [];
  bool get hasInsights => insight != null;
  String get sentiment => insight?.sentimentLabel ?? 'neutral';
  String get preview => _generatePreview();
  
  // Helper methods
  int _countSelfCare() {
    if (selfCare == null) return 0;
    int count = 0;
    if (selfCare!.sleep == true) count++;
    if (selfCare!.exercise == true) count++;
    if (selfCare!.freshAir == true) count++;
    if (selfCare!.learnNew == true) count++;
    if (selfCare!.balancedDiet == true) count++;
    if (selfCare!.podcast == true) count++;
    if (selfCare!.meMoment == true) count++;
    if (selfCare!.hydrated == true) count++;
    if (selfCare!.readBook == true) count++;
    if (selfCare!.getUpEarly == true) count++;
    return count;
  }
  
  int _countMeals() {
    if (meals == null) return 0;
    int count = 0;
    if (meals!.breakfast?.isNotEmpty == true) count++;
    if (meals!.lunch?.isNotEmpty == true) count++;
    if (meals!.dinner?.isNotEmpty == true) count++;
    return count;
  }
  
  String _generatePreview() {
    final text = entry.diaryText ?? '';
    if (text.length <= 100) return text;
    return text.substring(0, 100) + '...';
  }
}
```

---

### 2. Riverpod Provider

#### New Provider: `HistoryProvider`
**Location:** `lib/providers/history_provider.dart`

**State:**
```dart
class HistoryState {
  final List<HistoryEntry> entries; // All loaded entries
  final Set<String> loadedMonths; // Track loaded months (e.g., "2024-01")
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final Map<String, int> moodMap; // Optimized lookup: date -> mood
  
  HistoryState({
    this.entries = const [],
    this.loadedMonths = const {},
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    Map<String, int>? moodMap,
  }) : moodMap = moodMap ?? {};
  
  HistoryState copyWith({...}) { ... }
}
```

**Notifier:**
```dart
class HistoryNotifier extends Notifier<HistoryState> {
  final HistoryService _service = HistoryService();
  
  @override
  HistoryState build() => HistoryState();
  
  // Load current month on init
  Future<void> loadCurrentMonth() async {
    final userId = _getUserId();
    if (userId == null) return;
    
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final now = DateTime.now();
      final month = DateTime(now.year, now.month, 1);
      final entries = await _service.getEntriesForMonth(userId, month);
      
      final monthKey = DateFormat('yyyy-MM').format(month);
      final moodMap = _buildMoodMap(entries);
      
      state = state.copyWith(
        entries: entries,
        loadedMonths: {monthKey},
        isLoading: false,
        moodMap: moodMap,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load entries: $e',
      );
    }
  }
  
  // Load previous month (pagination)
  Future<void> loadPreviousMonth(String monthKey) async {
    final userId = _getUserId();
    if (userId == null) return;
    
    // Parse monthKey (e.g., "2024-01")
    final parts = monthKey.split('-');
    final month = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
    
    state = state.copyWith(isLoadingMore: true);
    
    try {
      final entries = await _service.getEntriesForMonth(userId, month);
      final newMoodMap = _buildMoodMap(entries);
      
      state = state.copyWith(
        entries: [...state.entries, ...entries],
        loadedMonths: {...state.loadedMonths, monthKey},
        isLoadingMore: false,
        moodMap: {...state.moodMap, ...newMoodMap},
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: 'Failed to load month: $e',
      );
    }
  }
  
  // Refresh current month
  Future<void> refresh() async {
    await loadCurrentMonth();
  }
  
  // Get entry by date (for calendar tap)
  Future<HistoryEntry?> getEntryByDate(DateTime date) async {
    final userId = _getUserId();
    if (userId == null) return null;
    return await _service.getEntryByDate(userId, date);
  }
  
  // Helper: Build mood map for calendar
  Map<String, int> _buildMoodMap(List<HistoryEntry> entries) {
    final map = <String, int>{};
    for (var entry in entries) {
      if (entry.entry.moodScore != null) {
        final dateStr = DateFormat('yyyy-MM-dd').format(entry.entry.entryDate);
        map[dateStr] = entry.entry.moodScore!;
      }
    }
    return map;
  }
  
  String? _getUserId() {
    return Supabase.instance.client.auth.currentUser?.id;
  }
}

final historyProvider = NotifierProvider<HistoryNotifier, HistoryState>(
  () => HistoryNotifier(),
);
```

---

### 3. Complete Data Structure & Flow

#### 3.1 HistoryEntry Model - Complete Structure

```dart
class HistoryEntry {
  // Core Data
  final Entry entry;                    // From entries table
  final DailyInsight? insight;          // From entry_insights table
  final EntrySelfCare? selfCare;        // From entry_self_care table
  final EntryMeals? meals;              // From entry_meals table
  final EntryAffirmations? affirmations; // From entry_affirmations table
  final EntryGratitude? gratitude;      // From entry_gratitude table
  final EntryPriorities? priorities;    // From entry_priorities table
  final EntryTomorrowNotes? tomorrowNotes; // From entry_tomorrow_notes table
  
  // Computed Properties (for Card Display)
  int get wordCount => entry.diaryText?.split(' ').length ?? 0;
  int get selfCareCount => _countSelfCare();
  int get mealsCount => _countMeals();
  List<String> get tags => insight?.topics ?? [];
  bool get hasInsights => insight != null && insight!.status == 'success';
  String get sentiment => insight?.sentimentLabel ?? 'neutral';
  String get preview => _generatePreview();
  
  // Helper Methods
  int _countSelfCare() { /* Count 10 boolean fields */ }
  int _countMeals() { /* Count non-null meals */ }
  String _generatePreview() { /* First 100 chars */ }
}
```

#### 3.2 DailyInsight Model - Structure

```dart
class DailyInsight {
  final String id;
  final String entryId;
  final String? insightText;           // entry_insights.insight_text
  final String? sentimentLabel;        // entry_insights.sentiment_label
  final List<String> topics;            // entry_insights.topics
  final InsightDetails? insightDetails; // entry_insights.insight_details (JSONB)
  final DateTime processedAt;
  final String status;                  // 'success', 'pending', 'error'
}

class InsightDetails {
  final String? whatWentWell;           // insight_details->what_went_well
  final String? progressArea;           // insight_details->progress_area
  final String? selfCareBalance;        // insight_details->self_care_balance
  final String? emotionalPattern;       // insight_details->emotional_pattern
  // ❌ NO keyTakeaways (removed)
  // ❌ NO actionItems (removed)
}
```

#### 3.3 Data Fetching Flow

```
User Opens History Screen
    ↓
Provider.loadCurrentMonth()
    ↓
HistoryService.getEntriesForMonth()
    ↓
1. LocalEntryService.getEntriesInRange() → List<Entry>
2. AIService.getDailyInsightsTimeline() → List<DailyInsight>
3. For each Entry:
   - LocalEntryService.getSelfCare(entryId)
   - LocalEntryService.getMeals(entryId)
   - LocalEntryService.getAffirmations(entryId)
   - LocalEntryService.getGratitude(entryId)
   - LocalEntryService.getPriorities(entryId)
   - LocalEntryService.getTomorrowNotes(entryId)
    ↓
Combine into List<HistoryEntry>
    ↓
Update Provider State
    ↓
UI Rebuilds with Real Data
```

---

### 3.4 Service Implementation Details

#### `HistoryService.getEntriesForMonth()`
**Flow:**
1. Calculate month start/end dates
2. Fetch entries: `LocalEntryService.getEntriesInRange(userId, start, end)`
3. Fetch insights in parallel: `AIService.getDailyInsightsTimeline(userId, start, end)`
4. For each entry:
   - Fetch self-care: `LocalEntryService.getSelfCare(entryId)`
   - Fetch meals: `LocalEntryService.getMeals(entryId)`
   - Fetch affirmations: `LocalEntryService.getAffirmations(entryId)`
   - Fetch gratitude: `LocalEntryService.getGratitude(entryId)`
5. Combine into `HistoryEntry` objects
6. Return sorted by date (newest first)

**Optimization:**
- Use `Future.wait()` for parallel fetching
- Batch fetch related data where possible
- Cache insights map by entry_id for quick lookup

---

### 4. UI Updates

#### 4.1 History Screen (List View) - Card Display

**File:** `lib/screens/history_screen.dart`

**Card Structure:**
```
┌─────────────────────────────────┐
│ Date (EEEE, MMMM d, y)         │
│ [AI Badge] [Mood Icon]          │
├─────────────────────────────────┤
│ Diary Preview (2 lines)        │
├─────────────────────────────────┤
│ [Word Count] [Self-Care X/10]   │
│ [Water X cups] [Meals X/3]      │
├─────────────────────────────────┤
│ [Tag1] [Tag2] [Tag3]            │
└─────────────────────────────────┘
```

**Card Data Mapping:**
| Element | Database Source | Display Logic |
|---------|----------------|---------------|
| Date | `entries.entry_date` | Format: "EEEE, MMMM d, y" |
| AI Badge | `entry_insights.status = 'success'` | Show if insight exists |
| Mood Icon | `entries.mood_score` | 1-5, colored circle with icon |
| Diary Preview | `entries.diary_text` | First 100 chars, 2 lines max |
| Word Count | `entries.diary_text` | Count words, always show |
| Self-Care | `entry_self_care` | Count true values, show "X/10" (always) |
| Water Cups | `entry_meals.water_cups` | Show "X cups" (always, even 0) |
| Meals | `entry_meals` | Count non-null meals, show "X/3" (always) |
| Tags | `entry_insights.topics` | Array, show if available, empty if not |

**Changes Required:**
1. ✅ Remove "Edited" text from card (keep in metadata only)
2. ✅ Remove emoji completion indicators
3. ✅ Show ALL stat chips (even if 0):
   - Word count: Always show
   - Self-care: Always show "X/10" (even if 0/10)
   - Water cups: Always show "X cups" (even if 0)
   - Meals: Always show "X/3" (even if 0/3)
4. ✅ Tags: Show from `entry_insights.topics` (fallback to empty if not available)

---

#### 4.2 Bottom Sheet - Entry Detail View

**File:** `lib/screens/history_screen.dart` - `_showEntryDetail()` method

**Bottom Sheet Structure:**
```
┌─────────────────────────────────┐
│ [Drag Handle]                   │
├─────────────────────────────────┤
│ Date (EEEE, MMMM d, y)          │
│ [Mood Icon]                     │
├─────────────────────────────────┤
│ 📖 Diary Entry                  │
│ [Full Diary Text]               │
├─────────────────────────────────┤
│ ✨ AI Insights (if available)    │
│ ┌─────────────────────────────┐ │
│ │ AI Insights [Sentiment Badge]│ │
│ │ [Insight Text]              │ │
│ │ • What Went Well            │ │
│ │ • Progress Area             │ │
│ │ • Self-Care Balance         │ │
│ │ • Emotional Pattern         │ │
│ │ Topics: [Tag1] [Tag2]       │ │
│ └─────────────────────────────┘ │
├─────────────────────────────────┤
│ 💜 Affirmations                 │
│ [List of affirmations or empty] │
├─────────────────────────────────┤
│ ❤️ Gratitude                    │
│ [List of gratitude items]       │
├─────────────────────────────────┤
│ 🎯 Priorities                   │
│ [List of priorities]             │
├─────────────────────────────────┤
│ 🍽️ Meals                        │
│ Breakfast: [text]               │
│ Lunch: [text]                   │
│ Dinner: [text]                  │
│ Water: X cups                   │
├─────────────────────────────────┤
│ 🧘 Self-Care                    │
│ [Chips for each activity]       │
├─────────────────────────────────┤
│ 📝 Tomorrow's Notes             │
│ [List of notes]                 │
├─────────────────────────────────┤
│ 📋 Metadata                     │
│ Created: [timestamp]            │
│ Updated: [timestamp]            │
│ Source: [mobile/web/import]     │
└─────────────────────────────────┘
```

**Bottom Sheet Data Mapping:**

| Section | Database Source | Display Logic |
|---------|----------------|---------------|
| **Header** | | |
| Date | `entries.entry_date` | Format: "EEEE, MMMM d, y" |
| Mood Icon | `entries.mood_score` | Colored circle with icon (1-5) |
| **Diary Entry** | | |
| Full Text | `entries.diary_text` | Complete text, no truncation |
| **AI Insights** (if available) | | |
| Insight Text | `entry_insights.insight_text` | Main AI-generated insight |
| Sentiment Badge | `entry_insights.sentiment_label` | Positive/Neutral/Negative |
| What Went Well | `entry_insights.insight_details->what_went_well` | From JSONB |
| Progress Area | `entry_insights.insight_details->progress_area` | From JSONB |
| Self-Care Balance | `entry_insights.insight_details->self_care_balance` | From JSONB |
| Emotional Pattern | `entry_insights.insight_details->emotional_pattern` | From JSONB |
| Topics | `entry_insights.topics` | Array of strings, show as chips |
| **Affirmations** | | |
| List | `entry_affirmations.affirmations` | JSONB array, show list or empty state |
| **Gratitude** | | |
| List | `entry_gratitude.grateful_items` | JSONB array, show list or empty state |
| **Priorities** | | |
| List | `entry_priorities.priorities` | JSONB array, show list |
| **Meals** | | |
| Breakfast | `entry_meals.breakfast` | Show if not null |
| Lunch | `entry_meals.lunch` | Show if not null |
| Dinner | `entry_meals.dinner` | Show if not null |
| Water Cups | `entry_meals.water_cups` | Show count |
| **Self-Care** | | |
| Activities | `entry_self_care` | Show chips for each true value (10 fields) |
| **Tomorrow Notes** | | |
| List | `entry_tomorrow_notes.tomorrow_notes` | JSONB array, show list or empty state |
| **Metadata** | | |
| Created At | `entries.created_at` | Format: "MMM d, y 'at' h:mm a" |
| Updated At | `entries.updated_at` | Format: "MMM d, y 'at' h:mm a" |
| Source | `entries.source` | mobile/web/import |

**Important Notes:**
- ❌ **REMOVED:** Key Takeaways section (not in database)
- ❌ **REMOVED:** Action Items section (not in database)
- ❌ **REMOVED:** "Edited" text from header (show in metadata only)
- ✅ **AI Insights Container:** Only shows if `entry_insights.status = 'success'`
- ✅ **Empty States:** Show motivational messages for empty sections (Affirmations, Gratitude, Tomorrow Notes)
- ✅ **Self-Care Chips:** Show all 10 activities as chips (checked/unchecked)

---

### 5. Integration Steps

#### Step 1: Create Models
- [ ] Create `lib/models/history_entry_model.dart`
- [ ] Add `HistoryEntry` class with computed properties
- [ ] Add helper methods for calculations

#### Step 2: Create Service
- [ ] Create `lib/services/history_service.dart`
- [ ] Implement `getEntriesForMonth()`
- [ ] Implement `getEntryByDate()`
- [ ] Add error handling and logging

#### Step 3: Create Provider
- [ ] Create `lib/providers/history_provider.dart`
- [ ] Implement `HistoryState` class
- [ ] Implement `HistoryNotifier` class
- [ ] Add pagination logic
- [ ] Add mood map building

#### Step 4: Update History Screen
- [ ] Replace `StatefulWidget` with `ConsumerWidget`
- [ ] Remove all mock data generation
- [ ] Remove `_allMockEntries`, `_entryMap`, `_moodMap` (use provider)
- [ ] Update `initState` to call `historyProvider.loadCurrentMonth()`
- [ ] Update `_buildEntryCard` to use `HistoryEntry` model
- [ ] Update stat chips to always show (remove `if` conditions)
- [ ] Remove emoji completion indicators
- [ ] Remove "Edited" text from card header
- [ ] Update `_getEntryByDate` to use provider
- [ ] Update `_getMoodByDate` to use provider's moodMap
- [ ] Update pagination button to call `historyProvider.loadPreviousMonth()`

#### Step 4.1: Update Bottom Sheet
- [ ] Remove "Edited" text from bottom sheet header
- [ ] Update `_showEntryDetail` to use `HistoryEntry` model
- [ ] Update `_buildEnhancedInsightsSection`:
  - [ ] Remove Key Takeaways section
  - [ ] Remove Action Items section
  - [ ] Keep only: Insight Text, 4 structured details, Topics
- [ ] Update all section builders to use real data:
  - [ ] `_buildAffirmationsSection` - use `entry.affirmations`
  - [ ] `_buildGratitudeSection` - use `entry.gratitude`
  - [ ] `_buildPrioritiesSection` - use `entry.priorities`
  - [ ] `_buildMealsSection` - use `entry.meals`
  - [ ] `_buildSelfCareSection` - use `entry.selfCare`
  - [ ] `_buildTomorrowNotesSection` - use `entry.tomorrowNotes`
  - [ ] `_buildMetadataSection` - use `entry.entry` (created_at, updated_at, source)

#### Step 5: Update Calendar View
- [ ] Use `historyProvider.state.moodMap` for mood indicators
- [ ] Update `_handleDateTap` to use `historyProvider.getEntryByDate()`

#### Step 6: Testing
- [ ] Test current month loading
- [ ] Test pagination (load previous months)
- [ ] Test calendar date tap
- [ ] Test empty states
- [ ] Test offline behavior
- [ ] Test error handling

---

### 6. Data Fetching Strategy

#### Current Month (Initial Load)
```
1. User opens History Screen
2. Provider calls loadCurrentMonth()
3. Service fetches:
   - Entries for current month (LocalEntryService)
   - Insights for current month (AIService or local)
   - Related data for each entry (parallel)
4. Combine into HistoryEntry objects
5. Update provider state
6. UI rebuilds with real data
```

#### Previous Month (Pagination)
```
1. User clicks "Load [Month Name]" button
2. Provider calls loadPreviousMonth(monthKey)
3. Service fetches:
   - Entries for that month
   - Insights for that month
   - Related data (parallel)
4. Append to existing entries
5. Update loadedMonths set
6. Update moodMap
7. UI rebuilds with additional entries
```

---

### 7. Error Handling

#### Service Level
- Try local first (offline support)
- If online, sync and fetch from cloud
- Log errors to ErrorLoggingService
- Return empty list on failure (don't crash)

#### Provider Level
- Set error state on failure
- Show error message in UI
- Allow retry functionality
- Clear error on successful load

#### UI Level
- Show loading indicators
- Show error messages
- Show empty states when no data
- Handle null values gracefully

---

### 8. Performance Optimizations

#### Already Implemented:
- ✅ O(1) mood lookup map
- ✅ Optimized entry lookup map
- ✅ ListView.builder for lazy rendering

#### Additional:
- ✅ Batch fetch related data (Future.wait)
- ✅ Cache insights by entry_id
- ✅ Only fetch data for loaded months
- ✅ Use const constructors where possible

---

### 9. Code Cleanup

#### Remove:
- [ ] `_generateMockEntries()` method
- [ ] `_generateDiaryText()` method
- [ ] `_generateTags()` method
- [ ] `_allMockEntries` variable
- [ ] All mock data initialization
- [ ] `_loadedMonths` local state (use provider)

#### Keep:
- ✅ `_buildEntryCard()` (update to use HistoryEntry)
- ✅ `_buildStatChip()` (update to always show)
- ✅ `_buildCalendarView()` (update to use provider)
- ✅ `_showEntryDetail()` (update to use HistoryEntry)
- ✅ All UI helper methods

---

### 10. Bottom Sheet Implementation Details

#### 10.1 AI Insights Section Structure

**Location:** `_buildEnhancedInsightsSection()` method

**Current Structure (to be updated):**
```dart
Widget _buildEnhancedInsightsSection(Map insights) {
  return Container(
    // Purple gradient background
    child: Column(
      children: [
        // Header: "AI Insights" + Sentiment Badge
        // Main Insight Text
        // 4 Structured Details:
        //   - What Went Well
        //   - Progress Area
        //   - Self-Care Balance
        //   - Emotional Pattern
        // Topics (as chips)
        // ❌ REMOVE: Key Takeaways
        // ❌ REMOVE: Action Items
      ],
    ),
  );
}
```

**Data Source:**
- `insights['insightText']` → `entry_insights.insight_text`
- `insights['sentimentLabel']` → `entry_insights.sentiment_label`
- `insights['insightDetails']` → `entry_insights.insight_details` (JSONB)
- `insights['topics']` → `entry_insights.topics` (array)

#### 10.2 Empty States for Bottom Sheet

**Sections with Empty States:**
1. **Affirmations** - "Start your day with positive affirmations..."
2. **Gratitude** - "Reflect on what you're grateful for today..."
3. **Tomorrow Notes** - "Plan ahead for tomorrow..."
4. **Meals** - Show only filled meals (breakfast/lunch/dinner)
5. **Self-Care** - Show all 10 activities as chips (checked/unchecked)

**Implementation:**
```dart
Widget _buildEmptySection(String title, String message, IconData icon) {
  return Container(
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Icon(icon, size: 48, color: Colors.grey.shade400),
        SizedBox(height: 12),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}
```

---

### 11. Tag Filtering (Future Discussion)

**Current Implementation:**
- Fixed tags in filter bar: `['Work', 'Family', 'Health', 'Goals', 'Growth', 'Challenge', 'Mindfulness', 'Connection', 'Self-Care', 'Reflection']`

**Options:**
1. **Keep Fixed Tags** (Current)
   - Pros: Clean UI, consistent
   - Cons: May not match user's actual tags

2. **Dynamic Tags from Insights**
   - Fetch all unique topics from `entry_insights.topics`
   - Show top 10 most used tags
   - Pros: Matches actual data
   - Cons: Can be cluttered, changes frequently

3. **Hybrid Approach**
   - Show fixed tags + most popular user tags
   - Limit to 10-12 total
   - Pros: Balance of consistency and relevance

**Decision:** To be discussed after backend integration is complete.

---

## 📝 Implementation Checklist

### Phase 1: Foundation
- [ ] Create `HistoryEntry` model
- [ ] Create `HistoryService`
- [ ] Create `HistoryProvider`
- [ ] Test service methods

### Phase 2: Integration
- [ ] Update History Screen to use provider
- [ ] Remove mock data
- [ ] Update card display
- [ ] Update bottom sheet structure
- [ ] Remove Key Takeaways and Action Items from bottom sheet
- [ ] Update all section builders with real data
- [ ] Update calendar view
- [ ] Test current month loading

### Phase 3: Pagination
- [ ] Implement load previous month
- [ ] Update pagination button
- [ ] Test month-by-month loading
- [ ] Test mood map updates

### Phase 4: Polish
- [ ] Error handling
- [ ] Loading states
- [ ] Empty states
- [ ] Performance testing
- [ ] Code cleanup

---

## 🔄 Migration Path

1. **Keep mock data initially** - Add provider alongside existing code
2. **Test provider** - Ensure it works with real data
3. **Gradually replace** - Update one section at a time
4. **Remove mock data** - Once everything is working
5. **Clean up** - Remove unused code

---

## 📌 Notes

- **Offline Support:** Always try local first, sync in background
- **Error Recovery:** Show errors but don't block UI
- **Performance:** Batch operations, use parallel fetching
- **User Experience:** Show loading states, handle empty data gracefully
- **Testing:** Test with real data, test offline, test errors

---

## ✅ Success Criteria

### History Screen (List View)
1. ✅ History screen loads current month entries on open
2. ✅ Pagination loads previous months correctly
3. ✅ Cards display all data correctly (no mock data)
4. ✅ All stat chips show (even if 0)
5. ✅ No emoji completion indicators
6. ✅ No "Edited" text on cards
7. ✅ Tags show from insights (with fallback)
8. ✅ Calendar shows mood indicators from real data

### Bottom Sheet (Entry Detail)
9. ✅ Date tap shows entry detail from database
10. ✅ Bottom sheet shows all user data sections
11. ✅ AI Insights section shows only available data:
    - ✅ Insight Text
    - ✅ 4 Structured Details (What Went Well, Progress Area, Self-Care Balance, Emotional Pattern)
    - ✅ Topics
    - ❌ NO Key Takeaways
    - ❌ NO Action Items
12. ✅ Empty states show motivational messages
13. ✅ Metadata shows created/updated/source
14. ✅ No "Edited" text in header (only in metadata)

### Performance & Reliability
15. ✅ Performance is acceptable (< 2s load time)
16. ✅ Works offline (local data first)
17. ✅ Error handling works correctly
18. ✅ Loading states display properly

---

**Next Steps:** Review this plan, discuss tag filtering approach, then start implementation.

