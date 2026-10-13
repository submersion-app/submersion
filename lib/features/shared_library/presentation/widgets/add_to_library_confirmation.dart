import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Before personal sites join a shared site library (issue #2567): what
/// every member will see, and what stays the diver's own. True to add.
Future<bool> confirmAddToLibrary(
  BuildContext context, {
  required String libraryName,
  required int siteCount,
  String? siteName,
}) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        siteCount == 1 && siteName != null
            ? l10n.sharedLibrary_add_confirm_title(siteName, libraryName)
            : l10n.sharedLibrary_add_confirm_titleMany(siteCount, libraryName),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.sharedLibrary_add_confirm_shared),
          const SizedBox(height: 12),
          Text(l10n.sharedLibrary_add_confirm_private),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(
            MaterialLocalizations.of(dialogContext).cancelButtonLabel,
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.sharedLibrary_add_confirm_action),
        ),
      ],
    ),
  );
  return ok ?? false;
}
