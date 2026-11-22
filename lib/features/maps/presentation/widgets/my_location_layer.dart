import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/maps/presentation/providers/device_location_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The blue dot that marks the device on a map (issue #4808).
///
/// Place it in a `FlutterMap`'s children after the site markers so the dot
/// draws on top. It draws nothing until [MyLocationButton] has found a fix,
/// and nothing again once that fix lapses.
class MyLocationLayer extends ConsumerWidget {
  const MyLocationLayer({super.key});

  static const _dotSize = 18.0;
  static const _haloSize = 40.0;

  /// The conventional "you are here" blue, fixed rather than themed so the
  /// dot reads the same on every map style and colour scheme.
  static const _blue = Color(0xFF1A73E8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final point = ref.watch(deviceLocationNotifierProvider);
    if (point == null) return const SizedBox.shrink();

    return MarkerLayer(
      markers: [
        Marker(
          point: point,
          width: _haloSize,
          height: _haloSize,
          // Display only, so a site marker under the dot still takes taps.
          child: IgnorePointer(
            child: Semantics(
              label: context.l10n.maps_myLocation_markerLabel,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _blue.withValues(alpha: 0.18),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: _dotSize,
                  height: _dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _blue,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
