import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/settings/presentation/providers/media_badge_settings_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the diver has recorded about a library item, as a row of small
/// glyphs for the bottom-left corner of its tile (issue #4218): a person
/// when someone is tagged, a fish when a species is, a timer when the item
/// has a time in its dive.
///
/// Styled like the provenance chip in the opposite corner (translucent black,
/// white glyph) so a grid of tagged photos still reads as photos, and the
/// saturated colours stay reserved for health badges.
///
/// Purely decorative to the pointer: a tap goes through to the tile and opens
/// the viewer, where the tags themselves are. The tooltips carry the meaning
/// for hover and for screen readers.
///
/// Reads flags the library page query already computed, so drawing it costs
/// no query per tile.
class MediaTileMarkers extends ConsumerWidget {
  const MediaTileMarkers({super.key, required this.entry});

  final MediaLibraryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(mediaTagBadgesProvider)) return const SizedBox.shrink();

    final l10n = context.l10n;
    final markers = <(Key, IconData, String)>[
      if (entry.hasPeople)
        (
          const Key('media-tile-marker-people'),
          Icons.person_outline,
          l10n.media_tileMarker_people,
        ),
      if (entry.hasSpecies)
        (
          const Key('media-tile-marker-species'),
          MdiIcons.fish,
          l10n.media_tileMarker_species,
        ),
      if (entry.hasTimeInDive)
        (
          const Key('media-tile-marker-time'),
          Icons.timer_outlined,
          l10n.media_tileMarker_timeInDive,
        ),
    ];
    if (markers.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        for (final (key, icon, label) in markers)
          Tooltip(
            message: label,
            child: Container(
              key: key,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(icon, size: 12, color: Colors.white),
            ),
          ),
      ],
    );
  }
}
