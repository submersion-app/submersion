import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/exif_extractor.dart';
import 'package:submersion/features/media/data/services/local_media_linker.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/universal_import/data/services/android_directory_scanner.dart';
import 'package:submersion/features/universal_import/data/services/desktop_directory_scanner.dart';
import 'package:submersion/features/universal_import/data/services/directory_scanner.dart';
import 'package:submersion/features/universal_import/data/services/ios_directory_scanner.dart';
import 'package:submersion/features/universal_import/presentation/providers/import_photo_link_controller.dart';

/// Session-scoped controller for the post-import photo-locate flow.
///
/// [scannerFor] selects the platform scanner: [AndroidDirectoryScanner] on
/// Android (SAF tree URI), [IosDirectoryScanner] on iOS (security-scoped
/// directory), and [DesktopDirectoryScanner] on all other platforms
/// (dart:io POSIX path).
final importPhotoLinkControllerProvider =
    StateNotifierProvider<ImportPhotoLinkController, ImportPhotoLinkState>((
      ref,
    ) {
      final mediaRepository = ref.read(mediaRepositoryProvider);
      final bookmarkStorage = ref.read(localBookmarkStorageProvider);
      final platform = ref.read(localMediaPlatformProvider);
      final exif = ExifExtractor();
      return ImportPhotoLinkController(
        scannerFor: (_) {
          if (!kIsWeb && Platform.isAndroid) {
            return AndroidDirectoryScanner(platform);
          }
          if (!kIsWeb && Platform.isIOS) return IosDirectoryScanner(platform);
          return DesktopDirectoryScanner();
        },
        linker: LocalMediaLinker(
          mediaRepository: mediaRepository,
          bookmarkStorage: bookmarkStorage,
        ),
        metadataFor: (file) async {
          final path = file.handle.localPath;
          if (path == null) {
            return const MediaSourceMetadata(mimeType: 'image/jpeg');
          }
          final meta = await exif.extract(File(path));
          return meta ?? const MediaSourceMetadata(mimeType: 'image/jpeg');
        },
        alreadyLinkedBasenames: (diveId) async {
          final items = await mediaRepository.getMediaForDive(diveId);
          return items
              .map((m) => m.originalFilename ?? '')
              .where((n) => n.isNotEmpty)
              .toSet();
        },
        fallbackTakenAtFor: (_) => DateTime.now(),
      );
    });

/// Post-import affordance that lets the user point at the folder holding the
/// photos referenced by the dives they just imported, then links them.
///
/// Renders nothing when the import carried no photo references. Otherwise it
/// walks the user through: prompt -> folder pick -> progress -> summary, with
/// a "try another folder" retry that is safe because linking is idempotent by
/// basename.
class ImportPhotoLocatePrompt extends ConsumerWidget {
  const ImportPhotoLocatePrompt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importPhotoLinkControllerProvider);
    if (state.refCount == 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final controller = ref.read(importPhotoLinkControllerProvider.notifier);

    Future<void> pick() async {
      final picked = await FilePicker.getDirectoryPath();
      if (picked == null) return;
      await controller.pickedFolder(GrantedFolder(path: picked));
    }

    final Widget action;
    if (state.isRunning) {
      action = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          // TODO(media): l10n
          Text('Linking ${state.processed} of ${state.total}...'),
        ],
      );
    } else if (state.summary != null) {
      final s = state.summary!;
      final skippedSuffix = s.skippedNonImage > 0
          ? ', ${s.skippedNonImage} skipped'
          : '';
      action = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            // TODO(media): l10n
            '${s.linked} linked, ${s.notFound} not found$skippedSuffix',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: pick,
            icon: const Icon(Icons.folder_open),
            // TODO(media): l10n
            label: const Text('Try another folder'),
          ),
        ],
      );
    } else if (state.errorMessage != null) {
      action = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            // TODO(media): l10n
            state.errorMessage!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: pick,
            icon: const Icon(Icons.folder_open),
            // TODO(media): l10n
            label: const Text('Try another folder'),
          ),
        ],
      );
    } else {
      action = FilledButton.icon(
        onPressed: pick,
        icon: const Icon(Icons.image_search),
        // TODO(media): l10n
        label: const Text('Locate Photos'),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 32),
          Text(
            // TODO(media): l10n
            '${state.refCount} photos referenced by these dives',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          action,
        ],
      ),
    );
  }
}
