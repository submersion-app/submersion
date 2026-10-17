import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:submersion/features/maps/presentation/widgets/map_compass_button.dart';
import 'package:submersion/features/maps/presentation/widgets/map_style_button.dart';

/// The standard column of on-map buttons: the map style switcher, with the
/// reset-to-north compass below it when the map can rotate.
///
/// The style button takes the top slot because it is always visible; the
/// compass is invisible while the map is north-up, so placing it first would
/// leave an empty gap above the style button. Wrap it in a [Positioned] in
/// the [Stack] that hosts the map.
class MapCornerControls extends StatelessWidget {
  const MapCornerControls({super.key, this.controller});

  /// The map's controller, which the compass steers. Null for a map that has
  /// no compass.
  final MapController? controller;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MapStyleButton(),
        if (controller != null) ...[
          const SizedBox(height: 8),
          MapCompassButton(controller: controller),
        ],
      ],
    );
  }
}
