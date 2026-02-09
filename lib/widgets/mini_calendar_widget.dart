import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

/// Mini calendar widget for week selection
/// Simple calendar for selecting any week - no analysis data connection
class MiniCalendarWidget extends StatefulWidget {
  final DateTime selectedWeek;
  final Function(DateTime) onWeekSelected;

  const MiniCalendarWidget({
    super.key,
    required this.selectedWeek,
    required this.onWeekSelected,
  });

  @override
  State<MiniCalendarWidget> createState() => _MiniCalendarWidgetState();
}

class _MiniCalendarWidgetState extends State<MiniCalendarWidget> {
  late DateTime _focusedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.selectedWeek;
  }

  @override
  void didUpdateWidget(MiniCalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedWeek != oldWidget.selectedWeek) {
      _focusedDay = widget.selectedWeek;
    }
  }

  DateTime _getWeekStart(DateTime date) {
    // Get Sunday of the week
    final weekday = date.weekday;
    return date.subtract(Duration(days: weekday % 7));
  }

  bool _isInSelectedWeek(DateTime date) {
    final weekStart = _getWeekStart(date);
    return weekStart.year == widget.selectedWeek.year &&
        weekStart.month == widget.selectedWeek.month &&
        weekStart.day == widget.selectedWeek.day;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: 360,
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Week',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TableCalendar(
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 30)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => _isInSelectedWeek(day),
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: StartingDayOfWeek.sunday,
                headerVisible: true,
                daysOfWeekVisible: true,
                weekendDays: const [DateTime.saturday, DateTime.sunday],
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  formatButtonShowsNext: false,
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                  ) ?? TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                  ),
                  leftChevronMargin: const EdgeInsets.only(left: 4),
                  rightChevronMargin: const EdgeInsets.only(right: 4),
                  headerPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  weekendTextStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                  defaultTextStyle: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                  todayDecoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.35),
                      width: 1.5,
                    ),
                  ),
                  todayTextStyle: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: TextStyle(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  markerDecoration: const BoxDecoration(shape: BoxShape.circle),
                  cellMargin: const EdgeInsets.all(1),
                  cellPadding: EdgeInsets.zero,
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                  weekendStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, date, focusedDay) {
                    final isSelectedWeek = _isInSelectedWeek(date);
                    
                    return Container(
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: isSelectedWeek
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                            : null,
                        borderRadius: BorderRadius.circular(5),
                        border: isSelectedWeek
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            color: isSelectedWeek
                                ? Theme.of(context).colorScheme.primary
                                : colorScheme.onSurface,
                            fontWeight: isSelectedWeek
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                  todayBuilder: (context, date, focusedDay) {
                    final isSelectedWeek = _isInSelectedWeek(date);
                    
                    return Container(
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: isSelectedWeek
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                            : colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: isSelectedWeek
                              ? Theme.of(context).colorScheme.primary
                              : colorScheme.primary.withOpacity(0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            color: isSelectedWeek
                                ? Theme.of(context).colorScheme.primary
                                : colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _focusedDay = focusedDay;
                  });
                  final weekStart = _getWeekStart(selectedDay);
                  widget.onWeekSelected(weekStart);
                  Navigator.of(context).pop();
                },
                onPageChanged: (focusedDay) {
                  setState(() {
                    _focusedDay = focusedDay;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }
}

