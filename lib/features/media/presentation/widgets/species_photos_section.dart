import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/species_photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The photos tagged with one species, on the species detail page.
///
/// A titled three-column grid with two header actions. Either action is
/// hidden when its callback is null, so the section can be mounted before
/// the flows behind the buttons exist.
class SpeciesPhotosSection extends ConsumerWidget {
  final String speciesId;
  final VoidCallback? onTagPhotos;
  final VoidCallback? onAddPhotos;

  const SpeciesPhotosSection({
    super.key,
    required this.speciesId,
    this.onTagPhotos,
    this.onAddPhotos,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mediaAsync = ref.watch(mediaForSpeciesProvider(speciesId));
    final settings = ref.watch(settingsProvider);
    final items = mediaAsync.value ?? const <MediaItem>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.marineLife_speciesPhotos_title(items.length),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            if (onTagPhotos != null)
              TextButton.icon(
                key: const ValueKey('species_tag_photos'),
                onPressed: onTagPhotos,
                icon: const Icon(Icons.sell_outlined),
                label: Text(l10n.marineLife_speciesPhotos_tagPhotos),
              ),
            if (onAddPhotos != null)
              TextButton.icon(
                key: const ValueKey('species_add_photos'),
                onPressed: onAddPhotos,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(l10n.marineLife_speciesPhotos_addPhotos),
              ),
          ],
        ),
        const SizedBox(height: 8),
        mediaAsync.when(
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text(
            '$error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          data: (items) {
            if (items.isEmpty) {
              return MediaEmptyState(
                icon: Icons.photo_library_outlined,
                message: l10n.marineLife_speciesPhotos_empty,
              );
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openViewer(context, item),
                  child: MediaThumbnailTile(
                    item: item,
                    settings: settings,
                    isSelectionMode: false,
                    isSelected: false,
                    semanticsLabel:
                        l10n.marineLife_speciesPhotos_thumbnailLabel,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  void _openViewer(BuildContext context, MediaItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => SpeciesPhotoViewerPage(
          speciesId: speciesId,
          initialMediaId: item.id,
        ),
      ),
    );
  }
}
