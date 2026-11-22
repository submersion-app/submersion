import 'dart:async';

import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';

/// Where the device was when a map's Show my location button last found it
/// (issue #4808), or null before the first fix or once that fix is older than
/// [maxAge].
///
/// Held in memory only and shared by every map, so the blue dot found on one
/// map is still drawn when another map opens. The fix lapses after [maxAge]
/// because the dot claims to be where the device is now: a fix from the
/// morning, kept while the app stays open, would put the diver at home.
/// Nothing is ever stored.
class DeviceLocationNotifier extends Notifier<LatLng?> {
  /// How long a fix stands for the device's position.
  static const maxAge = Duration(minutes: 10);

  Timer? _expiry;

  @override
  LatLng? build() {
    ref.onDispose(() => _expiry?.cancel());
    return null;
  }

  /// Records a fresh fix at [point], which lapses after [maxAge].
  void located(LatLng point) {
    _expiry?.cancel();
    _expiry = Timer(maxAge, () => state = null);
    state = point;
  }
}

final deviceLocationNotifierProvider =
    NotifierProvider<DeviceLocationNotifier, LatLng?>(
      DeviceLocationNotifier.new,
    );
