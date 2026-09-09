import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Simple picker listing the dive's other tanks for a series reassignment.
/// Shared by the data-quality inbox repair and the cylinders card sheet.
Future<String?> showReassignTankPicker(
  BuildContext context,
  WidgetRef ref, {
  required String diveId,
  required String excludeTankId,
}) async {
  final dive = await ref.read(diveProvider(diveId).future);
  if (dive == null || !context.mounted) return null;
  final candidates = dive.tanks.where((t) => t.id != excludeTankId).toList();
  if (candidates.isEmpty) return null;
  return showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(context.l10n.dataQuality_repairLabel_reassignSeries),
      children: [
        for (final t in candidates)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(t.id),
            child: Text(t.name ?? 'Tank ${t.order + 1}'),
          ),
      ],
    ),
  );
}
