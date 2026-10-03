import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_transfer_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_transfer_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';
import 'package:submersion/core/services/logger_service.dart';

const _log = LoggerService('EquipmentBulkTransfer');

/// "Transfer to..." from the item page or the list (issue #2852): asks for
/// the profile, transfers what [activeDiverId] owns and reports the result.
/// `keptAccess` tells the item page whether it can stay open.
Future<({BulkActionOutcome outcome, bool keptAccess})>
transferEquipmentToProfile(
  BuildContext context,
  WidgetRef ref, {
  required List<String> equipmentIds,
  required String? activeDiverId,
}) async {
  const cancelled = (outcome: BulkActionOutcome.cancelled, keptAccess: true);
  if (equipmentIds.isEmpty || activeDiverId == null) return cancelled;
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final divers = await ref.read(allDiversProvider.future);
  final others = [
    for (final d in divers)
      if (d.id != activeDiverId) d,
  ];
  if (!context.mounted || others.isEmpty) return cancelled;
  final request = await showEquipmentTransferDialog(
    context,
    equipmentIds: equipmentIds,
    activeDiverId: activeDiverId,
    profiles: others,
  );
  if (request == null) return cancelled;
  final name = others.firstWhere((d) => d.id == request.toDiverId).name;
  try {
    final result = await ref
        .read(equipmentTransferServiceProvider)
        .transfer(
          equipmentIds: equipmentIds,
          toDiverId: request.toDiverId,
          actingDiverId: activeDiverId,
          keepAccess: request.keepAccess,
          moveRegistry: request.moveRegistry,
        );
    if (messenger.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.skippedNotOwned == 0
                ? l10n.equipment_transfer_done(result.itemsMoved, name)
                : l10n.equipment_transfer_doneSkipped(
                    result.itemsMoved,
                    name,
                    result.skippedNotOwned,
                  ),
          ),
        ),
      );
    }
    return (
      outcome: BulkActionOutcome.completed,
      keptAccess: request.keepAccess,
    );
  } catch (e, stackTrace) {
    _log.warning('Equipment transfer failed', error: e, stackTrace: stackTrace);
    if (messenger.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.common_error_tryAgain)),
      );
    }
    return (outcome: BulkActionOutcome.failed, keptAccess: true);
  }
}
