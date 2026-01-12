# Unused Widgets Audit

## Widget Files in `lib/widgets/`

1. ✅ **bottom_navigation_bar.dart** - `AppBottomNavigationBar`
   - Used in: home_screen, analytics_screen, history_screen, profile_screen

2. ✅ **daily_insights_timeline.dart** - `DailyInsightsTimeline`
   - Used in: analytics_screen, ai_service

3. ✅ **day_details_bottom_sheet.dart** - `DayDetailsBottomSheet`
   - Used in: analytics_screen

4. ✅ **grace_system_info_card.dart** - `GraceSystemInfoCard` & `GraceSystemInfoButton`
   - Used in: home_screen, settings_screen

5. ✅ **habit_correlations_card.dart** - `HabitCorrelationsCard`
   - Used in: analytics_screen

6. ✅ **interactive_bar_chart.dart** - `InteractiveBarChart`
   - Used in: analytics_screen

7. ✅ **mini_calendar_widget.dart** - `MiniCalendarWidget`
   - Used in: analytics_screen

8. ✅ **period_comparison_card.dart** - `PeriodComparisonCard`
   - Used in: analytics_screen

9. ✅ **pin_number_pad.dart** - `PinNumberPad`
   - Used in: pin_lock_screen, pin_recovery_screen, pin_setup_screen, change_pin_screen

10. ✅ **week_chips_carousel.dart** - `WeekChipsCarousel`
    - Used in: analytics_screen

11. ✅ **yesterday_insight_card.dart** - `YesterdayInsightCard`
    - Used in: home_screen

## Nested Widgets in Screens

1. ✅ **_SkeletonShimmer** (in home_screen.dart)
   - Used internally in home_screen.dart

2. ✅ **_ExpandableInsightsCard** (in history_screen.dart)
   - Used internally in history_screen.dart

3. ✅ **_Section** (in terms_screen.dart, privacy_policy_screen.dart)
   - Used internally in respective screens

4. ✅ **AuthLoadingScreen** (in auth_wrapper.dart)
   - Used internally in auth_wrapper.dart

## Result

**All widgets are in use. No unused widgets found.**

