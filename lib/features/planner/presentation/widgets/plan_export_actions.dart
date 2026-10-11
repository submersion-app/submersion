import 'package:flutter/material.dart';

import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/export_destination_sheet.dart';

const _log = LoggerService('PlanExport');

/// A planner export once it has been built: what to write and what to call it.
typedef PlanExportFile = ({List<int> bytes, String fileName, String mimeType});

/// Hands a built export to the system share sheet, anchored at [origin].
typedef PlanExportShare =
    Future<void> Function(
      List<int> bytes,
      String fileName,
      String mimeType,
      Rect? origin,
    );

/// Writes a built export to a location the user picks. Returns where it
/// landed, or null when the save dialog was cancelled.
typedef PlanExportSave =
    Future<String?> Function(
      List<int> bytes,
      String fileName,
      String mimeType,
      String dialogTitle,
    );

/// Asks whether a planner export is saved or shared, then builds and
/// delivers it.
///
/// The share sheet alone left desktop users, Windows in particular, with no
/// way to put the slate or plan file in a folder of their choosing (#3114).
///
/// [build] runs only after a destination is chosen, so a dismissed sheet
/// renders no PDF and reads no plan; it returns null when there is nothing
/// left to export. [title] heads both the sheet and the save dialog.
/// [savedMessage] confirms a completed save; a cancelled save says nothing.
/// [shareAnchor] is the iPad popover's anchor, resolved by the caller while
/// the control that opened the menu is certainly mounted. A failure to build
/// or deliver the file is logged and reported in a snackbar, so a save the
/// system refuses does not end in silence.
Future<void> deliverPlanExport(
  BuildContext context, {
  required String title,
  required String savedMessage,
  required Future<PlanExportFile?> Function() build,
  Rect? shareAnchor,
  PlanExportShare? share,
  PlanExportSave? save,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final destination = await showExportDestinationSheet(context, title: title);
  if (destination == null) return;

  try {
    final file = await build();
    if (file == null) return;

    switch (destination) {
      case ExportDestination.share:
        await (share ?? _share)(
          file.bytes,
          file.fileName,
          file.mimeType,
          shareAnchor,
        );
      case ExportDestination.saveToFile:
        final saved = await (save ?? _save)(
          file.bytes,
          file.fileName,
          file.mimeType,
          title,
        );
        if (saved != null) {
          messenger.showSnackBar(SnackBar(content: Text(savedMessage)));
        }
    }
  } catch (e, st) {
    _log.error('Could not export "$title"', error: e, stackTrace: st);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.plannerCanvas_export_failed(e.toString()))),
    );
  }
}

Future<void> _share(
  List<int> bytes,
  String fileName,
  String mimeType,
  Rect? origin,
) => saveAndShareFileBytes(
  bytes,
  fileName,
  mimeType,
  sharePositionOrigin: origin,
);

Future<String?> _save(
  List<int> bytes,
  String fileName,
  String mimeType,
  String dialogTitle,
) => saveBytesToFile(
  bytes,
  fileName,
  dialogTitle: dialogTitle,
  mimeType: mimeType,
);
