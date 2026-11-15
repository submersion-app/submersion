import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';
import 'package:submersion/features/marine_life/presentation/sighting_abundance_display.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Tiny muted heading over a tail-of-day cluster (photos, species) so those
/// strips stop reading as unlabeled debris after the dive rows.
class TripDaySectionCaption extends StatelessWidget {
  const TripDaySectionCaption({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// A day's first photos in a row, each opening the trip gallery, with a
/// "+N" tile when the day has more than the preview holds.
class TripDayPhotoStrip extends StatelessWidget {
  const TripDayPhotoStrip({
    super.key,
    required this.tripId,
    required this.media,
    required this.totalCount,
  });

  final String tripId;
  final List<MediaItem> media;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final remaining = totalCount - media.length;
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: media.length + (remaining > 0 ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          if (index >= media.length) {
            return _MoreThumbnail(count: remaining, tripId: tripId);
          }
          // MediaItemView renders the image without a semantic label, so label
          // the tap target as a button that opens the trip gallery.
          return Semantics(
            button: true,
            label: context.l10n.trips_story_openGallery,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => context.push('/trips/$tripId/gallery'),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: MediaItemView(
                    item: media[index],
                    thumbnail: true,
                    targetSize: const Size(128, 128),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MoreThumbnail extends StatelessWidget {
  final int count;
  final String tripId;

  const _MoreThumbnail({required this.count, required this.tripId});

  @override
  Widget build(BuildContext context) {
    // The bare "+N" is a context-free accessible name; label it as a button
    // that opens the trip gallery.
    return Semantics(
      button: true,
      label: context.l10n.trips_story_openGallery,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => context.push('/trips/$tripId/gallery'),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text('+$count', style: Theme.of(context).textTheme.labelLarge),
        ),
      ),
    );
  }
}

/// The species seen on a day, one chip each, merged across the day's dives.
class TripDaySightingChips extends StatelessWidget {
  const TripDaySightingChips({super.key, required this.day});

  final TripStoryDay day;

  @override
  Widget build(BuildContext context) {
    // Merge the same species across the day's dives, keyed by the stable
    // speciesId so distinct species that share a common name stay separate.
    // Amounts combine as a dive merge does (issue #4337): exact counts add
    // up, Seen gives way, otherwise the larger REEF group wins.
    final l10n = context.l10n;
    final merged = <String, ({String name, SightingAmount amount})>{};
    for (final sighting in day.sightings) {
      final existing = merged[sighting.speciesId];
      merged[sighting.speciesId] = (
        name: localizedSpeciesName(
          l10n,
          sighting.speciesId,
          sighting.speciesName,
        ),
        amount: existing == null
            ? sighting.amount
            : SightingAbundance.combine(existing.amount, sighting.amount),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final entry in merged.values)
          Chip(
            label: Text(switch (sightingAmountLabel(l10n, entry.amount)) {
              null => entry.name,
              final amount => '${entry.name} $amount',
            }),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}
