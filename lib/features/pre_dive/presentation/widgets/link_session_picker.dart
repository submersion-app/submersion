import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Picks the checklist run to attach to a dive (#1066), from the dive's own
/// overflow menu. Only runs not already attached to another dive are offered,
/// scoped to [diverId] exactly, the same boundary the automatic linker keeps.
/// Returns the chosen session id, or null when the diver dismissed the picker.
Future<String?> showLinkSessionPicker(BuildContext context, {String? diverId}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _LinkSessionPicker(diverId: diverId),
  );
}

class _LinkSessionPicker extends ConsumerWidget {
  final String? diverId;

  const _LinkSessionPicker({required this.diverId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sessions = ref.watch(preDiveUnlinkedSessionsProvider(diverId));

    return AlertDialog(
      title: Text(l10n.preDive_link_linkChecklist),
      content: SizedBox(
        width: 420,
        height: 360,
        child: sessions.when(
          data: (runs) => runs.isEmpty
              ? Center(child: Text(l10n.preDive_link_noUnlinkedSessions))
              : _SessionList(sessions: runs),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
      ],
    );
  }
}

class _SessionList extends StatelessWidget {
  final List<PreDiveSession> sessions;

  const _SessionList({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final materialL10n = MaterialLocalizations.of(context);

    return ListView.builder(
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        // Runs are audit records: the time they were run is what identifies
        // one CCR build check from the evening before against another.
        final when = session.completedAt ?? session.startedAt;

        return ListTile(
          dense: true,
          leading: Icon(switch (session.status) {
            PreDiveSessionStatus.inProgress => Icons.pending_outlined,
            PreDiveSessionStatus.completed => Icons.check_circle_outline,
            PreDiveSessionStatus.aborted => Icons.cancel_outlined,
          }),
          title: Text(session.templateName),
          subtitle: Text(
            '${materialL10n.formatMediumDate(when)} - '
            '${TimeOfDay.fromDateTime(when).format(context)}',
          ),
          onTap: () => Navigator.of(context).pop(session.id),
        );
      },
    );
  }
}
