import 'package:flutter/material.dart';
import '../models/analytics_models.dart';

/// A polished pill-style switch for toggling between Week and Month analytics.
/// Uses sliding indicator animation and theme-aware styling.
class AnalyticsPeriodSwitch extends StatelessWidget {
  final AnalyticsPeriod value;
  final ValueChanged<AnalyticsPeriod> onChanged;
  final bool compact;

  const AnalyticsPeriodSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isWeekly = value == AnalyticsPeriod.weekly;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = compact || constraints.maxWidth < 280;
        final height = isCompact ? 36.0 : 40.0;
        final fontSize = isCompact ? 12.0 : 13.0;
        final iconSize = isCompact ? 16.0 : 18.0;
        final horizontalPadding = isCompact ? 10.0 : 14.0;
        final hasBoundedWidth = constraints.maxWidth.isFinite;
        final effectiveMaxWidth = hasBoundedWidth ? constraints.maxWidth : 220.0;

        return ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: 160,
            maxWidth: effectiveMaxWidth,
          ),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.6),
              borderRadius: BorderRadius.circular(height / 2),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.all(2),
            child: LayoutBuilder(
            builder: (context, innerConstraints) {
              final segmentWidth =
                  (innerConstraints.maxWidth - 4) / 2;
              return Stack(
                children: [
                  // Sliding indicator
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    left: 2 + (isWeekly ? 0 : segmentWidth),
                    top: 2,
                    bottom: 2,
                    width: segmentWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius:
                            BorderRadius.circular((height - 4) / 2),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Labels
                  Row(
                    children: [
                      _Segment(
                        label: 'Week',
                        icon: Icons.calendar_view_week,
                        isSelected: isWeekly,
                        onTap: () => onChanged(AnalyticsPeriod.weekly),
                        height: height,
                        fontSize: fontSize,
                        iconSize: iconSize,
                        horizontalPadding: horizontalPadding,
                        colorScheme: colorScheme,
                      ),
                      _Segment(
                        label: 'Month',
                        icon: Icons.calendar_month,
                        isSelected: !isWeekly,
                        onTap: () => onChanged(AnalyticsPeriod.monthly),
                        height: height,
                        fontSize: fontSize,
                        iconSize: iconSize,
                        horizontalPadding: horizontalPadding,
                        colorScheme: colorScheme,
                      ),
                    ],
                  ),
                ],
              );
            },
            ),
          ),
        );
      },
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final double height;
  final double fontSize;
  final double iconSize;
  final double horizontalPadding;
  final ColorScheme colorScheme;

  const _Segment({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.height,
    required this.fontSize,
    required this.iconSize,
    required this.horizontalPadding,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular((height - 4) / 2),
          splashColor: colorScheme.primary.withOpacity(0.15),
          highlightColor: colorScheme.primary.withOpacity(0.08),
          child: Container(
            height: height - 4,
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: iconSize,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
                SizedBox(width: iconSize * 0.4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
