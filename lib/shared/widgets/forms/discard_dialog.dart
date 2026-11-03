import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Asks whether to throw away unsaved changes. True means discard.
Future<bool> showDiscardDialog(BuildContext context) async {
  final l10n = context.l10n;
  final discard = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.forms_discard_title),
      content: Text(l10n.forms_discard_body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.forms_discard_keepEditing),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.forms_discard_discard),
        ),
      ],
    ),
  );
  return discard == true;
}
