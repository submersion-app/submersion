import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/profile_checklist_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';

/// The equipment list's bulk Share action (issue #2046): asks which other
/// profiles get [equipmentIds], shares the ones [activeDiverId] owns and
/// reports how many were shared and how many were skipped.
Future<BulkActionOutcome> shareEquipmentWithProfiles(
  BuildContext context,
  WidgetRef ref, {
  required List<String> equipmentIds,
  required String? activeDiverId,
}) async {
  if (equipmentIds.isEmpty || activeDiverId == null) {
    return BulkActionOutcome.cancelled;
  }
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final divers = await ref.read(allDiversProvider.future);
  final others = [
    for (final d in divers)
      if (d.id != activeDiverId) d,
  ];
  if (!context.mounted) return BulkActionOutcome.cancelled;
  final chosen = await showProfileChecklistDialog(
    context,
    title: l10n.equipment_sharing_dialogTitle,
    body: l10n.equipment_sharing_dialogBody,
    profiles: others,
    initiallySelected: const {},
    confirmLabel: l10n.common_action_share,
    allowEmpty: false,
  );
  if (chosen == null) return BulkActionOutcome.cancelled;
  try {
    final result = await ref
        .read(equipmentShareRepositoryProvider)
        .shareMany(
          equipmentIds: equipmentIds,
          diverIds: chosen.toList(),
          actingDiverId: activeDiverId,
        );
    // The list may have closed while the share ran.
    if (!context.mounted) return BulkActionOutcome.completed;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.skippedNotOwned == 0
              ? l10n.equipment_bulkShare_done(result.itemsChanged)
              : l10n.equipment_bulkShare_doneSkipped(
                  result.itemsChanged,
                  result.skippedNotOwned,
                ),
        ),
      ),
    );
    return BulkActionOutcome.completed;
  } catch (_) {
    if (!context.mounted) return BulkActionOutcome.failed;
    messenger.showSnackBar(SnackBar(content: Text(l10n.common_error_tryAgain)));
    return BulkActionOutcome.failed;
  }
}
