import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Asks before the weights and tanks of the diver's last dive at a center
/// replace the ones a dive already holds (issue #2075). True to replace.
/// Shared by the dive form and the dive page's Details card.
Future<bool> confirmApplyLastDive(BuildContext context) async {
  final l10n = context.l10n;
  final replace = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.diveCenters_rental_applyConfirmTitle),
      content: Text(l10n.diveCenters_rental_applyConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.diveCenters_rental_applyConfirmReplace),
        ),
      ],
    ),
  );
  return replace ?? false;
}
