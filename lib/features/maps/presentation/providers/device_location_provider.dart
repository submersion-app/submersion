import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
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
  DateTime? _foundAt;
  AppLifecycleListener? _lifecycle;

  @override
  LatLng? build() {
    // The timer below runs on the app's own clock, which stands still while
    // the app is suspended or the device sleeps. Coming back, the wall clock
    // says how long it really was.
    _lifecycle = AppLifecycleListener(onResume: _dropIfStale);
    ref.onDispose(() {
      _expiry?.cancel();
      _lifecycle?.dispose();
    });
    return null;
  }

  /// Records a fresh fix at [point], which lapses after [maxAge].
  void located(LatLng point) {
    _expiry?.cancel();
    _expiry = Timer(maxAge, _drop);
    _foundAt = clock.now();
    state = point;
  }

  void _dropIfStale() {
    final foundAt = _foundAt;
    if (foundAt != null && !clock.now().isBefore(foundAt.add(maxAge))) {
      _drop();
    }
  }

  void _drop() {
    _expiry?.cancel();
    _expiry = null;
    _foundAt = null;
    state = null;
  }
}

final deviceLocationNotifierProvider =
    NotifierProvider<DeviceLocationNotifier, LatLng?>(
      DeviceLocationNotifier.new,
    );
