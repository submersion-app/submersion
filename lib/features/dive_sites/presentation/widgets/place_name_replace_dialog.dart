import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Asks whether Look up's [differing] place names (field label to found
/// value) replace the ones shown: true for Replace, false for Keep or a
/// dismissed dialog. The site page's Location card and the merge page both
/// ask it (issue #4084).
Future<bool> confirmPlaceNameReplace(
  BuildContext context,
  Map<String, String> differing,
) async {
  final l10n = context.l10n;
  final replace = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.diveSites_edit_lookupReplace_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.diveSites_edit_lookupReplace_body),
          const SizedBox(height: 8),
          for (final entry in differing.entries)
            Text('${entry.key}: ${entry.value}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.diveSites_edit_lookupReplace_keep),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.diveSites_edit_lookupReplace_replace),
        ),
      ],
    ),
  );
  return replace ?? false;
}
