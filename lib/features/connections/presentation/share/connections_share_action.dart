import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/share_anchor.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/export_destination_sheet.dart';

const _log = LoggerService('ConnectionsShare');

typedef ConnectionsShareImage =
    Future<void> Function(List<int> bytes, String fileName, Rect? origin);
typedef ConnectionsSaveImage =
    Future<String?> Function(List<int> bytes, String fileName);

/// The share image's file name, dated so repeated shares do not collide.
/// A file name, not a date shown to the diver, so no unit formatting.
String connectionsShareFileName(DateTime now) =>
    'submersion-connections-${DateFormat('yyyyMMdd').format(now)}.png';

/// Asks share or save, renders the map image, and delivers it. Nothing is
/// uploaded. A dismissed sheet renders nothing; a cancelled save is a no-op;
/// a failure is logged and shown in a snackbar. [anchorContext] is the share
/// button's own context, for the iPad popover.
Future<void> shareConnectionsImage(
  BuildContext context, {
  required Future<Uint8List> Function() render,
  ConnectionsShareImage? share,
  ConnectionsSaveImage? save,
  DateTime? now,
  BuildContext? anchorContext,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  // The iPad popover points at the control that opened it, not the page.
  final origin = shareAnchorFrom(anchorContext ?? context);
  final destination = await showExportDestinationSheet(
    context,
    title: l10n.connections_share_sheetTitle,
  );
  if (destination == null) return;
  try {
    final bytes = await render();
    final name = connectionsShareFileName(now ?? DateTime.now());
    switch (destination) {
      case ExportDestination.share:
        await (share ?? _share)(bytes, name, origin);
      case ExportDestination.saveToFile:
        final saved =
            await (save ?? _saveTitled(l10n.connections_share_saveTitle))(
              bytes,
              name,
            );
        // A cancelled panel returns null and says nothing.
        if (saved != null) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.diveLog_exportImage_savedToFiles)),
          );
        }
    }
  } catch (e, st) {
    _log.error(
      'Could not create the connections image',
      error: e,
      stackTrace: st,
    );
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.connections_share_failed)),
    );
  }
}

Future<void> _share(List<int> bytes, String name, Rect? origin) =>
    saveAndShareFileBytes(
      bytes,
      name,
      'image/png',
      sharePositionOrigin: origin,
    );

/// The default save, with the panel titled for the map.
ConnectionsSaveImage _saveTitled(String title) =>
    (bytes, name) => saveImageToFile(bytes, name, dialogTitle: title);
