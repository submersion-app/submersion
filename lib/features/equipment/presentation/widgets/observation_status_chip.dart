import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_observation_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The trailing chip on a dive's gear row: nothing recorded, checked OK,
/// or an issue. Tapping opens the check-in sheet for (item, dive).
class ObservationStatusChip extends ConsumerWidget {
  final EquipmentItem equipment;
  final Dive dive;

  /// Shows the state only: no tap, as on a dive page that is locked
  /// (issue #4527). A check-in writes, so it waits for the unlock.
  final bool readOnly;

  /// Why a check-in is unavailable on a dive page that offers editing: it
  /// writes at once, so it is a whole-record operation (issue #4527). The
  /// chip keeps its colour and says why as its tooltip.
  final String? operationReason;

  /// Runs the check-in as the page's whole-record operation, so the page
  /// holds still while the sheet is open and reads the dive again after.
  /// Null opens the sheet directly, as off such a page.
  final Future<void> Function(Future<bool> Function() operation)?
  runAsOperation;

  const ObservationStatusChip({
    super.key,
    required this.equipment,
    required this.dive,
    this.readOnly = false,
    this.operationReason,
    this.runAsOperation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final mine = [
      for (final o
          in ref.watch(observationsForDiveProvider(dive.id)).value ??
              const <EquipmentObservation>[])
        if (o.equipmentId == equipment.id) o,
    ];
    final (IconData icon, Color color, String tooltip) = mine.isEmpty
        ? (
            Icons.add_task,
            scheme.onSurfaceVariant,
            l10n.equipmentObservation_chip_none,
          )
        : mine.any((o) => o.isIssue)
        ? (
            Icons.warning_amber,
            scheme.error,
            l10n.equipmentObservation_chip_issue,
          )
        : (
            Icons.check_circle,
            scheme.tertiary,
            l10n.equipmentObservation_chip_ok,
          );
    final button = IconButton(
      icon: Icon(icon, color: color, size: 20),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      // Read-only keeps the chip's colour: it still says how the gear did.
      disabledColor: color,
      onPressed: readOnly || operationReason != null
          ? null
          : () {
              Future<bool> checkIn() async {
                await showEquipmentObservationSheet(
                  context,
                  equipment: equipment,
                  dive: dive,
                );
                return true;
              }

              final run = runAsOperation;
              run == null ? checkIn() : run(checkIn);
            },
    );
    if (operationReason case final reason?) {
      return Tooltip(message: reason, child: button);
    }
    if (!readOnly) return button;
    // Read-only is a state, not a dimmed button: a check made is read out
    // as text, and "Check in", an action the locked page does not offer,
    // is not read out at all.
    return mine.isEmpty
        ? ExcludeSemantics(child: button)
        : Semantics(label: tooltip, excludeSemantics: true, child: button);
  }
}
