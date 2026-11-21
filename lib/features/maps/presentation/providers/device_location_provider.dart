import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';

/// Where the device was when a map's Show my location button last found it
/// (issue #4808), or null before the first fix.
///
/// Held in memory only and shared by every map, so the blue dot found on one
/// map is still drawn when another map opens. Nothing is ever stored.
class DeviceLocationNotifier extends Notifier<LatLng?> {
  @override
  LatLng? build() => null;

  /// Records a fresh fix at [point].
  void located(LatLng point) => state = point;
}

final deviceLocationProvider =
    NotifierProvider<DeviceLocationNotifier, LatLng?>(
      DeviceLocationNotifier.new,
    );
