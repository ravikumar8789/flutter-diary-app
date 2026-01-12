import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/analytics_models.dart';
import '../services/error_logging_service.dart';

/// Month chips carousel for month navigation
/// Displays months in chronological order (oldest to newest, left to right)
/// Auto-scrolls to newest month (rightmost) on initial load
class MonthChipsCarousel extends StatefulWidget {
  final List<MonthMetadata> months;
  final DateTime selectedMonth;
  final Function(DateTime) onMonthSelected;

  const MonthChipsCarousel({
    super.key,
    required this.months,
    required this.selectedMonth,
    required this.onMonthSelected,
  });

  @override
  State<MonthChipsCarousel> createState() => _MonthChipsCarouselState();
}

class _MonthChipsCarouselState extends State<MonthChipsCarousel> {
  late ScrollController _scrollController;
  DateTime? _previousSelectedMonth;
  bool _hasScrolledToEnd = false;

  @override
  void initState() {
    super.initState();
    try {
      _scrollController = ScrollController();
      _previousSelectedMonth = widget.selectedMonth;
    } catch (e) {
      ErrorLoggingService.logError(
        errorCode: 'ERRUI001',
        errorMessage: 'MonthChipsCarousel initState failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'MEDIUM',
        errorContext: {'operation': 'month_chips_carousel_init'},
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MonthChipsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If selected month changed, scroll to it
    if (widget.selectedMonth != _previousSelectedMonth) {
      _previousSelectedMonth = widget.selectedMonth;
      _scrollToSelectedMonth();
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

  void _scrollToSelectedMonth() {
    if (!_scrollController.hasClients || widget.months.isEmpty) return;

    try {
      // Reverse the list to find index (months are displayed in reverse order)
      final reversedMonths = widget.months.reversed.toList();
      final selectedIndex = reversedMonths.indexWhere((month) =>
          month.monthStart.year == widget.selectedMonth.year &&
          month.monthStart.month == widget.selectedMonth.month);

      if (selectedIndex == -1) return;

      // Estimate chip width (padding + text width + spacing)
      const estimatedChipWidth = 120.0;
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
    } catch (e) {
      ErrorLoggingService.logError(
        errorCode: 'ERRUI001',
        errorMessage: 'Scroll to selected month failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'LOW',
        errorContext: {'operation': 'scroll_to_selected_month'},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      if (widget.months.isEmpty) {
        return const SizedBox.shrink();
      }

      // Reverse months list: oldest to newest (left to right)
      // Service returns newest first, so we reverse for display
      final reversedMonths = widget.months.reversed.toList();
      
      // Auto-scroll to end (newest month) on initial load
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
          itemCount: reversedMonths.length,
          itemBuilder: (context, index) {
            final month = reversedMonths[index];
            final isSelected = month.monthStart.year == widget.selectedMonth.year &&
                month.monthStart.month == widget.selectedMonth.month;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _MonthChip(
                month: month,
                isSelected: isSelected,
                onTap: () => widget.onMonthSelected(month.monthStart),
              ),
            );
          },
        ),
      );
    } catch (e) {
      ErrorLoggingService.logError(
        errorCode: 'ERRUI001',
        errorMessage: 'MonthChipsCarousel build failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'MEDIUM',
        errorContext: {'operation': 'month_chips_carousel_build'},
      );
      return const SizedBox.shrink();
    }
  }
}

class _MonthChip extends StatefulWidget {
  final MonthMetadata month;
  final bool isSelected;
  final VoidCallback onTap;

  const _MonthChip({
    required this.month,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_MonthChip> createState() => _MonthChipState();
}

class _MonthChipState extends State<_MonthChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    try {
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
    } catch (e) {
      ErrorLoggingService.logError(
        errorCode: 'ERRUI001',
        errorMessage: '_MonthChip initState failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'LOW',
        errorContext: {'operation': 'month_chip_init'},
      );
    }
  }

  @override
  void didUpdateWidget(_MonthChip oldWidget) {
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

  String _formatMonth(DateTime monthStart) {
    return DateFormat('MMM yyyy').format(monthStart);
  }

  Color _getStatusColor(BuildContext context) {
    if (!widget.month.hasAnalysis) {
      return Colors.grey;
    }
    switch (widget.month.status) {
      case 'success':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
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
            width: 120,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  _formatMonth(widget.month.monthStart),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
                    color: widget.isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (widget.month.entriesCount > 0)
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
                        '${widget.month.entriesCount} entries',
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
    } catch (e) {
      ErrorLoggingService.logError(
        errorCode: 'ERRUI001',
        errorMessage: '_MonthChip build failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'MEDIUM',
        errorContext: {'operation': 'month_chip_build'},
      );
      return const SizedBox.shrink();
    }
  }
}

