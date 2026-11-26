import 'package:flutter/material.dart';

import 'package:submersion/features/marine_life/domain/entities/species_crop.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_launcher.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/species_id/presentation/widgets/suggested_species_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the viewer over [items] at [initialId]; [openMediaViewer] in the
/// app, a recorder in tests.
typedef SpeciesViewerOpener =
    void Function(
      BuildContext context,
      List<MediaItem> items,
      String initialId, {
      Duration? initialVideoPosition,
    });

void _openViewer(
  BuildContext context,
  List<MediaItem> items,
  String initialId, {
  Duration? initialVideoPosition,
}) => openMediaViewer(
  context,
  items,
  initialId,
  initialVideoPosition: initialVideoPosition,
);

/// Side of a strip tile.
const kSpeciesStripTile = 96.0;

/// Every crop of a species under its hero (issue #5027), the cover first,
/// then newest first, then the tagged photos with no crop. A tap opens the
/// photo, or the video at the animal's moment; a long press (or a right
/// click) makes a tile the cover, or removes the cover.
class SpeciesCropStrip extends StatelessWidget {
  const SpeciesCropStrip({
    super.key,
    required this.crops,
    required this.uncropped,
    required this.media,
    this.coverIdentificationId,
    this.coverMediaId,
    required this.onSetCover,
    required this.onClearCover,
    this.openViewer = _openViewer,
  });

  final List<SpeciesCrop> crops;

  /// Tagged media with no crop of this species, newest first.
  final List<MediaItem> uncropped;

  /// Every tagged media item of the species, what the viewer pages through.
  final List<MediaItem> media;
  final String? coverIdentificationId;
  final String? coverMediaId;
  final void Function(String mediaId, String? identificationId) onSetCover;
  final VoidCallback onClearCover;
  final SpeciesViewerOpener openViewer;

  /// Whether a tile is the cover. A cover may name a smaller animal on a
  /// photo than the one its tile shows (one tile per photo): then the photo
  /// is the cover.
  bool _isCover({String? identificationId, required String mediaId}) {
    if (coverMediaId != mediaId) return false;
    final inStrip = crops.any(
      (c) => c.identificationId == coverIdentificationId,
    );
    return inStrip ? coverIdentificationId == identificationId : true;
  }

  @override
  Widget build(BuildContext context) {
    if (crops.isEmpty && uncropped.isEmpty) return const SizedBox.shrink();
    final tiles = <_StripEntry>[
      for (final crop in crops)
        _StripEntry(
          key: crop.identificationId,
          mediaId: crop.mediaId,
          crop: crop,
          isCover: _isCover(
            identificationId: crop.identificationId,
            mediaId: crop.mediaId,
          ),
        ),
      for (final item in uncropped)
        _StripEntry(
          key: item.id,
          mediaId: item.id,
          photo: item,
          isCover: _isCover(mediaId: item.id),
        ),
    ];
    // The cover leads; the rest keep their order.
    final ordered = [
      ...tiles.where((t) => t.isCover),
      ...tiles.where((t) => !t.isCover),
    ];
    return SizedBox(
      height: kSpeciesStripTile,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: ordered.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) => _tile(context, ordered[index]),
      ),
    );
  }

  Widget _tile(BuildContext context, _StripEntry entry) {
    final l10n = context.l10n;
    final crop = entry.crop;
    final photo = entry.photo;
    return Semantics(
      button: true,
      label: l10n.marineLife_speciesDetail_openMedia,
      child: GestureDetector(
        key: ValueKey('species_strip_${entry.key}'),
        onTap: () => _open(context, entry),
        onLongPressStart: (details) =>
            _menu(context, entry, details.globalPosition),
        onSecondaryTapUp: (details) =>
            _menu(context, entry, details.globalPosition),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox.square(
            dimension: kSpeciesStripTile,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (crop != null)
                  IdentificationCrop(
                    mediaId: crop.mediaId,
                    identificationId: crop.identificationId,
                  )
                else if (photo != null)
                  MediaItemView(
                    item: photo,
                    fit: BoxFit.cover,
                    thumbnail: true,
                    targetSize: const Size(200, 200),
                  ),
                if (crop != null && crop.isVideo)
                  const PositionedDirectional(
                    bottom: 4,
                    end: 4,
                    child: Icon(
                      Icons.play_circle_fill,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                if (entry.isCover)
                  PositionedDirectional(
                    top: 4,
                    start: 4,
                    child: Tooltip(
                      message: l10n.marineLife_speciesDetail_cover,
                      child: const Icon(
                        Icons.star,
                        size: 18,
                        color: Colors.amber,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, _StripEntry entry) {
    if (!media.any((m) => m.id == entry.mediaId)) return;
    final crop = entry.crop;
    final at = crop != null && crop.isVideo && crop.bestMs != null
        ? Duration(milliseconds: crop.bestMs!)
        : null;
    openViewer(context, media, entry.mediaId, initialVideoPosition: at);
  }

  Future<void> _menu(BuildContext context, _StripEntry entry, Offset at) async {
    final l10n = context.l10n;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final choice = await showMenu<bool>(
      context: context,
      position: RelativeRect.fromRect(
        at & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        if (entry.isCover)
          PopupMenuItem(
            value: false,
            child: Text(l10n.marineLife_speciesDetail_removeCover),
          )
        else
          PopupMenuItem(
            value: true,
            child: Text(l10n.marineLife_speciesDetail_useAsCover),
          ),
      ],
    );
    if (choice == true) {
      onSetCover(entry.mediaId, entry.crop?.identificationId);
    } else if (choice == false) {
      onClearCover();
    }
  }
}

class _StripEntry {
  const _StripEntry({
    required this.key,
    required this.mediaId,
    this.crop,
    this.photo,
    required this.isCover,
  });

  final String key;
  final String mediaId;
  final SpeciesCrop? crop;
  final MediaItem? photo;
  final bool isCover;
}
