# Plan 1 — Minimalist Diary UI and Navigation

## Design Principles
- Minimal, calm, diary-themed (paper-like background, subtle lines, high readability).
- Low interaction cost: single-page inputs, fixed data fields where possible.
- Fast entry first; insights come later.
- Accessible: large tap targets, high contrast, screen-reader labels.

## Screens Overview
- Home (overview + quick entry CTA)
- Diary (two tabs on one page: Affirmations | Diary)
- Analytics (basic trends; later expanded)
- Profile (account, reminder prefs, export/delete)

Navigation uses a persistent left sidebar (drawer on mobile) instead of a bottom navbar.

---

## Diary Screen (Single Page)
Two top tabs in the same screen:
- Tab 1: Affirmations
- Tab 2: Diary

Top has date selector (today by default) and weekday pills (SA SU MON TUE WED THU FRI) for quick context.

### Tab: Affirmations (Fixed-Input Model)
Goal: capture consistent, structured inputs to streamline analytics.

Sections and fields (fixed choices/text areas):
- Affirmations for Today: 5 short text lines (multiline disabled; 80 chars max each).
- Top 6 Priorities: 6 short text lines.
- Meals: 3 small text fields (Breakfast, Lunch, Dinner).
- Water Intake: 8 toggle cups (0–8) with a single numeric total.
- 6 Things I’m Grateful For: 6 short text lines.
- Self Care Activities (checkboxes):
  - Sleep, Get up early, Get fresh air, Learn something new, Eat well-balanced diet,
    Listen to a podcast, Take a “me” moment, Stay hydrated, Read a book, Exercise.
- Shower/Bath checklist: 1–4 lines (short text).
- Important Notes Tomorrow: 4 short lines.

Constraints:
- Keep inputs short and fixed-count for consistent analytics.
- Use placeholder text and gentle character limits.
- Autosave on change; no explicit submit required.

### Tab: Diary (Notepad Style)
- Large, lined textarea with monospace or clean serif.
- Minimal chrome: word count, last saved indicator, and mood slider (1–5) below.
- Optional tags (fixed set chips): work, study, family, health, social, finance, misc.
- Autosave every 2s and on blur; offline-first local cache.

---

## Sidebar Navigation (Left Drawer)
Always available from the left (hamburger on small screens):
- Home
- Diary
- Analytics
- Profile
- Settings

Behavior:
- Collapsible to icons; expands on hover.
- Keyboard shortcuts: Alt+1 Home, Alt+2 Diary, Alt+3 Analytics, Alt+4 Profile.

---

## Fixed Data Model Mapping (for AI/Analytics)
Structured fields → normalized tables/columns to simplify aggregation:
- date, weekday
- affirmations[1..5]
- priorities[1..6]
- meals.breakfast, meals.lunch, meals.dinner
- water_cups (0–8)
- gratitude[1..6]
- self_care_flags: sleep, early, fresh_air, learn, diet, podcast, me_moment,
  hydrated, read, exercise
- shower_bath_notes[1..4]
- important_notes_tomorrow[1..4]
- diary_text (freeform)
- mood_score (1–5)
- tags[] (from fixed list)

---

## Initial Analytics (derived from fixed inputs)
- Habit adherence: self_care completion rate per category per week.
- Hydration trend: average cups/day, streaks over 8 cups.
- Gratitude breadth: unique themes/topics (via lightweight keywording).
- Priority follow-through: number of priorities filled vs. carried over.
- Mood correlation: mood vs. water/self-care/affirmations presence.
- Diary sentiment (LLM) vs. mood slider correlation.

---

## Interaction Rules
- Minimal modals; inline validation.
- Undo for last 30 seconds of edits.
- Non-blocking save to local cache then sync.
- Gentle nudge if any required fixed fields left empty when navigating away.

---

## Visual Style
- Neutral palette: paper off-white background, graphite text, accent ink blue.
- Typography: headings friendly serif; body readable sans.
- Components: lined cards with subtle shadows; checkboxes as rounded squares.
- Iconography: simple line icons; no heavy color.

---

## Accessibility
- Labels for every field; role=tab for tabs; aria-selected states.
- Focus outlines; tab order mirrors visual order.
- Color contrast ≥ 4.5:1; dynamic type scaling.

---

## Implementation Notes
- Flutter: `DefaultTabController` for two tabs within Diary screen.
- Sidebar: `NavigationRail` on wide, `Drawer` on narrow screens.
- State: Riverpod; autosave debounced provider.
- Offline-first: local `sqflite`/`hive` cache with sync to Supabase.
- Fixed data schemas align with `entries` + `entry_insights` tables.

### Components
- AffirmationsForm, PrioritiesForm, MealsWaterForm, GratitudeForm,
  SelfCareChecklist, ShowerBathNotes, ImportantTomorrowNotes,
  DiaryNotepad, MoodSlider, TagChips, SaveIndicator.

---

## Milestone Breakdown
- M1: Diary page shell with tabs + sidebar nav wired.
- M2: Affirmations tab with fixed inputs and autosave.
- M3: Diary notepad, mood slider, tags, autosave.
- M4: Local cache + sync; basic analytics wiring.
- M5: Polish, a11y pass, theming.

---

## Open Questions
- Exact fixed list text for self-care and tags; confirm copy.
- Max lengths for each short-line field.
- Whether to allow backdating entries from sidebar calendar.
