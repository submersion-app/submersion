import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/maps/presentation/widgets/map_compass_button.dart';
import 'package:submersion/features/maps/presentation/widgets/map_style_button.dart';
import 'package:submersion/features/maps/presentation/widgets/my_location_button.dart';

/// The standard column of on-map buttons: the map style switcher, then Show
/// my location when the map asks for it, with the reset-to-north compass
/// below them when the map can rotate.
///
/// The always-visible buttons take the top slots; the compass is invisible
/// while the map is north-up, so placing it above them would leave an empty
/// gap. Wrap it in a [Positioned] in the [Stack] that hosts the map.
class MapCornerControls extends StatelessWidget {
  const MapCornerControls({super.key, this.controller, this.onLocated});

  /// The map's controller, which the compass steers. Null for a map that has
  /// no compass.
  final MapController? controller;

  /// Adds a Show my location button that hands the device's fix here, for a
  /// map whose app bar has no room for one (#4808). Null leaves it out.
  final ValueChanged<LatLng>? onLocated;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    final onLocated = this.onLocated;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MapStyleButton(),
        if (onLocated != null) ...[
          const SizedBox(height: 8),
          _RoundControl(
            child: MyLocationButton(onLocated: onLocated, iconSize: 22),
          ),
        ],
        if (controller != null) ...[
          const SizedBox(height: 8),
          MapCompassButton(controller: controller),
        ],
      ],
    );
  }
}

/// The round, raised face [MapStyleButton] and [MapCompassButton] wear, so a
/// button set among them reads as part of the same column.
class _RoundControl extends StatelessWidget {
  const _RoundControl({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      elevation: 2,
      shape: CircleBorder(side: BorderSide(color: colorScheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox.square(dimension: 44, child: child),
    );
  }
}
