import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/features/demo_mode/presentation/demo_seal_guard.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_import_service.dart';
import 'package:submersion/features/nav_track/data/services/parsers/parsed_nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/presentation/nav_track_parse_error_text.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_import_flow_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

final _log = LoggerService.forClass(NavTrackFileActions);

/// The route detail page's file actions (issue #4231): re-read a route from
/// its file, and hand its original file back out.
///
/// Kept out of the page itself so each flow can be driven on its own, with
/// the file picker and the export replaced through [pickFile] and
/// [saveFile].
class NavTrackFileActions {
  const NavTrackFileActions({
    Future<({Uint8List bytes, String name})?> Function()? pickFile,
    Future<void> Function(Uint8List bytes, String fileName, Rect? shareOrigin)?
    saveFile,
  }) : _pickFile = pickFile ?? _pickCsv,
       _saveFile = saveFile ?? _shareCsv;

  final Future<({Uint8List bytes, String name})?> Function() _pickFile;
  final Future<void> Function(
    Uint8List bytes,
    String fileName,
    Rect? shareOrigin,
  )
  _saveFile;

  static Future<({Uint8List bytes, String name})?> _pickCsv() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (file == null) return null;
    return (bytes: await file.readAsBytes(), name: file.name);
  }

  static Future<void> _shareCsv(
    Uint8List bytes,
    String fileName,
    Rect? shareOrigin,
  ) => saveAndShareFileBytes(
    bytes,
    fileName,
    'text/csv',
    sharePositionOrigin: shareOrigin,
  );

  /// Lets the diver pick a file and re-reads [route]'s data from it,
  /// keeping every setting on the route. The file is parsed and compared
  /// with the route before anything is written: a recording made at another
  /// time (a console numbers its files from `001` again, so a name alone
  /// matches different dives) or a file of another name is confirmed first,
  /// so a different dive's recording is never written over the route by
  /// mistake.
  Future<void> updateFromFile(
    BuildContext context,
    WidgetRef ref,
    NavTrack route,
  ) async {
    if (!demoSealGuard(context, DemoSealedFeature.fileImport)) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ({Uint8List bytes, String name})? pick;
    try {
      pick = await _pickFile();
    } catch (e, stackTrace) {
      _log.error('Route file pick failed', error: e, stackTrace: stackTrace);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.navTrack_list_importFailed(e.toString()))),
      );
      return;
    }
    if (pick == null || !context.mounted) return;
    final picked = pick;

    final service = ref.read(navTrackImportServiceProvider);
    final ParsedNavTrack parsed;
    try {
      parsed = service.parseFile(picked.bytes);
    } on NavTrackParseException catch (e) {
      _log.warning('Route update rejected: ${e.message}');
      messenger.showSnackBar(
        SnackBar(content: Text(navTrackParseErrorText(l10n, e))),
      );
      return;
    }

    final warning = _updateWarning(l10n, ref, route, picked.name, parsed);
    if (warning != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(warning.title),
          content: Text(warning.message),
          actions: [
            TextButton(
              key: const ValueKey('nav-track-update-mismatch-cancel'),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.navTrack_common_cancel),
            ),
            FilledButton(
              key: const ValueKey('nav-track-update-mismatch-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.navTrack_review_updateAction),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      final updated = await service.updateFromFile(
        routeId: route.id,
        parsed: parsed,
        sourceFile: picked.bytes,
        sourceRef: picked.name,
      );
      if (!updated) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.navTrack_common_trackNotFound)),
        );
        return;
      }
    } catch (e, stackTrace) {
      _log.error('Route update failed', error: e, stackTrace: stackTrace);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.navTrack_review_trackSaveError(e.toString())),
        ),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.navTrack_review_trackUpdatedConfirmation)),
    );
  }

  /// Why updating [route] from [parsed] (picked as [fileName]) needs the
  /// diver's confirmation, or null when it is plainly the same recording.
  /// Another recording outranks another name: it is the stronger sign of a
  /// different dive.
  ({String title, String message})? _updateWarning(
    AppLocalizations l10n,
    WidgetRef ref,
    NavTrack route,
    String fileName,
    ParsedNavTrack parsed,
  ) {
    if (!NavTrackImportService.isSameRecording(route, parsed)) {
      final units = ref.read(unitFormatterProvider);
      String day(int epochMs) => units.formatDate(
        DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true),
      );
      return (
        title: l10n.navTrack_detail_updateOtherRecordingTitle,
        message: l10n.navTrack_detail_updateOtherRecordingMessage(
          day(parsed.points.first.timestamp * 1000),
          day(route.startTime),
        ),
      );
    }
    final expected = route.sourceRef;
    if (expected != null && expected != fileName) {
      return (
        title: l10n.navTrack_detail_updateNameMismatchTitle,
        message: l10n.navTrack_detail_updateNameMismatchMessage(
          expected,
          fileName,
        ),
      );
    }
    return null;
  }

  /// Hands [route]'s original file back out, byte for byte, under the name
  /// it was imported with. A route imported before the file was kept has
  /// none to give; the diver is told to update it from its file first.
  ///
  /// [shareOrigin] anchors the iPad share popover to the control that
  /// opened it (`shareAnchorFrom`).
  Future<void> exportCsv(
    BuildContext context,
    WidgetRef ref,
    NavTrack route, {
    Rect? shareOrigin,
  }) async {
    if (!demoSealGuard(context, DemoSealedFeature.share)) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await ref
          .read(navTrackRepositoryProvider)
          .getSourceFile(route.id);
      if (file == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.navTrack_detail_exportUnavailable)),
        );
        return;
      }
      await _saveFile(file, route.sourceRef ?? '${route.id}.csv', shareOrigin);
    } catch (e, stackTrace) {
      _log.error('Route export failed', error: e, stackTrace: stackTrace);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.navTrack_detail_exportFailed('$e'))),
      );
    }
  }
}
