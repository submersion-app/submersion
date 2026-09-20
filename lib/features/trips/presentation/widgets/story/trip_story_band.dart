import 'package:flutter/material.dart';

import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_band_extents.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_docked_day.dart';

/// The story's one pinned layer: the day docked at the start edge, the map at
/// the end edge.
///
/// It replaces two stacked pinned layers (a 180px map plus a 52px day header),
/// which together cost a third of a phone viewport for as long as the diver
/// was reading. The map's width interpolates with the shrink offset rather
/// than snapping, so the split tracks the scroll.
///
/// The [map] is built once by the view and handed in, so a scroll that changes
/// nothing but the shrink offset does not rebuild the map's subtree: only
/// layout re-runs.
class TripStoryBandDelegate extends SliverPersistentHeaderDelegate {
  static const Key bandKey = Key('trip-story-band');

  /// Fraction of the band the map keeps once fully docked.
  static const double dockedMapFraction = 0.5;

  /// The panel fades in over the back half of the morph, so it never sits
  /// half-visible beside a map that is still nearly full width.
  static const double panelFadeStart = 0.5;

  /// Cross-fade between two docked days.
  static const Duration panelSwapDuration = Duration(milliseconds: 200);

  final TripStoryBandExtents extents;
  final Widget map;
  final TripStoryDay? dockedDay;
  final TripStoryDayWeather? dockedWeather;
  final VoidCallback? onDockedDayTap;

  const TripStoryBandDelegate({
    required this.extents,
    required this.map,
    this.dockedDay,
    this.dockedWeather,
    this.onDockedDayTap,
  });

  @override
  double get maxExtent => extents.expanded;

  @override
  double get minExtent => extents.docked;

  @override
  bool shouldRebuild(TripStoryBandDelegate oldDelegate) =>
      oldDelegate.extents.docked != extents.docked ||
      oldDelegate.extents.expanded != extents.expanded ||
      !identical(oldDelegate.map, map) ||
      oldDelegate.dockedDay != dockedDay ||
      oldDelegate.dockedWeather != dockedWeather ||
      oldDelegate.onDockedDayTap != onDockedDayTap;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final span = maxExtent - minExtent;
    final t = span <= 0 ? 1.0 : (shrinkOffset / span).clamp(0.0, 1.0);
    final day = dockedDay;
    // Nothing to dock (a story with no days): the map keeps the whole band
    // rather than leaving half of it blank.
    final mapFraction = day == null ? 1.0 : 1.0 - (1.0 - dockedMapFraction) * t;
    final panelOpacity = day == null
        ? 0.0
        : ((t - panelFadeStart) / (1 - panelFadeStart)).clamp(0.0, 1.0);

    return Material(
      key: bandKey,
      elevation: overlapsContent ? 2 : 0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mapWidth = constraints.maxWidth * mapFraction;
          final panelWidth = constraints.maxWidth - mapWidth;
          return Row(
            children: [
              // Row lays its first child at the start edge, so this mirrors
              // under RTL without a Directionality check.
              if (day != null && panelWidth > 0)
                SizedBox(
                  width: panelWidth,
                  child: Opacity(
                    opacity: panelOpacity,
                    child: AnimatedSwitcher(
                      duration: panelSwapDuration,
                      // The incoming day rises into the slot, continuing the
                      // upward travel of the full-width heading that just went
                      // under the band, so the swap reads as a hand-off.
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.35),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: TripStoryDockedDay(
                        key: ValueKey(day.date),
                        day: day,
                        storedWeather: dockedWeather,
                        onTap: panelOpacity == 1.0 ? onDockedDayTap : null,
                      ),
                    ),
                  ),
                ),
              SizedBox(
                width: mapWidth,
                child: RepaintBoundary(child: map),
              ),
            ],
          );
        },
      ),
    );
  }
}
