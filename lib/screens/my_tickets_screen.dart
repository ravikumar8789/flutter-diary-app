import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/utility_models.dart';
import '../services/support_ticket_service.dart';
import '../utils/snackbar_utils.dart';
import '../services/error_logging_service.dart';
import '../models/error_models.dart';
import '../ui/responsive/responsive_body.dart';
import '../ui/responsive/responsive_info.dart';
import '../ui/responsive/responsive_tokens.dart';
import '../ui/responsive/responsive_wrap.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  List<SupportTicket> _tickets = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tickets = await SupportTicketService.getUserTickets();
      if (mounted) {
        setState(() {
          _tickets = tickets;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load tickets';
          _isLoading = false;
        });
        await ErrorLoggingService.logHighError(
          error: ErrorContext.fromException(
            errorCode: 'ERRSYS125',
            severity: ErrorSeverity.high,
            exception: e,
            stackTrace: StackTrace.current,
            errorContext: {
              'screen': 'MyTicketsScreen',
              'operation': 'load_tickets',
            },
          ),
        );
        SnackbarUtils.showError(context, 'Failed to load tickets');
      }
    }
  }

  String _getCategoryLabel(String? category) {
    switch (category) {
      case 'bug':
        return 'Bug Report';
      case 'feature':
        return 'Feature Request';
      case 'question':
        return 'Question';
      case 'feedback':
        return 'Feedback';
      case 'other':
        return 'Other';
      default:
        return 'Unknown';
    }
  }

  Color _getCategoryColor(BuildContext context, String? category) {
    switch (category) {
      case 'bug':
        return Colors.red;
      case 'feature':
        return Colors.blue;
      case 'question':
        return Colors.orange;
      case 'feedback':
        return Colors.green;
      case 'other':
        return Theme.of(context).colorScheme.onSurfaceVariant;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }

  void _showTicketDetails(SupportTicket ticket) {
    final info = ResponsiveInfo.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: info.value(compact: 0.65, medium: 0.7, expanded: 0.8),
        minChildSize: info.value(compact: 0.45, medium: 0.5, expanded: 0.6),
        maxChildSize: info.value(compact: 0.9, medium: 0.95, expanded: 0.98),
      builder: (context, scrollController) {
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveTokens.spacingL(info),
                  vertical: ResponsiveTokens.spacingM(info),
                ),
                child: ResponsiveWrapRow(
                  info: info,
                  rowMainAxisAlignment: MainAxisAlignment.spaceBetween,
                  wrapAlignment: WrapAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ticket Details',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ticket.ticketNumber ?? 'N/A',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: ticket.status == TicketStatus.open
                            ? Colors.green[100]
                            : colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        ticket.status == TicketStatus.open ? 'Open' : 'Closed',
                        style: TextStyle(
                          color: ticket.status == TicketStatus.open
                              ? Colors.green[800]
                              : colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.all(ResponsiveTokens.spacingL(info)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category
                      _buildDetailRow(
                        context,
                        'Category',
                        _getCategoryLabel(ticket.category),
                        icon: Icons.category,
                        color: _getCategoryColor(context, ticket.category),
                      ),
                      const SizedBox(height: 16),
                      // Subject
                      _buildDetailRow(
                        context,
                        'Subject',
                        ticket.subject ?? 'N/A',
                        icon: Icons.subject,
                      ),
                      const SizedBox(height: 16),
                      // Message
                      _buildDetailSection(
                        context,
                        'Message',
                        ticket.message ?? 'N/A',
                        icon: Icons.message,
                      ),
                      const SizedBox(height: 16),
                      // Created Date
                      _buildDetailRow(
                        context,
                        'Submitted',
                        _formatDate(ticket.createdAt),
                        icon: Icons.calendar_today,
                      ),
                      // Closed Date (if closed)
                      if (ticket.status == TicketStatus.closed && ticket.closedAt != null) ...[
                        const SizedBox(height: 16),
                        _buildDetailRow(
                          context,
                          'Closed',
                          _formatDate(ticket.closedAt!),
                          icon: Icons.check_circle,
                        ),
                      ],
                      // Closure Note (if closed and has note)
                      if (ticket.status == TicketStatus.closed && ticket.closureNote != null) ...[
                        const SizedBox(height: 16),
                        _buildDetailSection(
                          context,
                          'Response',
                          ticket.closureNote!,
                          icon: Icons.note,
                          isResponse: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    IconData? icon,
    Color? color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 20,
            color: color ?? colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailSection(
    BuildContext context,
    String label,
    String value, {
    IconData? icon,
    bool isResponse = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 20,
                color:
                    isResponse ? Colors.green[700] : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isResponse ? Colors.green[50] : colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isResponse ? Colors.green[200]! : colorScheme.outlineVariant,
            ),
          ),
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tickets'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadTickets,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _tickets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No tickets yet',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Submit a ticket from Help & Support',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadTickets,
                      child: ResponsiveBody(
                        useSafeArea: false,
                        useScrollView: false,
                        child: ListView.builder(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveTokens.screenPaddingHorizontal(
                              ResponsiveInfo.of(context),
                            ),
                            vertical: ResponsiveTokens.spacingM(
                              ResponsiveInfo.of(context),
                            ),
                          ),
                          itemCount: _tickets.length,
                          itemBuilder: (context, index) {
                            final ticket = _tickets[index];
                            return Card(
                              elevation: 1,
                              margin: EdgeInsets.only(
                                bottom: ResponsiveTokens.spacingM(
                                  ResponsiveInfo.of(context),
                                ),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                onTap: () => _showTicketDetails(ticket),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: EdgeInsets.all(
                                    ResponsiveTokens.spacingM(
                                      ResponsiveInfo.of(context),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Header row
                                      ResponsiveWrapRow(
                                        info: ResponsiveInfo.of(context),
                                        rowMainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        wrapAlignment: WrapAlignment.spaceBetween,
                                        children: [
                                          // Category badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getCategoryColor(
                                                context,
                                                ticket.category,
                                              ).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              _getCategoryLabel(ticket.category),
                                              style: TextStyle(
                                                color: _getCategoryColor(
                                                  context,
                                                  ticket.category,
                                                ),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          // Status badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: ticket.status == TicketStatus.open
                                                  ? Colors.green[100]
                                                  : colorScheme.surfaceVariant,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              ticket.status == TicketStatus.open
                                                  ? 'Open'
                                                  : 'Closed',
                                              style: TextStyle(
                                                color: ticket.status == TicketStatus.open
                                                    ? Colors.green[800]
                                                    : colorScheme.onSurface,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(
                                        height: ResponsiveTokens.spacingS(
                                          ResponsiveInfo.of(context),
                                        ),
                                      ),
                                      // Subject
                                      Text(
                                        ticket.subject ?? 'No subject',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(
                                        height: ResponsiveTokens.spacingS(
                                          ResponsiveInfo.of(context),
                                        ),
                                      ),
                                      // Footer row
                                      ResponsiveWrapRow(
                                        info: ResponsiveInfo.of(context),
                                        rowMainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        wrapAlignment: WrapAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 14,
                                                color: colorScheme.onSurfaceVariant,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _formatDate(ticket.createdAt),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                  color: colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            ticket.ticketNumber ?? 'N/A',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                              color: colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
    );
  }
}

