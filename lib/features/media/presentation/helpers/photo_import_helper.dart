import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/presentation/pages/photo_picker_page.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Helper for importing photos for a dive.
///
/// Opens the photo picker, imports selected photos, and refreshes the media list.
class PhotoImportHelper {
  /// Opens the photo picker and imports selected photos for a dive.
  ///
  /// [context] - Build context for navigation.
  /// [ref] - Riverpod ref for accessing providers.
  /// [dive] - The dive to associate photos with.
  ///
  /// Returns true if photos were imported, false if cancelled or failed.
  static Future<bool> importPhotosForDive({
    required BuildContext context,
    required WidgetRef ref,
    required Dive dive,
  }) async {
    // Calculate time window with 30-minute buffer
    final diveStart = dive.effectiveEntryTime;
    final diveDuration = dive.calculatedDuration ?? const Duration(hours: 1);
    final diveEnd = dive.exitTime ?? diveStart.add(diveDuration);

    // Open photo picker
    final selectedAssets = await showPhotoPicker(
      context: context,
      diveStartTime: diveStart,
      diveEndTime: diveEnd,
    );

    // User cancelled or context no longer valid
    if (selectedAssets == null || selectedAssets.isEmpty || !context.mounted) {
      return false;
    }

    // Defer dialog display to avoid Navigator lock issues.
    // The photo picker just popped, so the Navigator may still be locked.
    // We need to wait for the next frame before showing the dialog.
    final dialogCompleter = Completer<void>();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        _showImportingDialog(context, selectedAssets.length);
      }
      dialogCompleter.complete();
    });
    await dialogCompleter.future;

    // Context may have become invalid while waiting
    if (!context.mounted) {
      return false;
    }

    try {
      // Import photos
      final importService = ref.read(mediaImportServiceProvider);
      final result = await importService.importPhotosForDive(
        selectedAssets: selectedAssets,
        dive: dive,
      );

      // Dismiss loading dialog safely
      if (context.mounted) {
        _dismissDialogSafely(context);
      }

      // Refresh media list and GPS providers
      ref.invalidate(mediaForDiveProvider(dive.id));
      ref.invalidate(mediaCountForDiveProvider(dive.id));
      ref.invalidate(divePhotoGpsProvider(dive.id));
      ref.invalidate(allDivePhotoGpsProvider(dive.id));

      // Show result
      if (context.mounted) {
        _showResultSnackbar(
          context,
          result.imported.length,
          result.failures.length,
        );
      }

      return result.imported.isNotEmpty;
    } catch (e) {
      // Dismiss loading dialog safely
      if (context.mounted) {
        _dismissDialogSafely(context);
      }

      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.media_import_failedToImportError(e.toString()),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }

      return false;
    }
  }

  /// Safely dismisses the dialog using post-frame callback to avoid lock issues.
  static void _dismissDialogSafely(BuildContext context) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }

  static void _showImportingDialog(BuildContext context, int count) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 24),
            Expanded(
              child: Text(context.l10n.media_import_importingPhotos(count)),
            ),
          ],
        ),
      ),
    );
  }

  static void _showResultSnackbar(
    BuildContext context,
    int imported,
    int failed,
  ) {
    String message;
    if (failed == 0) {
      message = context.l10n.media_import_importedPhotos(imported);
    } else if (imported == 0) {
      message = context.l10n.media_import_failedToImport(failed);
    } else {
      message = context.l10n.media_import_importedAndFailed(imported, failed);
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Extension on WidgetRef for convenient photo import.
extension PhotoImportExtension on WidgetRef {
  /// Opens the photo picker and imports photos for a dive.
  Future<bool> importPhotosForDive(BuildContext context, Dive dive) {
    return PhotoImportHelper.importPhotosForDive(
      context: context,
      ref: this,
      dive: dive,
    );
  }
}
