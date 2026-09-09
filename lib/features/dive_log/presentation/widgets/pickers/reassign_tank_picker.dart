import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Simple picker listing the dive's other tanks for a series reassignment.
/// Shared by the data-quality inbox repair and the cylinders card sheet.
///
/// Only tanks attributed to the same computer as the source are offered:
/// re-parse keys an explicit source index on `(computerId, index)`, so a
/// series moved onto another computer's row, or onto an unattributed manual
/// row, would be handed back to a fresh row on the next re-parse.
Future<String?> showReassignTankPicker(
  BuildContext context,
  WidgetRef ref, {
  required String diveId,
  required String excludeTankId,
}) async {
  final dive = await ref.read(diveProvider(diveId).future);
  if (dive == null || !context.mounted) return null;
  final source = dive.tanks.where((t) => t.id == excludeTankId).firstOrNull;
  final candidates = dive.tanks
      .where((t) => t.id != excludeTankId)
      .where((t) => source == null || t.computerId == source.computerId)
      .toList();
  if (candidates.isEmpty) return null;
  return showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(context.l10n.dataQuality_repairLabel_reassignSeries),
      children: [
        for (final t in candidates)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(t.id),
            child: Text(
              t.name != null && t.name!.isNotEmpty
                  ? t.name!
                  : context.l10n.diveLog_tank_title(t.order + 1),
            ),
          ),
      ],
    ),
  );
}
