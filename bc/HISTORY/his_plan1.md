# History Screen Enhancement Plan

## 📋 Overview
Plan to enhance the History Screen UI with static mock data. Backend integration will be added later.

---

## 🏷️ Tags Source & Fetching

### Where Tags Come From:
- **Database Table**: `entries` table
- **Column**: `tags` (PostgreSQL: `text[]` array, SQLite: JSON-encoded text)
- **Model**: `Entry.tags` (List<String>)

### How to Fetch Tags:
1. **From Local DB**: When fetching entries via `LocalEntryService.getEntriesInRange()`, tags are automatically included in the `Entry` object
2. **From Supabase**: Tags come as part of the entry JSON response from `entries` table
3. **Filter Tags**: Extract unique tags from all entries to populate filter chips dynamically

**Implementation Note**: For static data, we'll include tags in mock entries. Later, when connecting backend, tags will come from `Entry.tags` property.

---

## 🎨 UI Enhancements Plan

### 1. List View Enhancements

#### 1.1 Group by Month/Year
- **Implementation**: Group entries by month/year sections
- **UI**: Section headers like "December 2024", "January 2025"
- **Order**: Most recent first (descending)
- **Static Data**: Create mock entries spanning multiple months

#### 1.2 Word Count / Reading Time
- **Display**: Show word count badge on entry card
- **Calculation**: Count words in `diary_text`
- **Reading Time**: ~200 words/min (optional)
- **UI**: Small badge/chip showing "245 words" or "~1 min read"

#### 1.3 AI Insight Badge
- **Display**: Badge icon if entry has insights
- **Condition**: Show if `entry_insights` exists for entry
- **UI**: Small sparkle/AI icon badge
- **Color**: Theme primary color
- **Static Data**: Add `hasInsights: true/false` to mock entries

#### 1.4 Completion Indicators
- **Display**: Small icons showing what's completed
- **Items to Show**:
  - ✓ Affirmations (if affirmations exist)
  - ✓ Gratitude (if gratitude items exist)
  - ✓ Self-Care (count of completed self-care items)
- **UI**: Row of small icons/badges
- **Static Data**: Add completion flags to mock entries

#### 1.5 Attachments Indicator
- **Status**: Not needed (no attachment feature)

---

### 2. Entry Card Details

#### 2.1 Full Date Format
- **Current**: "EEEE, MMMM d" (e.g., "Monday, December 16")
- **Enhanced**: "EEEE, MMMM d, y" (e.g., "Monday, December 16, 2024")
- **Location**: Entry card header

#### 2.2 Sentiment Indicator
- **Display**: Color-coded indicator if insights available
- **Options**: 
  - Positive (green)
  - Neutral (gray/yellow)
  - Negative (red/orange)
- **UI**: Small colored dot or icon next to mood
- **Static Data**: Add `sentiment: 'positive'/'neutral'/'negative'` to mock entries

#### 2.3 Quick Stats
- **Display**: Row of mini stats
- **Items**:
  - Self-care count (e.g., "7/10")
  - Water cups (e.g., "💧 5 cups")
  - Meals logged (e.g., "🍽️ 2 meals")
- **UI**: Small chips/badges below preview text
- **Static Data**: Add stats to mock entries

#### 2.4 Last Edited Timestamp
- **Display**: Show if `updated_at` differs from `created_at`
- **Format**: "Edited 2 hours ago" or "Edited on Dec 15"
- **UI**: Small gray text below date
- **Static Data**: Add `isEdited: true/false` and `editedAt` to mock entries

---

### 3. Detail Bottom Sheet

#### 3.1 Full Diary Text
- **Display**: Complete scrollable diary text
- **Styling**: Match diary screen font/paper style
- **Scroll**: Full scrollable content

#### 3.2 AI Insight Section
- **Conditional**: Only show if insights exist
- **Content**:
  - Summary text
  - Sentiment label with score
  - Topics (as chips)
  - Insight text (if available)
- **UI**: Collapsible section with card styling
- **Static Data**: Add `insights` object to mock entries

#### 3.3 Related Sections
- **Sections to Display**:
  - **Affirmations**: List of affirmation items (or motivational message if empty)
  - **Gratitude**: List of grateful items (or motivational message if empty)
  - **Priorities**: List of priority items
  - **Meals**: Breakfast, lunch, dinner, water cups
  - **Self-Care**: Grid of completed items with icons
- **UI**: Collapsible cards for each section
- **Empty State**: Beautiful motivational message if section is empty
- **Static Data**: Add all related data to mock entries

#### 3.4 Metadata
- **Display**: Footer section with metadata
- **Items**:
  - Created timestamp
  - Updated timestamp (if different)
  - Source (mobile/web)
- **UI**: Small gray text at bottom

---

### 4. Filtering

#### 4.1 Date Range Picker
- **UI**: Filter button in app bar
- **Functionality**: Date range selector
- **Static**: For now, just UI (no actual filtering)

#### 4.2 Mood Filter
- **Options**: Filter by mood 1-5
- **UI**: Filter chips or dropdown
- **Static**: Add mood filter state

#### 4.3 Sentiment Filter
- **Options**: Positive, Neutral, Negative
- **UI**: Filter chips
- **Static**: Add sentiment filter state

#### 4.4 Has Insights Filter
- **Option**: Toggle to show only entries with insights
- **UI**: Switch or chip
- **Static**: Add insights filter state

