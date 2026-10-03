import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/gps_log/data/services/track_import/csv_track_parser.dart';
import 'package:submersion/features/gps_log/data/services/track_import/parsed_track.dart';
import 'package:submersion/features/gps_log/data/services/track_import/track_import_service.dart';
import 'package:submersion/features/gps_log/presentation/pages/track_import_review_page.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/track_parse_error_text.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_import_service.dart';
import 'package:submersion/features/nav_track/data/services/parsers/parsed_nav_track.dart';
import 'package:submersion/features/nav_track/data/services/parsers/seacraft_enc_signature.dart';
import 'package:submersion/features/nav_track/presentation/nav_track_parse_error_text.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_import_review_page.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_import_flow_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('TracksImport');

/// Whether a picked file is a Seacraft ENC navigation log rather than a GPS
/// track. Only a CSV can be one; its headers decide.
bool isSeacraftEncFile(String fileName, Uint8List bytes) {
  if (!fileName.toLowerCase().endsWith('.csv')) return false;
  try {
    return looksLikeSeacraftEnc(readCsvHeaders(bytes));
  } catch (_) {
    // Unreadable as CSV: not an ENC log, and the GPS parser reports why.
    return false;
  }
}

/// The Tracks page's Import action: picks one file and sends it to the
/// review page for its kind (spec 2026-10-02, "Import").
Future<void> importTrackFile(BuildContext context, WidgetRef ref) async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['gpx', 'kml', 'csv', 'fit'],
  );
  if (file == null) return;
  // FIT is binary, so read the bytes through the handle rather than via a
  // path: file_picker 12 retired `withData`, and on Android SAF there may be
  // no local path at all.
  final bytes = await file.readAsBytes();
  if (!context.mounted) return;

  if (isSeacraftEncFile(file.name, bytes)) {
    await _importUnderwater(context, ref, bytes, file.name);
  } else {
    await _importGps(context, ref, bytes, file.name);
  }
}

Future<void> _importUnderwater(
  BuildContext context,
  WidgetRef ref,
  Uint8List bytes,
  String fileName,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final NavTrackImportPreview preview;
  try {
    preview = await ref
        .read(navTrackImportServiceProvider)
        .prepare(bytes, fileName: fileName);
  } on NavTrackParseException catch (e) {
    _log.warning('Underwater track import rejected: ${e.message}');
    messenger.showSnackBar(
      SnackBar(content: Text(navTrackParseErrorText(l10n, e))),
    );
    return;
  } catch (e, stackTrace) {
    _log.error(
      'Underwater track import failed',
      error: e,
      stackTrace: stackTrace,
    );
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.navTrack_list_importFailed(e.toString()))),
    );
    return;
  }
  if (!context.mounted) return;
  await navigateToNavTrackReview(
    context,
    bytes,
    fileName: fileName,
    preview: preview,
  );
}

Future<void> _importGps(
  BuildContext context,
  WidgetRef ref,
  Uint8List bytes,
  String fileName,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final TrackImportCandidate candidate;
  try {
    candidate = await ref
        .read(trackImportServiceProvider)
        .prepare(fileName: fileName, bytes: bytes);
  } on TrackParseException catch (e) {
    // e.message names the offending element or row, in English. It belongs
    // in the log; the SnackBar gets the localized reason.
    _log.warning('Track import rejected: ${e.message}');
    messenger.showSnackBar(
      SnackBar(content: Text(trackParseErrorText(l10n, e))),
    );
    return;
  } catch (e, stackTrace) {
    _log.error('Track import failed', error: e, stackTrace: stackTrace);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.gpsTrack_import_failed('$e'))),
    );
    return;
  }
  // The page may have left while the file parsed; its navigator with it.
  if (!context.mounted) return;
  await navigator.push<bool>(
    MaterialPageRoute(
      builder: (_) => TrackImportReviewPage(candidate: candidate, bytes: bytes),
    ),
  );
}
