import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/syntax/query_printer.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/features/query/presentation/providers/saved_query_providers.dart';
import 'package:submersion/features/query/presentation/widgets/save_query_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/fab_clearance.dart';

/// Settings > Manage > Saved queries (spec Unit 7): rename, reorder and
/// delete. Rows this build cannot read are flagged, never hidden, so they
/// can be deleted. Queries are created from the editor, so there is no add
/// button here.
class SavedQueriesPage extends ConsumerWidget {
  const SavedQueriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadsAsync = ref.watch(savedQueryLoadsProvider(null));
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.savedQueries_appBar_title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: context.l10n.common_action_back,
        ),
      ),
      body: loadsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('${context.l10n.common_label_error}: $e')),
        data: (loads) => loads.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    context.l10n.savedQueries_empty,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : _SavedQueryList(loads: loads),
      ),
    );
  }
}

class _SavedQueryList extends ConsumerStatefulWidget {
  const _SavedQueryList({required this.loads});

  final List<SavedQueryLoad> loads;

  @override
  ConsumerState<_SavedQueryList> createState() => _SavedQueryListState();
}

class _SavedQueryListState extends ConsumerState<_SavedQueryList> {
  /// A local copy so a dropped row does not snap back while the write and
  /// the tick catch up (the components card pattern).
  late List<SavedQueryLoad> _loads = List.of(widget.loads);

  @override
  void didUpdateWidget(_SavedQueryList old) {
    super.didUpdateWidget(old);
    if (old.loads != widget.loads) _loads = List.of(widget.loads);
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    setState(() {
      final moved = _loads.removeAt(oldIndex);
      _loads.insert(newIndex, moved);
    });
    try {
      await ref.read(savedQueryRepositoryProvider).reorder([
        for (final l in _loads) l.saved.id,
      ]);
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${context.l10n.common_label_error}: $e'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(queryUnitPrefsProvider);
    return ReorderableListView.builder(
      padding: kFabListPadding,
      buildDefaultDragHandles: false,
      itemCount: _loads.length,
      onReorderItem: _reorder,
      itemBuilder: (context, i) => _tile(context, _loads[i], i, prefs),
    );
  }

  Widget _tile(
    BuildContext context,
    SavedQueryLoad load,
    int index,
    UnitPrefs prefs,
  ) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final subject = load.saved.querySubject;
    final Widget subtitle = switch (load.problem) {
      null => Text(
        QueryPrinter(
          appQueryRegistry,
          appQueryRegistry.entityFor(subject!),
          prefs,
        ).print(load.node),
        style: const TextStyle(fontFamily: 'monospace'),
      ),
      SavedQueryProblem.unresolvedRef => Text(
        l10n.savedQueries_problem_unresolved(load.detail ?? ''),
        style: TextStyle(color: theme.colorScheme.tertiary),
      ),
      SavedQueryProblem.unreadable => Text(
        l10n.savedQueries_problem_unreadable,
        style: TextStyle(color: theme.colorScheme.error),
      ),
      SavedQueryProblem.invalid => Text(
        l10n.savedQueries_problem_invalid(load.detail ?? ''),
        style: TextStyle(color: theme.colorScheme.error),
      ),
      SavedQueryProblem.unknownSubject => Text(
        l10n.savedQueries_problem_unknownSubject(load.detail ?? ''),
        style: TextStyle(color: theme.colorScheme.error),
      ),
    };
    final flagged =
        load.problem != null && load.problem != SavedQueryProblem.unresolvedRef;
    return ListTile(
      key: ValueKey(load.saved.id),
      leading: Icon(
        flagged ? Icons.error_outline : Icons.bookmark_outline,
        color: flagged ? theme.colorScheme.error : theme.colorScheme.primary,
      ),
      title: Text(load.saved.name),
      subtitle: subtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.savedQueries_renameTooltip,
            onPressed: () => _rename(load),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.savedQueries_deleteTooltip,
            onPressed: () => _confirmDelete(load),
          ),
          ReorderableDragStartListener(
            index: index,
            child: Tooltip(
              message: l10n.savedQueries_reorderTooltip,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.drag_handle),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(SavedQueryLoad load) async {
    final name = await showSaveQueryDialog(
      context,
      initialName: load.saved.name,
    );
    if (name == null || name == load.saved.name) return;
    try {
      await ref.read(savedQueryRepositoryProvider).rename(load.saved.id, name);
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  Future<void> _confirmDelete(SavedQueryLoad load) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.savedQueries_deleteDialog_title),
        content: Text(l10n.savedQueries_deleteDialog_content(load.saved.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.common_action_delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(savedQueryRepositoryProvider).delete(load.saved.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.savedQueries_snackbar_deleted(load.saved.name)),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError(e);
    }
  }
}
