import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

/// Shared logic for handling an incoming file from drag-and-drop or
/// share-sheet intents. Both [GlobalDropTarget] and [SubmersionApp]
/// delegate to this function.
///
/// Returns `true` when the caller should navigate to the import wizard.
Future<bool> handleIncomingFile({
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
    return false;
  }

  final detection = await notifier.loadFileFromBytes(bytes, fileName);

  if (!detection.format.isSupported) {
    notifier.reset();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(unsupportedFileMessage ?? 'Unsupported file type'),
      ),
    );
    return false;
  }

  return true;
}