#### 4.5 Completion Status Filter
- **Options**: 
  - All entries
  - Complete entries (all sections filled)
  - Incomplete entries
- **UI**: Filter chips
- **Static**: Add completion filter state

#### 4.6 Tag Filter (Dynamic)
- **Source**: Extract unique tags from all entries
- **UI**: Horizontal scrollable chips (current implementation)
- **Enhancement**: Show count of entries per tag
- **Static**: Generate unique tags from mock entries

---

### 5. Calendar View

#### 5.1 Mark Dates with Entries
- **Display**: Calendar widget with marked dates
- **Marking**: Dot or highlight on dates with entries
- **Static**: Use `table_calendar` package (or similar)

#### 5.2 Color-code by Mood/Sentiment
- **Colors**: 
  - Mood-based: 5 colors for 5 mood levels
  - Sentiment-based: Green/Neutral/Red
- **UI**: Colored dots on calendar dates
- **Static**: Apply colors based on mock entry data

#### 5.3 Entry Count per Day
- **Display**: Show count if multiple entries on same date
- **UI**: Number badge on calendar date
- **Static**: Group mock entries by date

#### 5.4 Tap Date to View Entries
- **Functionality**: Navigate to filtered list or show entries for that date
- **UI**: Bottom sheet or navigate to filtered list
- **Static**: Filter mock entries by selected date

---

## 📊 Mock Data Structure

### Enhanced Entry Model (for static data):
```dart
{
  'id': 'uuid',
  'date': DateTime,
  'mood': int (1-5),
  'diaryText': String,
  'preview': String, // First 100 chars
  'tags': List<String>,
  'wordCount': int,
  'hasInsights': bool,
  'sentiment': String, // 'positive', 'neutral', 'negative'
  'insights': {
    'summary': String,
    'sentimentLabel': String,
    'sentimentScore': double,
    'topics': List<String>,
    'insightText': String,
  },
  'completion': {
    'hasAffirmations': bool,
    'hasGratitude': bool,
    'selfCareCount': int, // 0-10
    'hasMeals': bool,
    'waterCups': int,
  },
  'stats': {
    'selfCareCount': int,
    'waterCups': int,
    'mealsLogged': int,
  },
  'affirmations': List<String>,
  'gratitude': List<String>,
  'priorities': List<String>,
  'meals': {
    'breakfast': String?,
    'lunch': String?,
    'dinner': String?,
  },
  'selfCare': {
    'sleep': bool,
    'exercise': bool,
    // ... all 10 items
  },
  'createdAt': DateTime,
  'updatedAt': DateTime,
  'isEdited': bool,
  'source': String, // 'mobile' or 'web'
}
```

---

## 🎯 Implementation Steps

### Phase 1: Enhanced Mock Data
1. Create comprehensive mock entries (20-30 entries spanning 3-4 months)
2. Include all data fields (insights, completion, stats, etc.)
3. Ensure variety in moods, sentiments, completion status

### Phase 2: List View Enhancements
1. Implement month/year grouping
2. Add word count badge
3. Add AI insight badge
4. Add completion indicators
5. Update date format
6. Add sentiment indicator
7. Add quick stats row
8. Add last edited timestamp

### Phase 3: Detail Bottom Sheet
1. Show full diary text
2. Add AI insight section (conditional)
3. Add related sections (affirmations, gratitude, etc.)
4. Add empty state messages for missing sections
5. Add metadata footer

### Phase 4: Filtering
1. Implement date range picker UI
2. Add mood filter
3. Add sentiment filter
4. Add insights filter
5. Add completion filter
6. Enhance tag filter with counts

### Phase 5: Calendar View
1. Integrate calendar widget
2. Mark dates with entries
3. Color-code by mood/sentiment
4. Show entry count per day
5. Implement tap to view entries

---

## 🎨 UI/UX Guidelines

### Colors
- **Positive Sentiment**: Green shades
- **Neutral Sentiment**: Gray/Yellow shades
- **Negative Sentiment**: Red/Orange shades
- **Mood Colors**: Red (1) → Orange (2) → Yellow (3) → Light Green (4) → Green (5)

### Typography
- **Section Headers**: Bold, larger font
- **Entry Preview**: Body medium, 2 lines max
- **Metadata**: Small, gray text

### Spacing
- **Card Padding**: 16px (mobile), 20px (tablet)
- **Section Spacing**: 12-16px between sections
- **Filter Chips**: 8px spacing

### Empty States
- **Motivational Messages**: 
  - "Start your day with positive affirmations! ✨"
  - "What are you grateful for today? 🙏"
  - "Every entry is a step forward on your journey 💫"

---

## 📝 Notes

- All features will use static mock data initially
- Backend integration will replace mock data later
- Ensure UI is responsive for tablet/desktop
- Maintain consistent styling with rest of app
- Test with various data combinations (empty, partial, complete entries)

---

## ✅ Checklist

- [ ] Create enhanced mock data structure
- [ ] Implement month/year grouping
- [ ] Add word count badge
- [ ] Add AI insight badge
- [ ] Add completion indicators
- [ ] Update date format
- [ ] Add sentiment indicator
- [ ] Add quick stats
- [ ] Add last edited timestamp
- [ ] Enhance detail bottom sheet
- [ ] Add AI insight section
- [ ] Add related sections with empty states
- [ ] Implement all filters
- [ ] Build calendar view
- [ ] Test responsive design
- [ ] Polish UI/animations

