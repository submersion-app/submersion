import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Asks before a data source is removed from a dive with its readings
/// (issue #4393). Shared by the dive's Data Sources menu and the data
/// quality inbox's Remove source repair. [source] is the source's label, or
/// null when no name is known. Resolves to true only on the confirm button.
Future<bool> confirmRemoveSource(
  BuildContext context, {
  required String? source,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final l10n = context.l10n;
      return AlertDialog(
        title: Text(l10n.diveLog_sources_removeDialog_title),
        content: Text(
          source == null
              ? l10n.diveLog_sources_removeDialog_bodyUnnamed
              : l10n.diveLog_sources_removeDialog_body(source),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.diveLog_sources_removeDialog_confirm),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
