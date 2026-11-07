import 'package:flutter/material.dart';

import 'package:submersion/features/media/presentation/helpers/gallery_album_filter.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A row of album chips above the Gallery tab's grid: "All albums" and then
/// each album that holds photos from the dive's time window, so the dive's
/// camera roll can be picked out from chat images and screenshots taken in
/// the same hour (issue #189).
///
/// Renders nothing when no album would narrow what the grid shows, such as a
/// window whose photos all sit in one album.
class GalleryAlbumFilterBar extends StatelessWidget {
  /// The albums to offer, in display order.
  final List<GalleryAlbumOption> options;

  /// How many assets the time window holds across all albums.
  final int totalCount;

  /// The album shown, or null for all of them.
  final String? selectedAlbumId;

  /// Called with the album the user picked, or null for "All albums".
  final ValueChanged<String?> onSelected;

  const GalleryAlbumFilterBar({
    super.key,
    required this.options,
    required this.totalCount,
    required this.selectedAlbumId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (!options.any((option) => option.count < totalCount)) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    Widget chip(String label, String? albumId) => Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selectedAlbumId == albumId,
        showCheckmark: false,
        onSelected: (_) => onSelected(albumId),
      ),
    );

    return Semantics(
      container: true,
      label: l10n.media_photoPicker_albumFilter_label,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
          ),
        ),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          children: [
            chip(
              l10n.media_photoPicker_albumFilter_chip(
                l10n.media_photoPicker_albumFilter_all,
                totalCount,
              ),
              null,
            ),
            for (final option in options)
              chip(
                l10n.media_photoPicker_albumFilter_chip(
                  option.album.name,
                  option.count,
                ),
                option.album.id,
              ),
          ],
        ),
      ),
    );
  }
}
