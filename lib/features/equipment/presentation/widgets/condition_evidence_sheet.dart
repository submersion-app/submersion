import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/condition_evidence_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/exposure_thresholds_provider.dart';
import 'package:submersion/features/equipment/presentation/utils/condition_finding_text.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The dives a finding was built from: the sentence, then one row per dive
/// with its number, date, depth and bottom time in the diver's units.
/// Tapping a row opens the dive.
Future<void> showConditionEvidenceSheet(
  BuildContext context, {
  required EquipmentItem equipment,
  required EquipmentFinding finding,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: _EvidenceSheet(equipment: equipment, finding: finding),
    ),
  );
}

class _EvidenceSheet extends ConsumerWidget {
  final EquipmentItem equipment;
  final EquipmentFinding finding;

  const _EvidenceSheet({required this.equipment, required this.finding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final thresholds = ref.watch(exposureThresholdsProvider);
    final divesAsync = ref.watch(
      conditionEvidenceDivesProvider((
        equipmentId: equipment.id,
        findingId: finding.id,
      )),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              l10n.equipmentCondition_evidence_title,
              style: theme.textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              conditionFindingTitle(
                finding,
                l10n,
                units,
                thresholds: thresholds,
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: divesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              // A localized retry line: the raw exception is neither
              // translated nor something a diver can act on.
              error: (_, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(context.l10n.common_error_tryAgain),
              ),
              data: (dives) => ListView(
                shrinkWrap: true,
                children: [
                  for (final dive in dives)
                    ListTile(
                      title: Text(_diveTitle(context, dive)),
                      subtitle: Text(_diveSubtitle(context, units, dive)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // Both looked up before the pop: the sheet's
                        // context is on its way out once the route pops.
                        final router = GoRouter.of(context);
                        Navigator.of(context).pop();
                        router.push('/dives/${dive.id}');
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _diveTitle(BuildContext context, DiveSummary dive) {
    final number = dive.diveNumber;
    return number == null
        ? context.l10n.equipmentCondition_evidence_unnumbered
        : context.l10n.equipmentCondition_evidence_dive(number);
  }

  String _diveSubtitle(
    BuildContext context,
    UnitFormatter units,
    DiveSummary dive,
  ) {
    final parts = <String>[units.formatDate(dive.dateTime)];
    if (dive.maxDepth != null) parts.add(units.formatDepth(dive.maxDepth));
    final minutes = dive.bottomTime?.inMinutes;
    if (minutes != null) {
      parts.add(context.l10n.equipmentCondition_evidence_minutes(minutes));
    }
    return parts.join(' · ');
  }
}
