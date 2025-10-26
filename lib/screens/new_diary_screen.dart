import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../providers/entry_provider.dart';
import '../providers/sync_status_provider.dart';
import '../providers/paper_style_provider.dart';
import '../providers/font_size_provider.dart';
import '../services/error_logging_service.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/app_drawer.dart';
import '../widgets/paper_background.dart';

class NewDiaryScreen extends ConsumerStatefulWidget {
  const NewDiaryScreen({super.key});

  @override
  ConsumerState<NewDiaryScreen> createState() => _NewDiaryScreenState();
}

class _NewDiaryScreenState extends ConsumerState<NewDiaryScreen> {
  final TextEditingController _diaryController = TextEditingController();
  final FocusNode _diaryFocusNode = FocusNode();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Load entry data when screen mounts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEntryData();
    });
  }

  @override
  void dispose() {
    _diaryController.dispose();
    _diaryFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadEntryData() async {
    final currentDate = DateTime.now();
    final userId = supabase.Supabase.instance.client.auth.currentUser?.id;

    if (userId != null && !_isInitialized) {
      _isInitialized = true;
      await ref.read(entryProvider.notifier).loadEntry(userId, currentDate);

      // Update text controller with loaded data
      final entryState = ref.read(entryProvider);
      if (entryState.entry?.diaryText != null) {
        _diaryController.text = entryState.entry!.diaryText!;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentDate = DateTime.now();
    final syncState = ref.watch(syncStatusProvider);
    final entryState = ref.watch(entryProvider);
    final paperStyle = ref.watch(paperStyleProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final userId = supabase.Supabase.instance.client.auth.currentUser?.id;

    // Show loading state while entry data is being fetched
    if (entryState.isLoading && entryState.entry == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Diary')),
        drawer: const AppDrawer(currentRoute: 'diary'),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading your diary...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Today - ${DateFormat('MMM d, y').format(DateTime.now())}',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        actions: [
          // Sync status indicator
          _buildSyncStatusIcon(syncState),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearContent,
            tooltip: 'Clear all',
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: 'diary'),
      body: PaperBackground(
        paperStyle: paperStyle,
        lineHeight: 24.0, // Match the line height for proper alignment
        child: Column(
          children: [
            // Minimal greeting
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  Icon(_getGreetingIcon(), color: Colors.grey[600], size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _getGreeting(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Full-screen diary text field
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors
                    .transparent, // Make transparent to show paper background
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _diaryController,
                  focusNode: _diaryFocusNode,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: TextStyle(
                    fontSize: fontSize.size,
                    height:
                        paperStyle == PaperStyle.ruled ||
                            paperStyle == PaperStyle.grid
                        ? 1.0 // Match line height exactly for ruled/grid
                        : 1.6, // Normal line height for plain
                    letterSpacing: 0.3,
                    color: Colors.black87,
                  ),
                  onChanged: (text) {
                    if (userId != null) {
                      ref
                          .read(entryProvider.notifier)
                          .updateDiaryText(userId, currentDate, text);
                    }
                  },
                  decoration: InputDecoration(
                    hintText:
                        'Start writing your thoughts...\n\nYou can write about:\n• How your day went\n• Things you\'re grateful for\n• Challenges you faced\n• Goals and dreams\n• People who made you smile\n• Lessons you learned\n\nJust let your thoughts flow naturally! ✨',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: fontSize.size,
                      height:
                          paperStyle == PaperStyle.ruled ||
                              paperStyle == PaperStyle.grid
                          ? 1.0 // Match line height exactly for ruled/grid
                          : 1.6, // Normal line height for plain
                      letterSpacing: 0.3,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    fillColor: Colors
                        .transparent, // Make transparent to show paper background
                    filled: true,
                  ),
                ),
              ),
            ),

            // Status bar with sync indicator
            _buildStatusBar(syncState),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning! Start your day right';
    } else if (hour < 17) {
      return 'Good Afternoon! Capture your thoughts';
    } else {
      return 'Good Evening! Reflect on your day';
    }
  }

  IconData _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return Icons.wb_sunny;
    } else if (hour < 17) {
      return Icons.wb_cloudy;
    } else {
      return Icons.nightlight_round;
    }
  }

  Widget _buildSyncStatusIcon(SyncState syncState) {
    switch (syncState.status) {
      case SyncStatus.syncing:
        return const Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case SyncStatus.saved:
        return Icon(Icons.cloud_done, color: Colors.green[600]);
      case SyncStatus.error:
        return Icon(Icons.cloud_off, color: Colors.red[600]);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStatusBar(SyncState syncState) {
    String statusText = 'Not saved';
    Color statusColor = Colors.grey[500]!;

    switch (syncState.status) {
      case SyncStatus.syncing:
        statusText = 'Syncing...';
        statusColor = Colors.blue[600]!;
        break;
      case SyncStatus.saved:
        statusText = 'Auto-saved';
        statusColor = Colors.green[600]!;
        break;
      case SyncStatus.error:
        statusText = 'Save failed - will retry';
        statusColor = Colors.red[600]!;
        break;
      default:
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _getSyncStatusIcon(syncState.status),
                size: 14,
                color: statusColor,
              ),
              const SizedBox(width: 6),
              Text(
                statusText,
                style: TextStyle(color: statusColor, fontSize: 12),
              ),
            ],
          ),
          if (syncState.lastSavedAt != null)
            Text(
              DateFormat('hh:mm a').format(syncState.lastSavedAt!),
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
        ],
      ),
    );
  }

  IconData _getSyncStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return Icons.sync;
      case SyncStatus.saved:
        return Icons.check_circle;
      case SyncStatus.error:
        return Icons.error_outline;
      default:
        return Icons.circle_outlined;
    }
  }

  void _clearContent() async {
    if (_diaryController.text.trim().isEmpty) {
      // Log error to Supabase
      await ErrorLoggingService.logLowError(
        errorCode: 'ERRUI001',
        errorMessage: 'Nothing to clear',
        errorContext: {
          'action': 'clear_content',
          'text_length': _diaryController.text.length,
          'user_id': supabase.Supabase.instance.client.auth.currentUser?.id,
        },
      );

      SnackbarUtils.showError(context, 'Nothing to clear', 'ERRUI001');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Content?'),
        content: const Text(
          'Are you sure you want to clear all content? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _diaryController.clear();
      _diaryFocusNode.requestFocus();

      // Clear the entry data as well
      final userId = supabase.Supabase.instance.client.auth.currentUser?.id;
      final currentDate = DateTime.now();
      if (userId != null) {
        ref
            .read(entryProvider.notifier)
            .updateDiaryText(userId, currentDate, '');
      }
    }
  }
}
