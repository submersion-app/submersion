import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/domain/services/checklist_session_engine.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/features/pre_dive/presentation/widgets/start_session_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Pre-dive checklist sessions: any in-progress run pinned on top with
/// Resume, then history with status badges and linked-dive chips.
class PreDiveSessionsPage extends ConsumerWidget {
  const PreDiveSessionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sessionsAsync = ref.watch(preDiveSessionsProvider);
    final sessions = sessionsAsync.value;
    final active = ref.watch(preDiveActiveSessionProvider).value;

    final history = sessions == null
        ? null
        : [
            for (final s in sessions)
              if (s.id != active?.id) s,
          ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.preDive_sessions_title)),
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
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                if (active != null) _ActiveSessionCard(session: active),
                if (history != null && history.isEmpty && active == null)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(child: Text(l10n.preDive_sessions_empty)),
                  ),
                if (history != null)
                  for (final session in history) _SessionTile(session: session),
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
    final items = ref.watch(preDiveSessionItemsProvider(session.id)).value;
    final resolved = items == null
        ? 0
        : ChecklistSessionEngine.resolvedCount(items);
    final total = items?.length ?? 0;

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
    final items = ref.watch(preDiveSessionItemsProvider(session.id)).value;
    final flagged = items == null
        ? 0
        : ChecklistSessionEngine.flaggedCount(items);
    final startedDate = MaterialLocalizations.of(
      context,
    ).formatMediumDate(session.startedAt);

    return ListTile(
      leading: Icon(switch (session.status) {
        PreDiveSessionStatus.inProgress => Icons.pending_outlined,
        PreDiveSessionStatus.completed => Icons.check_circle_outline,
        PreDiveSessionStatus.aborted => Icons.cancel_outlined,
      }),
      title: Text(session.templateName),
      subtitle: Text(
        [
          startedDate,
          _statusLabel(context),
          if (flagged > 0) l10n.preDive_runner_flaggedBadge(flagged),
        ].join(' - '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (session.diveId != null)
            ActionChip(
              avatar: const Icon(Icons.scuba_diving, size: 18),
              label: Text(l10n.preDive_sessions_linkedDive),
              visualDensity: VisualDensity.compact,
              onPressed: () => context.push('/dives/${session.diveId}'),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') _confirmDelete(context, ref);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Text(l10n.preDive_sessions_delete),
              ),
            ],
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
