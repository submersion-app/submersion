import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/observation_tag_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the diver chose in [showIncidentCheckInPicker]. A dismissed dialog
/// returns null, which a bare nullable id could not tell apart from None.
sealed class IncidentCheckInChoice {
  const IncidentCheckInChoice();
}

class IncidentCheckInNone extends IncidentCheckInChoice {
  const IncidentCheckInNone();
}

class IncidentCheckInAddNew extends IncidentCheckInChoice {
  const IncidentCheckInAddNew();
}

class IncidentCheckInPicked extends IncidentCheckInChoice {
  final EquipmentObservation observation;
  const IncidentCheckInPicked(this.observation);
}

/// Offers None, [checkIns] with those on [diveId] first, and Add check-in.
Future<IncidentCheckInChoice?> showIncidentCheckInPicker(
  BuildContext context, {
  required List<EquipmentObservation> checkIns,
  String? diveId,
}) {
  final l10n = context.l10n;
  final onDive = [
    for (final o in checkIns)
      if (diveId != null && o.diveId == diveId) o,
  ];
  final others = [
    for (final o in checkIns)
      if (diveId == null || o.diveId != diveId) o,
  ];
  return showDialog<IncidentCheckInChoice>(
    context: context,
    builder: (dialogContext) {
      SimpleDialogOption option(IncidentCheckInChoice choice, Widget child) =>
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(choice),
            child: child,
          );
      Widget row(EquipmentObservation o) =>
          option(IncidentCheckInPicked(o), _CheckInLabel(observation: o));
      return SimpleDialog(
        title: Text(l10n.incidentEdit_checkIn),
        children: [
          option(
            const IncidentCheckInNone(),
            Text(l10n.incidentEdit_equipment_none),
          ),
          if (onDive.isNotEmpty) ...[
            IncidentPickerHeader(l10n.incidentEdit_equipment_onThisDive),
            ...onDive.map(row),
          ],
          if (others.isNotEmpty) ...[
            // Only a heading when something sits above it to tell apart.
            if (onDive.isNotEmpty)
              IncidentPickerHeader(l10n.incidentEdit_checkIn_others),
            ...others.map(row),
          ],
          option(
            const IncidentCheckInAddNew(),
            Text(l10n.equipmentObservation_sheet_add),
          ),
        ],
      );
    },
  );
}

/// A section heading inside one of the near-miss form's pickers.
class IncidentPickerHeader extends StatelessWidget {
  final String text;
  const IncidentPickerHeader(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

/// The near-miss form's Gear check-in row. Shows the linked check-in, or None
/// while there is none, it has not loaded, or it can no longer be linked: the
/// sheet the form opens can delete a check-in or save it as OK, and a sync can
/// delete one.
class IncidentCheckInRow extends ConsumerWidget {
  final String? observationId;
  final VoidCallback onTap;

  const IncidentCheckInRow({
    required this.observationId,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final id = observationId;
    final observation = id == null
        ? null
        : ref.watch(observationProvider(id)).valueOrNull;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.fact_check_outlined),
      title: Text(l10n.incidentEdit_checkIn),
      subtitle: observation != null && observation.isIssue
          ? _CheckInLabel(observation: observation)
          : Text(l10n.incidentEdit_equipment_none),
      onTap: onTap,
    );
  }
}

/// What the check-in found and the day it was made.
class _CheckInLabel extends ConsumerWidget {
  final EquipmentObservation observation;
  const _CheckInLabel({required this.observation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    return Text(
      '${observation.displayTitle(l10n)}, '
      '${units.formatDate(observation.observedAt)}',
    );
  }
}
