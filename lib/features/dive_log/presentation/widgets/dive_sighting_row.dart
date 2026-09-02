import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_color.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One sighting on the dive detail page: the category avatar, the localized
/// species name, the note, the animal count, and, when the dive's photos
/// carry this species' tag, a chip that opens those photos.
class DiveSightingRow extends StatelessWidget {
  const DiveSightingRow({
    super.key,
    required this.sighting,
    required this.photoCount,
    required this.onOpen,
    this.onOpenPhotos,
  });

  final Sighting sighting;

  /// Photos on this dive tagged with the sighting's species. The chip only
  /// appears for a positive count with an [onOpenPhotos] to call.
  final int photoCount;

  /// Tapping the row: opens the species detail.
  final VoidCallback onOpen;

  /// Tapping the photo chip.
  final VoidCallback? onOpenPhotos;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final name = localizedSpeciesName(
      l10n,
      sighting.speciesId,
      sighting.speciesName,
    );
    final onOpenPhotos = this.onOpenPhotos;

    return Semantics(
      button: true,
      label: l10n.diveLog_detail_semantics_viewSpecies(name),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colorForSpeciesCategory(
                  sighting.speciesCategory,
                  theme.brightness,
                ),
                child: Icon(
                  iconForSpeciesCategory(
                    sighting.speciesCategory ?? SpeciesCategory.other,
                  ),
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (sighting.notes.isNotEmpty)
                      Text(
                        sighting.notes,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (photoCount > 0 && onOpenPhotos != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ActionChip(
                    key: const ValueKey('sighting_photos'),
                    avatar: const Icon(Icons.photo_outlined, size: 16),
                    label: Text(l10n.diveLog_detail_sightingPhotos(photoCount)),
                    onPressed: onOpenPhotos,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              if (sighting.count > 1)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'x${sighting.count}',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
