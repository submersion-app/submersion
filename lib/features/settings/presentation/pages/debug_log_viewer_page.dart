import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/share_anchor.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/debug_mode_provider.dart';
import 'package:submersion/features/settings/presentation/widgets/log_entry_tile.dart';
import 'package:submersion/features/settings/presentation/widgets/log_filter_bar.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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
                decoration: InputDecoration(
                  hintText: context.l10n.settings_debugLog_search_hint,
                  border: InputBorder.none,
                ),
                onChanged: (query) {
                  ref
                      .read(logFilterNotifierProvider.notifier)
                      .setSearchQuery(query);
                },
              )
            : Text(context.l10n.settings_debugLog_appBar_title),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  ref
                      .read(logFilterNotifierProvider.notifier)
                      .setSearchQuery('');
                }
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'disable':
                  await ref.read(debugModeNotifierProvider.notifier).disable();
                  if (context.mounted) {
                    context.go('/settings');
                  }
                case 'clear':
                  await ref.read(logFileServiceProvider).clearLog();
                  ref.invalidate(logEntriesProvider);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'disable',
                child: Text(context.l10n.settings_debugLog_disableDebugMode),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Text(context.l10n.settings_debugLog_clearLogs),
              ),
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
                  return Center(
                    child: Text(context.l10n.settings_debugLog_empty),
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
              error: (error, _) => Center(
                child: Text(context.l10n.settings_debugLog_loadError(error)),
              ),
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
              // Builder so the iPad share popover anchors to this button;
              // shareLogFile lives in the provider layer and has no context.
              child: Builder(
                builder: (buttonContext) => OutlinedButton.icon(
                  onPressed: () async {
                    final l10n = context.l10n;
                    final service = ref.read(logFileServiceProvider);
                    await shareLogFile(
                      service,
                      l10n,
                      sharePositionOrigin: shareAnchorFrom(buttonContext),
                    );
                  },
                  icon: const Icon(Icons.share, size: 18),
                  label: Text(context.l10n.common_action_share),
                ),
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
                        SnackBar(
                          content: Text(
                            context.l10n.settings_debugLog_copiedSnack,
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.copy, size: 18),
                label: Text(context.l10n.common_action_copy),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final l10n = context.l10n;
                  final service = ref.read(logFileServiceProvider);
                  final path = await saveLogFile(service, l10n);
                  if (path != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.settings_debugLog_savedSnack(path)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.save_alt, size: 18),
                label: Text(context.l10n.common_action_save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
