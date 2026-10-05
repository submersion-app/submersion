import 'package:flutter/material.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_comparison.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_device_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Whether "Keep both" can really make a copy. `SyncService.resolveConflict`
/// copies the remote row under a new id only for a non-deleted record with
/// its own `id`, outside `settings`; anywhere else it keeps the local row, so
/// offering it would promise a copy that is never made.
bool canKeepBoth(SyncConflict conflict) =>
    conflict.entityType != 'settings' &&
    conflict.remoteData['_deleted'] != true &&
    conflict.localData.isNotEmpty &&
    conflict.remoteData['id'] != null;

/// What the selected choice keeps and discards, in one sentence.
String conflictConsequence({
  required AppLocalizations l10n,
  required ConflictComparison comparison,
  required ConflictDeviceLabels devices,
  required ConflictResolution? choice,
}) {
  if (choice == null) return l10n.settings_conflict_chooseVersion;
  final keepLocal = choice != ConflictResolution.keepRemote;
  switch (comparison.state) {
    case ConflictComparisonState.sameContent:
      return l10n.settings_conflict_consequence_nothingLost;
    case ConflictComparisonState.remoteDeleted:
      return keepLocal
          ? l10n.settings_conflict_consequence_keepRecord(devices.local)
          : l10n.settings_conflict_consequence_deleteHere;
    case ConflictComparisonState.localDeleted:
      return keepLocal
          ? l10n.settings_conflict_consequence_staysDeleted
          : l10n.settings_conflict_consequence_keepRecord(devices.remote);
    case ConflictComparisonState.differing:
      if (choice == ConflictResolution.keepBoth) {
        return l10n.settings_conflict_consequence_keepBoth(
          devices.local,
          devices.remote,
        );
      }
      final fields = comparison.differences.map((d) => d.label).join(', ');
      return keepLocal
          ? l10n.settings_conflict_consequence_keep(
              devices.local,
              devices.remote,
              fields,
            )
          : l10n.settings_conflict_consequence_keep(
              devices.remote,
              devices.local,
              fields,
            );
  }
}

/// The line under the resolution chips.
class ConflictChoiceConsequence extends StatelessWidget {
  const ConflictChoiceConsequence({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
