import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Asks whether an edit of one fill of a twin set fill (issue #4242) also
/// goes on [partnerName]'s fill. True for both, false for only this one,
/// null when the diver backs out. Yes is the default: most corrections are
/// typos made when the fill was entered once.
Future<bool?> askApplyToTiedFill(BuildContext context, String partnerName) {
  final l10n = context.l10n;
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: Text(l10n.passport_logFill_applyToTied(partnerName)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.forms_cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.passport_logFill_onlyThisOne),
        ),
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.passport_logFill_applyBoth),
        ),
      ],
    ),
  );
}

/// Warns that a twin fill's pressure [pressure] is above [name]'s working
/// pressure [workingPressure], already formatted in the diver's unit. True
/// when the diver saves anyway: the log records what happened.
Future<bool> confirmOverPressure(
  BuildContext context, {
  required String pressure,
  required String name,
  required String workingPressure,
}) async {
  final l10n = context.l10n;
  final go = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.passport_logFill_overPressureTitle),
      content: Text(
        l10n.passport_logFill_overPressureBody(pressure, name, workingPressure),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.passport_logFill_back),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.passport_logFill_saveAnyway),
        ),
      ],
    ),
  );
  return go ?? false;
}
