import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species_crop.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_color.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/species_id/presentation/widgets/suggested_species_section.dart';

/// Draws the picture that stands for a species, filling its box (issue
/// #5027): the stored crop, a tagged photo, or the category tile.
class SpeciesPictureView extends StatelessWidget {
  const SpeciesPictureView({
    super.key,
    required this.picture,
    required this.category,
    this.fit = BoxFit.cover,
    this.targetSize,
  });

  final SpeciesPicture picture;
  final SpeciesCategory category;
  final BoxFit fit;

  /// Decode target for a photo; a tile-sized default when null.
  final Size? targetSize;

  @override
  Widget build(BuildContext context) => switch (picture) {
    CropPicture(:final crop) => IdentificationCrop(
      mediaId: crop.mediaId,
      identificationId: crop.identificationId,
      fit: fit,
    ),
    PhotoPicture(:final media) => MediaItemView(
      item: media,
      fit: fit,
      thumbnail: true,
      targetSize: targetSize ?? const Size(400, 400),
    ),
    NoPicture() => SpeciesCategoryTile(category: category),
  };
}

/// The category's colour with its icon: what a species with no picture
/// shows.
class SpeciesCategoryTile extends StatelessWidget {
  const SpeciesCategoryTile({super.key, required this.category});

  final SpeciesCategory category;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: const ValueKey('species_category_tile'),
    child: ColoredBox(
      color: colorForSpeciesCategory(category, Theme.of(context).brightness),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = math.min(constraints.maxWidth, constraints.maxHeight);
          return Center(
            child: ExcludeSemantics(
              child: Icon(
                iconForSpeciesCategory(category),
                color: Colors.white,
                size: side.isFinite ? math.min(side * 0.4, 72) : 40,
              ),
            ),
          );
        },
      ),
    ),
  );
}
