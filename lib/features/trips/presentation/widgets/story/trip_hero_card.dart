import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/theme/app_colors.dart';
import 'package:submersion/core/theme/backdrop_color.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/header_map_backdrop.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/locked_map_scroll_passthrough.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/submersion_tile_layer.dart';
import 'package:submersion/features/maps/presentation/widgets/world_camera_fit.dart';
import 'package:submersion/features/maps/presentation/widgets/world_copies.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_progress_line.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_stat_strip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The story's opening card (issue #4106): trip identity, the countdown or
/// day-of-trip line, and the trip's stats, over a map of every located site
/// on the trip fading into the card as the dive detail header does. A trip
/// with no located sites gets the theme's ocean gradient instead, so the card
/// still reads as a hero rather than a plain box.
class TripHeroCard extends ConsumerWidget {
  final TripStory story;
  final TripWithStats stats;

  /// Distinct dive sites visited across the trip (0 hides the tile).
  final int siteCount;

  const TripHeroCard({
    super.key,
    required this.story,
    required this.stats,
    this.siteCount = 0,
  });

  /// Zoom for a trip whose sites all sit on one spot: a close view rather
  /// than a dot in an ocean.
  static const double singlePointZoom = 12.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = story.trip;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasMap = story.mapGeometry.hasPoints;
    // Over the gradient everything reads in onPrimary; over the map fade the
    // card's own foreground pair applies.
    final Color? foreground = hasMap ? null : scheme.onPrimary;
    final Color accent = hasMap ? scheme.primary : scheme.onPrimary;
    final units = ref.watch(unitFormatterProvider);
    final progress = tripProgressLine(context, story);

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                trip.isLiveaboard ? Icons.sailing : Icons.flight_takeoff,
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trip.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${units.formatDate(trip.startDate)}'
            ' - ${units.formatDate(trip.endDate)}'
            ' (${context.l10n.trips_detail_durationDays(trip.durationDays)})',
            style: theme.textTheme.bodyMedium?.copyWith(
              color:
                  foreground?.withValues(alpha: 0.85) ??
                  scheme.onSurfaceVariant,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            Text(
              progress,
              style: theme.textTheme.titleMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const SizedBox(height: 8),
          TripStatStrip(stats: stats, siteCount: siteCount, color: foreground),
        ],
      ),
    );

    if (!hasMap) {
      return Card(
        key: const Key('trip-hero-card'),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          key: const Key('trip-hero-gradient'),
          decoration: BoxDecoration(gradient: heroGradient(theme.brightness)),
          child: content,
        ),
      );
    }

    return Card(
      key: const Key('trip-hero-card'),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Resolved under the Card, so the fade ends in the colour the card
          // actually paints (a theme preset's card, not ThemeData.cardColor).
          Positioned.fill(
            child: Builder(
              builder: (context) => HeaderMapBackdrop(
                fadeColor: backdropColorOf(context),
                child: _TripSitesMap(points: story.mapGeometry.points),
              ),
            ),
          ),
          content,
        ],
      ),
    );
  }

  /// Deep-to-light ocean gradient in the theme's primary blues. The dark
  /// theme stops at the mid blue so the card stays deep against a dark page.
  static LinearGradient heroGradient(Brightness brightness) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: brightness == Brightness.dark
        ? const [AppColors.primaryDark, AppColors.primary]
        : const [
            AppColors.primaryDark,
            AppColors.primary,
            AppColors.primaryLight,
          ],
  );
}

/// Every located site on the trip as a small dot, fitted to the whole set.
/// Decorative: it takes no gestures and has no semantics of its own; the
/// text over it says what the trip is.
class _TripSitesMap extends ConsumerWidget {
  final List<TripStoryMapPoint> points;

  const _TripSitesMap({required this.points});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maxZoom = ref.watch(mapTileMaxZoomProvider);
    final scheme = Theme.of(context).colorScheme;
    // One dot per distinct spot: a trip that dives the same site daily
    // would otherwise stack identical markers.
    final spots = <LatLng>{
      for (final p in points) LatLng(p.latitude, p.longitude),
    }.toList();
    return ExcludeSemantics(
      child: LockedMapScrollPassthrough(
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: WorldCameraFit(
              points: spots,
              padding: const EdgeInsets.all(40),
              maxZoom: maxZoom,
              singlePointZoom: TripHeroCard.singlePointZoom,
            ),
            minZoom: 2.0,
            maxZoom: maxZoom,
            cameraConstraint: worldMapCameraConstraint,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            submersionTileLayer(ref),
            MarkerLayer(
              markers: [
                for (final spot in spots)
                  Marker(
                    point: spot,
                    width: 14,
                    height: 14,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.onPrimary, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const MapAttribution(),
          ],
        ),
      ),
    );
  }
}
