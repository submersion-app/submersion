import 'package:flutter/material.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_comparison.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_device_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Whether "Keep both" should be offered: only where resolving with it
/// really makes a copy (the service's own rule), and not when the versions
/// match, where the copy would duplicate an unchanged record.
bool canKeepBoth(ConflictComparison comparison, SyncConflict conflict) =>
    comparison.state != ConflictComparisonState.sameContent &&
    conflict.localData.isNotEmpty &&
    SyncService.keepBothMakesCopy(conflict.entityType, conflict.remoteData);

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
      final fields = _fieldList(l10n, comparison);
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

/// Field labels for the consequence line. A record can disagree on dozens of
/// columns, and the line sits outside the scrolling area, so it names the
/// first few and counts the rest.
const _namedFields = 3;

String _fieldList(AppLocalizations l10n, ConflictComparison comparison) {
  final labels = [for (final d in comparison.differences) d.label];
  if (labels.length <= _namedFields + 1) return labels.join(', ');
  return l10n.settings_conflict_moreFields(
    labels.take(_namedFields).join(', '),
    labels.length - _namedFields,
  );
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
