import 'package:flutter/material.dart';
import '../services/database/database_manager.dart';

/// Temporary debug widget to show all local SQLite tables and data.
/// TODO: Remove after debugging
class DebugLocalDbBottomSheet extends StatefulWidget {
  const DebugLocalDbBottomSheet({super.key});

  @override
  State<DebugLocalDbBottomSheet> createState() =>
      _DebugLocalDbBottomSheetState();
}

class _DebugLocalDbBottomSheetState extends State<DebugLocalDbBottomSheet> {
  static const List<String> _tables = [
    'entries',
    'entry_affirmations',
    'entry_priorities',
    'entry_meals',
    'entry_gratitude',
    'entry_self_care',
    'entry_shower_bath',
    'entry_tomorrow_notes',
    'sync_queue',
    'streaks',
    'habits_daily',
    'users',
    'user_settings',
    'user_profiles',
    'yesterday_insight',
    'entry_insights_local',
  ];

  Map<String, List<Map<String, dynamic>>> _tableData = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final db = await DatabaseManager().database;
      final data = <String, List<Map<String, dynamic>>>{};

      for (final table in _tables) {
        try {
          final rows = await db.query(table);
          data[table] = rows.map((r) => Map<String, dynamic>.from(r)).toList();
        } catch (e) {
          data[table] = [{'__error__': e.toString()}];
        }
      }

      setState(() {
        _tableData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Debug: Local DB',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Card(
              color: Colors.red.shade100,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(_error!, style: const TextStyle(fontSize: 12)),
              ),
            ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _tables.length,
                itemBuilder: (context, index) {
                  final table = _tables[index];
                  final rows = _tableData[table] ?? [];
                  return _TableSection(table: table, rows: rows);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TableSection extends StatelessWidget {
  final String table;
  final List<Map<String, dynamic>> rows;

  const _TableSection({required this.table, required this.rows});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        table,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      subtitle: Text('${rows.length} row(s)'),
      initiallyExpanded: rows.isNotEmpty && rows.length <= 5,
      children: [
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('(empty)', style: TextStyle(color: Colors.grey)),
          )
        else
          ...rows.asMap().entries.map((e) {
            final i = e.key;
            final row = e.value;
            if (row.containsKey('__error__')) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    row['__error__'] as String,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              );
            }
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Row ${i + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...row.entries.map((entry) {
                      final val = entry.value;
                      final str = val == null
                          ? 'null'
                          : val is String
                              ? (val.length > 200 ? '${val.substring(0, 200)}...' : val)
                              : val.toString();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 140,
                              child: Text(
                                '${entry.key}:',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Expanded(
                              child: SelectableText(
                                str,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
