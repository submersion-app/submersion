import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

/// What the caller should do once [handleIncomingFile] has processed a
/// file.
enum IncomingFileOutcome {
  /// A dive-log format was recognised; push the universal import wizard.
  navigateToWizard,

  /// A Seacraft ENC navigation log was recognised. This is an underwater
  /// route, not a dive log, and never enters the dive import pipeline
  /// (`ImportFormat.navTrack.isSupported == false`); push the route
  /// review page directly with the same [bytes]/[fileName] the caller
  /// already has, instead of the wizard.
  navigateToNavTrackReview,

  /// Nothing to do: the wizard was already busy, or the file is
  /// genuinely unsupported (both cases already surfaced a snackbar).
  none,
}

/// Shared logic for handling an incoming file from drag-and-drop or
/// share-sheet intents. Both [GlobalDropTarget] and [SubmersionApp]
/// delegate to this function.
Future<IncomingFileOutcome> handleIncomingFile({
  required Uint8List bytes,
  required String fileName,
  required String currentPath,
  required UniversalImportNotifier notifier,
  required ScaffoldMessengerState? messenger,
  String? wizardActiveMessage,
  String? unsupportedFileMessage,
}) async {
  if (currentPath.startsWith('/transfer/import-wizard')) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text(wizardActiveMessage ?? 'Finish current import first'),
      ),
    );
    return IncomingFileOutcome.none;
  }

  final detection = await notifier.loadFileFromBytes(bytes, fileName);

  // Checked ahead of isSupported: a recognised ENC file is deliberately
  // unsupported by the dive import pipeline (it is a route, not a dive
  // log), which would otherwise fall into the generic "unsupported file"
  // rejection below instead of reaching the route review page the
  // wizard's own file-selection step already hands off to.
  if (detection.format == ImportFormat.navTrack) {
    notifier.reset();
    return IncomingFileOutcome.navigateToNavTrackReview;
  }

  if (!detection.format.isSupported) {
    notifier.reset();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(unsupportedFileMessage ?? 'Unsupported file type'),
      ),
    );
    return IncomingFileOutcome.none;
  }

  return IncomingFileOutcome.navigateToWizard;
}
