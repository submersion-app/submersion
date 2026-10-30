import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:submersion/features/buddies/domain/services/buddy_card_codec.dart';
import 'package:submersion/core/router/shortcut_locations.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/shared/services/shared_file_unreadable_exception.dart';

const _log = LoggerService('IncomingFileHandler');

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

  /// A Suunto app JSON export was recognised (issue #1445). It is imported
  /// by the Suunto importer, not the universal wizard; push the Suunto file
  /// import with the same [bytes]/[fileName] the caller already has.
  navigateToSuuntoFileImport,

  /// A buddy card file (issue #3728). It is never a dive log, so it is
  /// recognised by name before the import wizard is asked: open the buddy
  /// card preview with the same bytes.
  buddyCard,

  /// Nothing to do: the wizard was already busy, or the file is
  /// genuinely unsupported (both cases already surfaced a snackbar).
  none,
}

/// True while an import wizard owns the screen: the universal import
/// wizard (at Transfer, or opened as its nav shortcut, #2936), or the Suunto
/// file import (#1445). A file arriving then is turned away rather than
/// stacking a second wizard over the first.
bool isImportWizardRoute(String path) =>
    path.startsWith('/transfer/import-wizard') ||
    path.startsWith(shortcutLocation('import-wizard')) ||
    path.startsWith('/transfer/import-file/');

/// Shared logic for handling an incoming file from drag-and-drop or
/// share-sheet intents. Both [GlobalDropTarget] and [SubmersionApp]
/// delegate to this function.
///
/// [isImportRunning] turns the file away too: an import that runs on after
/// its wizard closed still reads the shared import state, which loading
/// another file would replace (#3554). It is asked right before that state
/// is written, not when the file arrived, so an import started meanwhile
/// is seen.
Future<IncomingFileOutcome> handleIncomingFile({
  required Uint8List bytes,
  required String fileName,
  required String currentPath,
  required UniversalImportNotifier notifier,
  required ScaffoldMessengerState? messenger,
  bool Function() isImportRunning = _noImportRunning,
  String? wizardActiveMessage,
  String? unsupportedFileMessage,
}) async {
  // Not an import, so neither a running import nor an open wizard holds it
  // back, and the import state is left alone.
  if (BuddyCardCodec.isCardFileName(fileName) ||
      BuddyCardCodec.looksLikeFullCard(bytes)) {
    return IncomingFileOutcome.buddyCard;
  }
  if (isImportRunning() || isImportWizardRoute(currentPath)) {
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

  if (detection.format == ImportFormat.suuntoJson) {
    notifier.reset();
    return IncomingFileOutcome.navigateToSuuntoFileImport;
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

/// [paths] split into buddy card files (issue #3728), found by name, and
/// everything else. Several files arriving together go to the import
/// wizard as a batch; a card is not a dive log, so each opens its preview
/// instead.
({List<String> cards, List<String> others}) splitBuddyCardPaths(
  List<String> paths,
) => (
  cards: [
    for (final path in paths)
      if (BuddyCardCodec.isCardFileName(path)) path,
  ],
  others: [
    for (final path in paths)
      if (!BuddyCardCodec.isCardFileName(path)) path,
  ],
);

/// Multi-file counterpart of [handleIncomingFile], for a share-sheet intent
/// carrying several files at once. The files enter the import wizard as one
/// batch, the way several dropped files do in [GlobalDropTarget].
///
/// Returns `true` when the caller should navigate to the import wizard.
/// [isImportRunning] turns the files away, as for [handleIncomingFile].
Future<bool> handleIncomingFiles({
  required List<String> paths,
  required String currentPath,
  required UniversalImportNotifier notifier,
  required ScaffoldMessengerState? messenger,
  bool Function() isImportRunning = _noImportRunning,
  String? wizardActiveMessage,
}) async {
  if (isImportRunning() || isImportWizardRoute(currentPath)) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text(wizardActiveMessage ?? 'Finish current import first'),
      ),
    );
    return false;
  }

  await notifier.loadFilesFromPaths(paths);
  return true;
}

/// Surfaces an incoming file that failed, from a share-sheet intent or a
/// drag-and-drop: writes [error] to the log and shows the diver a snackbar,
/// so neither ends in silence (#2689, #2715).
///
/// A [SharedFileUnreadableException] whose share still imported other files
/// reads [someUnreadableMessage] with the number skipped; everything else,
/// that exception included when nothing was readable, reads
/// [readFailedMessage].
void reportIncomingFileError(
  Object error, {
  required ScaffoldMessengerState? messenger,
  String? readFailedMessage,
  String Function(int count)? someUnreadableMessage,
}) {
  _log.warning('An incoming file could not be imported', error: error);

  final String message;
  if (error is SharedFileUnreadableException && !error.nothingReadable) {
    final count = error.unreadablePaths.length;
    message =
        someUnreadableMessage?.call(count) ??
        '$count file(s) could not be read and were skipped';
  } else {
    message = readFailedMessage ?? 'Could not read file';
  }
  messenger?.showSnackBar(SnackBar(content: Text(message)));
}

bool _noImportRunning() => false;
