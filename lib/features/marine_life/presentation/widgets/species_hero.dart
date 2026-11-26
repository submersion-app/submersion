import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/domain/entities/species_crop.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_picture_view.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The longer side of the rendition the hero asks for: sharp at any hero
/// size without fetching a full original.
const kSpeciesHeroTarget = Size(1600, 1600);

/// The part of the image, normalised 0 to 1, the hero shows for [box]: the
/// box padded by [margin] of its longer side, clamped to the image.
Rect heroSourceRect(IdentificationBox box, {double margin = 0.15}) {
  final pad = margin * math.max(box.width, box.height);
  return Rect.fromLTRB(
    math.max(0, box.x - pad),
    math.max(0, box.y - pad),
    math.min(1, box.x + box.width + pad),
    math.min(1, box.y + box.height + pad),
  );
}

/// The top of a species' page (issue #5027): its picture, large, with the
/// names over a fade.
///
/// For a crop of a photo the hero draws the original zoomed to the animal,
/// over the stored crop it falls back to: the crop is at most 320 px, too
/// soft at this size, and the original may be on another device. Video and
/// any load failure keep the stored crop.
class SpeciesHero extends StatefulWidget {
  const SpeciesHero({
    super.key,
    required this.species,
    required this.picture,
    this.cropMedia,
    this.emptyAction,
  });

  final Species species;
  final SpeciesPicture picture;

  /// The media item the crop is cut from, when it is known here.
  final MediaItem? cropMedia;

  /// Shown under the names when there is no picture (Find photos).
  final Widget? emptyAction;

  @override
  State<SpeciesHero> createState() => _SpeciesHeroState();
}

class _SpeciesHeroState extends State<SpeciesHero> {
  bool _failed = false;
  Size? _imageSize;

  @override
  void didUpdateWidget(SpeciesHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cropMedia?.id != widget.cropMedia?.id) {
      _failed = false;
      _imageSize = null;
    }
  }

  SpeciesCrop? get _zoomable {
    final picture = widget.picture;
    final media = widget.cropMedia;
    if (_failed || picture is! CropPicture || media == null) return null;
    final crop = picture.crop;
    if (crop.isVideo || media.mediaType != MediaType.photo) return null;
    return media.id == crop.mediaId ? crop : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final species = widget.species;
    final zoomable = _zoomable;
    final scientific = species.scientificName;
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          SpeciesPictureView(
            picture: widget.picture,
            category: species.category,
          ),
          if (zoomable != null)
            LayoutBuilder(
              builder: (context, constraints) =>
                  _zoomed(zoomable, widget.cropMedia!, constraints.biggest),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.45, 1],
                colors: [Colors.transparent, Color(0xB3000000)],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  species.localizedCommonName(l10n),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
                if (scientific != null && scientific.isNotEmpty)
                  Text(
                    scientific,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                Text(
                  species.category.localizedName(l10n),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                if (widget.picture is NoPicture &&
                    widget.emptyAction != null) ...[
                  const SizedBox(height: 8),
                  widget.emptyAction!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The original laid out so the padded box covers [hero], centred on the
  /// box, never leaving an edge of the hero uncovered.
  Widget _zoomed(SpeciesCrop crop, MediaItem media, Size hero) {
    final known = (media.width ?? 0) > 0 && (media.height ?? 0) > 0
        ? Size(media.width!.toDouble(), media.height!.toDouble())
        : _imageSize;
    final aspect = known == null ? 4 / 3 : known.width / known.height;
    final source = heroSourceRect(crop.box);
    final width = math.max(
      hero.width / source.width,
      hero.height / source.height * aspect,
    );
    final height = width / aspect;
    final left = (hero.width / 2 - source.center.dx * width).clamp(
      hero.width - width,
      0.0,
    );
    final top = (hero.height / 2 - source.center.dy * height).clamp(
      hero.height - height,
      0.0,
    );
    return Opacity(
      // Until the aspect is known the layout is a guess; draw nothing yet.
      opacity: known == null ? 0 : 1,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: left,
            top: top,
            width: width,
            height: height,
            child: MediaItemView(
              key: ValueKey('species_hero_original_${media.id}'),
              item: media,
              fit: BoxFit.fill,
              thumbnail: true,
              targetSize: kSpeciesHeroTarget,
              onImageSize: (size) {
                if (mounted && _imageSize == null) {
                  setState(() => _imageSize = size);
                }
              },
              onImageFailed: () {
                if (mounted) setState(() => _failed = true);
              },
            ),
          ),
        ],
      ),
    );
  }
}
