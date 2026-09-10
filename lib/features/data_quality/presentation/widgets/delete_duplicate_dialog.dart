import 'package:flutter/material.dart';

import 'package:submersion/features/data_quality/domain/entities/diver_data_summary.dart';
import 'package:submersion/features/data_quality/presentation/widgets/dive_identity_label.dart';
import 'package:submersion/features/data_quality/presentation/widgets/diver_data_description.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Confirms a delete-duplicate repair by naming both dives: the one that
/// survives and the one about to go. Resolves true only on the destructive
/// button; dismissing the dialog any other way resolves null.
///
/// The dives are named the way the inbox names them everywhere else (number,
/// site or name, when, then depth and duration), so the diver is confirming
/// a dive they can recognise rather than an id.
///
/// [carries] is what the doomed copy holds of the diver's own work, which the
/// delete takes with it through the FK cascade. Named under the red line when
/// there is any, absent when there is none or when the dive could not be read
/// (#1729). The detector already refuses to name a copy carrying the diver's
/// work as the redundant one (#1720); this is what stands between the diver
/// and the delete if that ever stops holding.
Future<bool?> showDeleteDuplicateDialog(
  BuildContext context, {
  required DiveIdentityLabel? keep,
  required DiveIdentityLabel? delete,
  required DiverDataSummary? carries,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      final l10n = context.l10n;
      final scheme = Theme.of(context).colorScheme;
      final body = Theme.of(context).textTheme.bodyMedium;
      final carried = describeDiverData(carries, l10n);
      String describe(DiveIdentityLabel? label) {
        if (label == null) return l10n.dataQuality_dive_unknown;
        final stats = label.stats;
        return stats == null
            ? label.headline
            : '${label.headline}$kDiveIdentitySeparator$stats';
      }

      return AlertDialog(
        title: Text(l10n.dataQuality_deleteDuplicate_title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.dataQuality_deleteDuplicate_body),
            const SizedBox(height: 16),
            Text(
              l10n.dataQuality_deleteDuplicate_keep(describe(keep)),
              style: body,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.dataQuality_deleteDuplicate_delete(describe(delete)),
              style: body?.copyWith(color: scheme.error),
            ),
            // Detail, not a second warning: the red line above is the alarm,
            // and colouring this too would drown it.
            if (carried != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.dataQuality_deleteDuplicate_carries(carried),
                style: body,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            child: Text(l10n.common_action_delete),
          ),
        ],
      );
    },
  );
}
