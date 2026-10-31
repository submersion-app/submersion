import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the change log filtered to one record.
void openChangeLogHistory(
  BuildContext context, {
  required String rootTable,
  required String rootId,
}) {
  context.push(
    Uri(
      path: '/settings/change-log',
      queryParameters: {'rootTable': rootTable, 'rootId': rootId},
    ).toString(),
  );
}

/// The History item of a record's overflow menu. It carries its own [onTap]
/// and no value, so a menu's `onSelected` needs no case for it.
PopupMenuItem<T> changeLogHistoryMenuItem<T>(
  BuildContext context, {
  required String rootTable,
  required String rootId,
}) => PopupMenuItem<T>(
  onTap: () =>
      openChangeLogHistory(context, rootTable: rootTable, rootId: rootId),
  child: Row(
    children: [
      const Icon(Icons.history),
      const SizedBox(width: 12),
      Text(context.l10n.changeLog_history),
    ],
  ),
);
