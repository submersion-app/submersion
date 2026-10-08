import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Wizard step that settles where an import's photos come from and go to.
///
/// Two kinds of photo can be in play, and each asks its own question:
///
/// - Photos the logbook *references* by path (Subsurface, MacDive). The
///   import cannot find those files on its own, so this step collects a
///   folder to resolve them against and reports what matched. Matches are
///   linked in place.
/// - Photos *bundled* inside an imported archive (a DiveCloud ZIP). Their
///   only home is a temp folder the wizard deletes, so this step asks where
///   to save them. They are written there and linked from there; nothing is
///   ever filed inside the app's own storage.
///
/// Only shown when the import actually carries photos; see
/// [universalAdapterNoPhotosProvider], which auto-advances past it otherwise.
class PhotoFolderStep extends ConsumerWidget {
  const PhotoFolderStep({
    super.key,
    this.pickFolderOverride,
    this.pickDestinationOverride,
  });

  /// Test seam for the platform directory picker (referenced photos).
  @visibleForTesting
  final Future<String?> Function()? pickFolderOverride;

  /// Test seam for the platform directory picker (bundled photos).
  @visibleForTesting
  final Future<String?> Function()? pickDestinationOverride;

  /// A recursive folder scan needs real filesystem paths, which Android's SAF
  /// does not reliably provide and iOS does not expose at all.
  static bool get canPickFolder => switch (defaultTargetPlatform) {
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

  Future<void> _pickDestination(BuildContext context, WidgetRef ref) async {
    final path =
        await (pickDestinationOverride?.call() ??
            FilePicker.getDirectoryPath());
    if (path == null) return;
    final accepted = await ref
        .read(universalImportNotifierProvider.notifier)
        .chooseBundledPhotoFolder(path);
    if (accepted || !context.mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.l10n.importWizard_photos_destinationUnwritable),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(universalImportNotifierProvider);
    final referencedCount =
        state.payload?.entitiesOf(ImportEntityType.media).length ?? 0;
    final bundledCount = state.photoPathsByBaseName.values.fold<int>(
      0,
      (sum, paths) => sum + paths.length,
    );
    final downloadCount = state.remotePhotoCount;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (referencedCount > 0) ...[
            _Heading(
              icon: Icons.photo_library_outlined,
              text: l10n.importWizard_photos_foundCount(referencedCount),
            ),
            const SizedBox(height: 24),
            if (state.isLoading && canPickFolder)
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
            else if (canPickFolder) ...[
              FilledButton.icon(
                onPressed: () => _pick(ref),
                icon: const Icon(Icons.folder_open),
                label: Text(l10n.importWizard_photos_chooseFolder),
              ),
              if (state.photoFolderPath != null) ...[
                const SizedBox(height: 12),
                Text(state.photoFolderPath!, style: theme.textTheme.bodySmall),
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
          ],
          if (bundledCount > 0 || downloadCount > 0) ...[
            if (bundledCount > 0)
              _Heading(
                icon: Icons.archive_outlined,
                text: l10n.importWizard_photos_bundledCount(bundledCount),
              ),
            if (downloadCount > 0)
              _Heading(
                icon: Icons.cloud_download_outlined,
                text: l10n.importWizard_photos_downloadCount(downloadCount),
              ),
            const SizedBox(height: 24),
            if (canPickFolder) ...[
              FilledButton.icon(
                onPressed: () => _pickDestination(context, ref),
                icon: const Icon(Icons.drive_folder_upload_outlined),
                label: Text(l10n.importWizard_photos_chooseDestination),
              ),
              if (state.bundledPhotoFolderPath != null) ...[
                const SizedBox(height: 12),
                Text(
                  state.bundledPhotoFolderPath!,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              Text(
                l10n.importWizard_photos_destinationNote,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 24),
          ],
          // One explanation, covering whichever sections are listed above:
          // neither kind of photo can be located without a folder, and
          // repeating that under each heading only adds noise.
          if (!canPickFolder) ...[
            Text(l10n.importWizard_photos_mobileUnsupported),
            const SizedBox(height: 24),
          ],
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

class _Heading extends StatelessWidget {
  const _Heading({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    );
  }
}
