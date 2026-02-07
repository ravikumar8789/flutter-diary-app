# Responsive Architecture - Implementation Plan

## Scope
- Target devices: phones + tablets (portrait + landscape).
- Not targeting desktop/large monitors (still use max width caps).

## Non-Goals (Protect Current Flow)
- No changes to providers, services, navigation, or data logic.
- No changes to app startup sequence (Supabase init, notifications, lifecycle).
- No feature behavior changes; layout-only adjustments.

## Current State (Quick Audit)
- Many screens use `isTablet = width > 600` with fixed padding and maxWidth.
- Complex screens use fixed grid counts and hard heights.
- Several screens have no responsive logic at all.
- Some widgets already use constraints, but not standardized.

## Architecture (Shared Utilities)
1. Breakpoints
   - Compact: width < 600
   - Medium: 600 - 900
   - Expanded: > 900 (still capped by max content width)
2. ResponsiveInfo (single source of truth)
   - width/height/breakpoint/isCompact/isMedium/isExpanded
   - responsiveValue helper for spacing, padding, sizes
3. Tokens (centralized)
   - spacing: xs/s/m/l
   - padding: screen horizontal/vertical
   - maxContentWidth: 520 (phone), 720 (tablet), 840 (large tablet)
   - gridMinTileWidth for cards
4. Layout wrappers
   - ResponsiveBody: LayoutBuilder + Align + ConstrainedBox(maxWidth) + Padding
   - Optional ResponsiveScaffold: SafeArea + Scrollbar + scroll behavior
5. Layout helpers
   - responsiveGridDelegate(maxTileWidth, spacing)
   - ResponsiveWrapRow (Row on medium/expanded, Wrap on compact)
   - ResponsiveChartBox (AspectRatio or height from constraints)
   - ResponsiveAppBarActions (segmented vs dropdown on compact)

## Planned File Structure
- `lib/ui/responsive/breakpoints.dart`
- `lib/ui/responsive/responsive_info.dart`
- `lib/ui/responsive/responsive_tokens.dart`
- `lib/ui/responsive/responsive_body.dart`
- `lib/ui/responsive/responsive_grid.dart`
- `lib/ui/responsive/responsive_wrap.dart`
- `lib/ui/responsive/responsive_chart_box.dart`
- `lib/ui/responsive/responsive_app_bar_actions.dart`

## Implementation Phases
### Phase 0 - Safety Baseline
- Capture current UI at target sizes (see test matrix).
- Identify screens with overflow risk (grids, chips, charts, long text).
- Confirm no startup/service files will be edited.

### Phase 1 - Build Responsive Core
- Add responsive helpers and tokens (no screen edits yet).
- Ensure helpers are pure layout utilities (no app logic).

### Phase 2 - Update Shared Widgets
- `mini_calendar_widget`: enforce max width and responsive padding.
- `interactive_bar_chart`: size bars/labels by constraints.
- `day_details_bottom_sheet`: responsive heights and padding.
- `bottom_navigation_bar`: check font sizes for compact screens.

### Phase 3 - Reference Screen (Analytics)
- AppBar actions: switch to compact menu on small widths.
- Summary cards: use max tile width, not fixed `crossAxisCount`.
- Monthly stats row: Wrap on compact, Row on medium/expanded.
- Charts: aspect ratio or constraint-based height.
- AI insight cards: constrain max width to avoid wide text blocks.
- Replace fixed spacing with token-based spacing.

### Phase 4 - Screen Integration (Grouped)
1. Forms and static pages
   - `login_screen`, `register_screen`, `terms_screen`, `privacy_policy_screen`
   - Apply `ResponsiveBody`, consistent padding, max width caps.
2. Settings + support
   - `settings_screen`, `help_support_screen`, `my_tickets_screen`
   - Wrap dense rows/chips, adjust form spacing and headers.
3. Core screens
   - `home_screen`: grid tiles and cards via max tile width.
   - `history_screen`: list + calendar layouts, wrap chips, bottom sheet sizing.
4. Heavy form screen
   - `new_diary_screen`: responsive section layout, 1-column on compact,
     2-column on tablet where safe, wrap chips, limit text widths.
5. Auth/security screens
   - `pin_lock_screen`, `pin_setup_screen`, `pin_recovery_screen`,
     `change_pin_screen`, `security_questions_screen`
   - Center content, keypad sizing by constraints, safe padding.
6. Other
   - `yesterday_insight_screen`, `notification_test_screen`
   - Constrain text width and card spacing.

## Screen-by-Screen Checklist (What Changes)
- Replace `isTablet` padding with responsive tokens.
- Replace `GridView.count` with max-cross-axis grid delegate.
- Replace dense `Row` with `Wrap` on compact.
- Use `ResponsiveBody` for consistent centering and width caps.
- Avoid fixed heights where possible (use `AspectRatio`/constraints).
- Keep all existing callbacks, providers, and navigation intact.

## Startup and Flow Protection
- Do not touch `main.dart`, `AppWrapper`, or service initialization.
- No edits to auth or notification workflows.
- Any change that affects flow will be flagged before applying.

## Test Matrix
- Small phone: 360x640
- Large phone: 412x915
- Small tablet: 600x960
- Tablet: 800x1280
- Landscape checks: 640x360 and 1024x600
- Verify: no overflow, no clipping, all actions work.

## Done Criteria
- All screens fit on phone + tablet without layout errors.
- No functional regressions (navigation, save, providers, startup).
- Consistent padding/grid behavior across screens.