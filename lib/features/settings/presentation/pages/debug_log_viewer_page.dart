import 'package:flutter/material.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/debug_mode_provider.dart';
import 'package:submersion/features/settings/presentation/widgets/log_entry_tile.dart';
import 'package:submersion/features/settings/presentation/widgets/log_filter_bar.dart';

/// Full-screen debug log viewer with filtering and export capabilities.
class DebugLogViewerPage extends ConsumerStatefulWidget {
  const DebugLogViewerPage({super.key});

  @override
  ConsumerState<DebugLogViewerPage> createState() => _DebugLogViewerPageState();
}

class _DebugLogViewerPageState extends ConsumerState<DebugLogViewerPage> {
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredEntriesAsync = ref.watch(filteredLogEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search logs...',
                  border: InputBorder.none,
                ),
                onChanged: (query) {
                  ref.read(logFilterProvider.notifier).setSearchQuery(query);
                },
              )
            : const Text('Debug Logs'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  ref.read(logFilterProvider.notifier).setSearchQuery('');
                }
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'disable':
                  ref.read(debugModeProvider.notifier).disable();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                case 'clear':
                  await ref.read(logFileServiceProvider).clearLog();
                  ref.invalidate(logEntriesProvider);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'disable',
                child: Text('Disable Debug Mode'),
              ),
              const PopupMenuItem(value: 'clear', child: Text('Clear Logs')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const LogFilterBar(),
          const Divider(height: 1),
          Expanded(
            child: filteredEntriesAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return const Center(
                    child: Text('No log entries match the current filters'),
                  );
                }
                return ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    return LogEntryTile(entry: entries[index]);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Error loading logs: $error')),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildActionBar(context, filteredEntriesAsync),
    );
  }

  Widget _buildActionBar(
    BuildContext context,
    AsyncValue<List<LogEntry>> filteredEntriesAsync,
  ) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final service = ref.read(logFileServiceProvider);
                  await shareLogFile(service);
                },
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Share'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final entries = filteredEntriesAsync.valueOrNull;
                  if (entries != null && entries.isNotEmpty) {
                    await copyFilteredLogs(entries);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Filtered logs copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final service = ref.read(logFileServiceProvider);
                  final path = await saveLogFile(service);
                  if (path != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Logs saved to $path'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.save_alt, size: 18),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
