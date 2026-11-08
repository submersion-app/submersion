import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Asks before a finding makes another data source the dive's primary one.
///
/// The repair rewrites which recording the dive's depth, duration and profile
/// come from and has no snackbar undo (it is set back from the dive's data
/// sources), so it names the source and waits for a yes (issue #4209).
/// [source] is the source's label, or null when no name is known. Resolves
/// to true only on the confirm button.
Future<bool> confirmSetPrimarySource(
  BuildContext context, {
  required String? source,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final l10n = context.l10n;
      return AlertDialog(
        title: Text(
          source == null
              ? l10n.dataQuality_repairLabel_setPrimary
              : l10n.dataQuality_setPrimary_title(source),
        ),
        content: Text(
          source == null
              ? l10n.dataQuality_setPrimary_bodyUnnamed
              : l10n.dataQuality_setPrimary_body(source),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.dataQuality_setPrimary_confirm),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
