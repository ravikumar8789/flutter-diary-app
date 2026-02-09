import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/analytics_models.dart';

/// Week chips carousel for week navigation
/// Displays weeks in chronological order (oldest to newest, left to right)
/// Auto-scrolls to newest week (rightmost) on initial load
class WeekChipsCarousel extends StatefulWidget {
  final List<WeekMetadata> weeks;
  final DateTime selectedWeek;
  final Function(DateTime) onWeekSelected;

  const WeekChipsCarousel({
    super.key,
    required this.weeks,
    required this.selectedWeek,
    required this.onWeekSelected,
  });

  @override
  State<WeekChipsCarousel> createState() => _WeekChipsCarouselState();
}

class _WeekChipsCarouselState extends State<WeekChipsCarousel> {
  late ScrollController _scrollController;
  DateTime? _previousSelectedWeek;
  bool _hasScrolledToEnd = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _previousSelectedWeek = widget.selectedWeek;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(WeekChipsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If selected week changed, scroll to it
    if (widget.selectedWeek != _previousSelectedWeek) {
      _previousSelectedWeek = widget.selectedWeek;
      _scrollToSelectedWeek();
    }
  }

  void _scrollToEnd() {
    if (!_scrollController.hasClients) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToSelectedWeek() {
    if (!_scrollController.hasClients || widget.weeks.isEmpty) return;

    // Reverse the list to find index (weeks are displayed in reverse order)
    final reversedWeeks = widget.weeks.reversed.toList();
    final selectedIndex = reversedWeeks.indexWhere((week) =>
        week.weekStart.year == widget.selectedWeek.year &&
        week.weekStart.month == widget.selectedWeek.month &&
        week.weekStart.day == widget.selectedWeek.day);

    if (selectedIndex == -1) return;

    // Estimate chip width (padding + text width + spacing)
    // Approximate: 16 (padding) + 100 (text) + 8 (spacing) = ~124 per chip
    const estimatedChipWidth = 124.0;
    final targetOffset = selectedIndex * estimatedChipWidth;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final scrollOffset = targetOffset.clamp(0.0, maxScroll);
        
        _scrollController.animateTo(
          scrollOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.weeks.isEmpty) {
      debugPrint('WeekChipsCarousel: weeks.isEmpty, returning SizedBox.shrink()');
      return const SizedBox.shrink();
    }

    debugPrint('WeekChipsCarousel.build: Building with ${widget.weeks.length} weeks');
    
    // Reverse weeks list: oldest to newest (left to right)
    // Service returns newest first, so we reverse for display
    final reversedWeeks = widget.weeks.reversed.toList();
    
    // Auto-scroll to end (newest week) on initial load
    if (!_hasScrolledToEnd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasScrolledToEnd) {
          _hasScrolledToEnd = true;
          _scrollToEnd();
        }
      });
    }
    
    // Always use fixed height - don't rely on parent constraints
    return SizedBox(
      height: 60,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: reversedWeeks.length,
        itemBuilder: (context, index) {
          final week = reversedWeeks[index];
          final isSelected = week.weekStart.year == widget.selectedWeek.year &&
              week.weekStart.month == widget.selectedWeek.month &&
              week.weekStart.day == widget.selectedWeek.day;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _WeekChip(
              week: week,
              isSelected: isSelected,
              onTap: () => widget.onWeekSelected(week.weekStart),
            ),
          );
        },
      ),
    );
  }
}

class _WeekChip extends StatefulWidget {
  final WeekMetadata week;
  final bool isSelected;
  final VoidCallback onTap;

  const _WeekChip({
    required this.week,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_WeekChip> createState() => _WeekChipState();
}

class _WeekChipState extends State<_WeekChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isSelected) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_WeekChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.forward();
    } else if (!widget.isSelected && oldWidget.isSelected) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatWeekRange(DateTime start, DateTime end) {
    final startFormat = DateFormat('MMM d');
    final endFormat = DateFormat('MMM d');
    return '${startFormat.format(start)} - ${endFormat.format(end)}';
  }

  Color _getStatusColor(BuildContext context) {
    switch (widget.week.status) {
      case 'success':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'error':
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(context);
    
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isSelected
                  ? Theme.of(context).colorScheme.primary
                  : statusColor.withOpacity(0.3),
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _formatWeekRange(widget.week.weekStart, widget.week.weekEnd),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
                  color: widget.isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (widget.week.entriesCount > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      '${widget.week.entriesCount} entries',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: statusColor,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
