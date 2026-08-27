import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/domain/models/pre_dive_session_filter.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/features/pre_dive/presentation/widgets/link_dive_picker.dart';
import 'package:submersion/features/pre_dive/presentation/widgets/pre_dive_session_filter_sheet.dart';
import 'package:submersion/features/pre_dive/presentation/widgets/start_session_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/export_destination_sheet.dart';

/// Pre-dive checklist sessions: any in-progress run pinned on top with
/// Resume, then history with status badges and linked-dive chips.
class PreDiveSessionsPage extends ConsumerWidget {
  const PreDiveSessionsPage({super.key});

  /// Exports whatever the filter currently shows, so the filter doubles as the
  /// export selector. Share and save are a deliberate pair: a null return from
  /// the save path means the diver cancelled, not that the export succeeded.
  ///
  /// [sessions] is resolved by the caller, which knows whether the list has
  /// loaded: a pending or failed load must not reach here and be reported as
  /// "nothing to export".
  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    List<PreDiveSession> sessions,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    if (sessions.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.preDive_sessions_exportEmpty)),
      );
      return;
    }

    final destination = await showExportDestinationSheet(
      context,
      title: l10n.preDive_sessions_export,
    );
    if (destination == null) return;

    final dateFormat = ref.read(settingsProvider).dateFormat;
    final service = ref.read(preDiveExcelExportServiceProvider);

    try {
      final itemsBySession = await ref
          .read(preDiveSessionRepositoryProvider)
          .getItemsForSessions([for (final session in sessions) session.id]);

      switch (destination) {
        case ExportDestination.share:
          await service.exportToExcel(
            sessions: sessions,
            itemsBySession: itemsBySession,
            dateFormat: dateFormat,
          );
        case ExportDestination.saveToFile:
          await service.saveToFile(
            sessions: sessions,
            itemsBySession: itemsBySession,
            dateFormat: dateFormat,
          );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.preDive_sessions_exportFailed(e.toString())),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sessionsAsync = ref.watch(preDiveSessionsProvider);
    final sessions = sessionsAsync.value;
    final filter = ref.watch(preDiveSessionFilterProvider);
    final filtered = ref.watch(filteredPreDiveSessionsProvider).value;
    final active = ref.watch(preDiveActiveSessionProvider).value;

    // The active run stays pinned whatever the filter says: it is a "resume
    // this now" affordance, and a filter left on from an earlier session must
    // not make an unfinished checklist look like it disappeared.
    final history = filtered == null
        ? null
        : [
            for (final s in filtered)
              if (s.id != active?.id) s,
          ];
    final hiddenByFilter =
        filter.hasActiveFilters && (sessions?.isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.preDive_sessions_title),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: filter.hasActiveFilters,
              child: const Icon(Icons.filter_list),
            ),
            tooltip: l10n.preDive_sessions_filter,
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const PreDiveSessionFilterSheet(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.grid_on),
            tooltip: l10n.preDive_sessions_export,
            // Disabled until the list resolves. While it is loading or in
            // error there is nothing meaningful to export, and offering the
            // action would report a pending load as an empty history.
            onPressed: filtered == null
                ? null
                : () => _export(context, ref, filtered),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showStartSessionSheet(context),
        icon: const Icon(Icons.play_arrow),
        label: Text(l10n.preDive_sessions_start),
      ),
      body: sessions == null
          ? Center(
              child: sessionsAsync.hasError
                  ? Text(sessionsAsync.error.toString())
                  : const CircularProgressIndicator(),
            )
          : Column(
              children: [
                if (filter.hasActiveFilters) const _ActiveFilterBar(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 88),
                    children: [
                      if (active != null) _ActiveSessionCard(session: active),
                      if (history != null &&
                          history.isEmpty &&
                          active == null) ...[
                        if (hiddenByFilter)
                          const _FilteredEmptyState()
                        else
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Text(l10n.preDive_sessions_empty),
                            ),
                          ),
                      ],
                      if (history != null)
                        for (final session in history)
                          _SessionTile(session: session),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Dismissible chips for each active facet, so the diver can see and undo the
/// filter without reopening the sheet.
class _ActiveFilterBar extends ConsumerWidget {
  const _ActiveFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filter = ref.watch(preDiveSessionFilterProvider);

    void update(PreDiveSessionFilter next) =>
        ref.read(preDiveSessionFilterProvider.notifier).state = next;

    String statusLabel(PreDiveSessionStatus status) => switch (status) {
      PreDiveSessionStatus.inProgress => l10n.preDive_sessions_statusInProgress,
      PreDiveSessionStatus.completed => l10n.preDive_sessions_statusCompleted,
      PreDiveSessionStatus.aborted => l10n.preDive_sessions_statusAborted,
    };

    final materialL10n = MaterialLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final name in filter.templateNames)
                  Chip(
                    label: Text(name),
                    visualDensity: VisualDensity.compact,
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => update(
                      filter.copyWith(
                        templateNames: {...filter.templateNames}..remove(name),
                      ),
                    ),
                  ),
                for (final status in filter.statuses)
                  Chip(
                    label: Text(statusLabel(status)),
                    visualDensity: VisualDensity.compact,
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => update(
                      filter.copyWith(
                        statuses: {...filter.statuses}..remove(status),
                      ),
                    ),
                  ),
                if (filter.flaggedOnly)
                  Chip(
                    label: Text(l10n.preDive_sessions_filterFlaggedChip),
                    visualDensity: VisualDensity.compact,
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () =>
                        update(filter.copyWith(flaggedOnly: false)),
                  ),
                if (filter.dateRange != null)
                  Chip(
                    label: Text(
                      '${materialL10n.formatMediumDate(filter.dateRange!.start)}'
                      ' - '
                      '${materialL10n.formatMediumDate(filter.dateRange!.end)}',
                    ),
                    visualDensity: VisualDensity.compact,
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () =>
                        update(filter.copyWith(clearDateRange: true)),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => update(const PreDiveSessionFilter()),
            child: Text(l10n.preDive_sessions_filterClearAll),
          ),
        ],
      ),
    );
  }
}

