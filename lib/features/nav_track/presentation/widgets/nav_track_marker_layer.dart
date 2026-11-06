import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_polyline_layer.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One console marker as a map draws it (issue #4231): its number in file
/// order, the recorded sample it belongs to, and where that sample lands.
typedef NavTrackMarkerPlacement = ({
  int number,
  NavTrackPoint point,
  LatLng latLng,
});

/// Where [route]'s markers sit on the map, numbered 1, 2, 3 in file order.
///
/// Placed on the drawn samples of [navTrackDrawnSamples], so a marker moves
/// with every correction the line does. A marker on a sample the line does
/// not draw (a GPS-fix row after the dive) keeps its number but is left
/// out: there is no point of the drawn route to put it on.
List<NavTrackMarkerPlacement> navTrackMarkerPlacements(NavTrack route) {
  if (route.markers.isEmpty) return const [];
  final drawn = {
    for (final sample in navTrackDrawnSamples(route))
      sample.index: sample.latLng,
  };
  return [
    for (final (i, marker) in route.markers.indexed)
      if (drawn[marker.index] case final latLng?)
        (number: i + 1, point: route.points[marker.index], latLng: latLng),
  ];
}

/// The console's markers on a route map: a numbered dot each, which on a
/// tap names the marker's time, depth and distance into the dive.
class NavTrackMarkerLayer extends ConsumerWidget {
  const NavTrackMarkerLayer({super.key, required this.route});

  final NavTrack route;

  static const double _size = 22;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placements = navTrackMarkerPlacements(route);
    if (placements.isEmpty) return const SizedBox.shrink();
    final units = ref.watch(unitFormatterProvider);
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return MarkerLayer(
      markers: [
        for (final placement in placements)
          Marker(
            point: placement.latLng,
            width: _size,
            height: _size,
            child: Tooltip(
              key: ValueKey('nav-track-marker-${placement.number}'),
              triggerMode: TooltipTriggerMode.tap,
              message: _details(l10n, units, placement),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.tertiary,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.onTertiary, width: 1.5),
                ),
                child: Text(
                  '${placement.number}',
                  style: TextStyle(
                    color: scheme.onTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _details(
    AppLocalizations l10n,
    UnitFormatter units,
    NavTrackMarkerPlacement placement,
  ) {
    final point = placement.point;
    final time = DateTime.fromMillisecondsSinceEpoch(
      point.timestamp * 1000,
      isUtc: true,
    );
    final distance = point.distance;
    return l10n.navTrack_marker_details(
      placement.number,
      units.formatTime(time),
      units.formatDepth(point.depth),
      distance == null ? '-' : units.formatDistance(distance),
    );
  }
}
