import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The diver's answer about a picked set's weights.
enum SetWeightsChoice { add, replace, keep }

/// Asks what to do with the weights of set [setName] when the dive already
/// has some (issue #4525). [setTotal] and [currentTotal] are formatted in
/// the diver's unit. Null when the dialog is dismissed, which callers treat
/// as keeping what is there.
Future<SetWeightsChoice?> showSetWeightsChoiceDialog(
  BuildContext context, {
  required String setName,
  required String setTotal,
  required String currentTotal,
}) {
  return showDialog<SetWeightsChoice>(
    context: context,
    builder: (dialogContext) {
      final l10n = dialogContext.l10n;
      return AlertDialog(
        title: Text(l10n.diveLog_edit_setWeights_title(setName)),
        content: Text(
          l10n.diveLog_edit_setWeights_body(currentTotal, setTotal),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(SetWeightsChoice.keep),
            child: Text(l10n.diveLog_edit_setWeights_keep),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(SetWeightsChoice.replace),
            child: Text(l10n.diveLog_edit_setWeights_replace),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(SetWeightsChoice.add),
            child: Text(l10n.diveLog_edit_setWeights_add),
          ),
        ],
      );
    },
  );
}