class _FilteredEmptyState extends ConsumerWidget {
  const _FilteredEmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.filter_list_off,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.preDive_sessions_emptyFiltered,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () =>
                ref.read(preDiveSessionFilterProvider.notifier).state =
                    const PreDiveSessionFilter(),
            child: Text(l10n.preDive_sessions_filterClearAll),
          ),
        ],
      ),
    );
  }
}

class _ActiveSessionCard extends ConsumerWidget {
  final PreDiveSession session;

  const _ActiveSessionCard({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final stats =
        ref.watch(preDiveSessionStatsProvider).value?[session.id] ??
        const PreDiveSessionStats();
    final resolved = stats.resolved;
    final total = stats.total;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.templateName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: total == 0 ? 0 : resolved / total,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.preDive_runner_progress(resolved, total)),
                FilledButton(
                  onPressed: () =>
                      context.push('/pre-dive-sessions/${session.id}'),
                  child: Text(l10n.preDive_sessions_resume),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends ConsumerWidget {
  final PreDiveSession session;

  const _SessionTile({required this.session});

  String _statusLabel(BuildContext context) {
    return switch (session.status) {
      PreDiveSessionStatus.inProgress =>
        context.l10n.preDive_sessions_statusInProgress,
      PreDiveSessionStatus.completed =>
        context.l10n.preDive_sessions_statusCompleted,
      PreDiveSessionStatus.aborted =>
        context.l10n.preDive_sessions_statusAborted,
    };
  }

  /// Attaches this run to a dive the diver picks (#1066). The automatic
  /// linker only reaches back three hours from the dive, so a build check run
  /// the evening before is only ever linked by hand.
  Future<void> _link(BuildContext context, WidgetRef ref) async {
    final diveId = await showLinkDivePicker(context);
    if (diveId == null) return;
    await ref
        .read(preDiveSessionRepositoryProvider)
        .linkToDive(session.id, diveId);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.preDive_sessions_delete),
        content: Text(l10n.preDive_sessions_deleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.common_action_delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(preDiveSessionRepositoryProvider)
          .deleteSession(session.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final flagged =
        ref.watch(preDiveSessionStatsProvider).value?[session.id]?.flagged ?? 0;
    final startedDate = MaterialLocalizations.of(
      context,
    ).formatMediumDate(session.startedAt);

    final hasLinkedDive = session.diveId != null;

    // Only fixed-width widgets belong in ListTile.trailing: the tile lays the
    // trailing widget out against the full tile width and gives the title
    // column whatever is left, so a text-bearing chip here starves the title
    // down to one glyph per line in longer locales (issue #935).
    return ListTile(
      leading: Icon(switch (session.status) {
        PreDiveSessionStatus.inProgress => Icons.pending_outlined,
        PreDiveSessionStatus.completed => Icons.check_circle_outline,
        PreDiveSessionStatus.aborted => Icons.cancel_outlined,
      }),
      title: Text(
        session.templateName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: hasLinkedDive,
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              startedDate,
              _statusLabel(context),
              if (flagged > 0) l10n.preDive_runner_flaggedBadge(flagged),
            ].join(' - '),
          ),
          if (hasLinkedDive)
            ActionChip(
              avatar: const Icon(Icons.scuba_diving, size: 18),
              label: Text(l10n.preDive_sessions_linkedDive),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onPressed: () => context.push('/dives/${session.diveId}'),
            ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'link':
              _link(context, ref);
            case 'unlink':
              ref
                  .read(preDiveSessionRepositoryProvider)
                  .unlinkFromDive(session.id);
            case 'delete':
              _confirmDelete(context, ref);
          }
        },
        itemBuilder: (context) => [
          if (hasLinkedDive)
            PopupMenuItem(
              value: 'unlink',
              child: Text(l10n.preDive_link_unlinkDive),
            )
          else
            PopupMenuItem(
              value: 'link',
              child: Text(l10n.preDive_link_linkToDive),
            ),
          PopupMenuItem(
            value: 'delete',
            child: Text(l10n.preDive_sessions_delete),
          ),
        ],
      ),
      onTap: () => context.push('/pre-dive-sessions/${session.id}'),
      textColor: session.status == PreDiveSessionStatus.aborted
          ? theme.colorScheme.onSurfaceVariant
          : null,
    );
  }
}
