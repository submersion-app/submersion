import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/presentation/providers/bulk_equipment_tag_provider.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/bulk_tag_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';

/// Edits the tags of the equipment items in [equipmentIds] (issue #1942):
/// the shared bulk tag editor ([showBulkTagSheet]) over equipment tags.
/// Once the diver confirms, the tags go on and come off every item in one
/// transaction, and a SnackBar offers Undo. Returns
/// [BulkActionOutcome.cancelled] when the diver backs out, so the selection
/// survives, and [BulkActionOutcome.failed] when the write throws.
Future<BulkActionOutcome> showBulkEquipmentTagSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<String> equipmentIds,
}) {
  final l10n = context.l10n;
  return showBulkTagSheet(
    context,
    ref,
    scope: TagScope.equipment,
    service: ref.read(bulkEquipmentTagServiceProvider),
    itemIds: equipmentIds,
    keyPrefix: 'bulkEquipmentTags',
    labels: (
      confirmAdding: l10n.equipment_bulkTags_confirmAdding,
      confirmRemoving: l10n.equipment_bulkTags_confirmRemoving,
      empty: l10n.equipment_bulkTags_empty,
    ),
  );
}
