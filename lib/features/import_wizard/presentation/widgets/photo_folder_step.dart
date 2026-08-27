import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Wizard step for locating the photos a logbook references.
///
/// Subsurface stores an absolute path from the exporting machine, so the
/// import cannot find the files on its own. This step collects a folder to
/// resolve them against and reports what matched before anything is written.
///
/// Only shown when the parsed payload actually references photos; see
/// [universalAdapterNoPhotosProvider], which auto-advances past it otherwise.
class PhotoFolderStep extends ConsumerWidget {
  const PhotoFolderStep({super.key, this.pickFolderOverride});

  /// Test seam for the platform directory picker.
  @visibleForTesting
  final Future<String?> Function()? pickFolderOverride;

  /// A recursive folder scan needs real filesystem paths, which Android's SAF
  /// does not reliably provide and iOS does not expose at all.
  static bool get _canPickFolder => switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => true,
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.fuchsia => false,
  };

  Future<void> _pick(WidgetRef ref) async {
    final path =
        await (pickFolderOverride?.call() ?? FilePicker.getDirectoryPath());
    if (path == null) return;
    await ref
        .read(universalImportNotifierProvider.notifier)
        .resolvePhotosIn(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(universalImportNotifierProvider);
    final pictureCount = state.payload
        ?.entitiesOf(ImportEntityType.media)
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_library_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.importWizard_photos_foundCount(pictureCount ?? 0),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (!_canPickFolder)
            Text(l10n.importWizard_photos_mobileUnsupported)
          else if (state.isLoading)
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(l10n.importWizard_photos_scanning),
              ],
            )
          else ...[
            FilledButton.icon(
              onPressed: () => _pick(ref),
              icon: const Icon(Icons.folder_open),
              label: Text(l10n.importWizard_photos_chooseFolder),
            ),
            if (state.photoFolderPath != null) ...[
              const SizedBox(height: 12),
              Text(
                state.photoFolderPath!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (state.photoResolution != null) ...[
              const SizedBox(height: 12),
              Text(
                l10n.importWizard_photos_matchSummary(
                  state.photoResolution!.matchedCount,
                  state.photoResolution!.filenameOnlyCount,
                  state.photoResolution!.notFoundCount,
                ),
              ),
            ],
          ],
          const SizedBox(height: 24),
          TextButton(
            onPressed: () =>
                ref.read(universalImportNotifierProvider.notifier).skipPhotos(),
            child: Text(l10n.importWizard_photos_skip),
          ),
        ],
      ),
    );
  }
}
