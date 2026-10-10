import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import 'package:submersion/core/network/proxy/proxy_controller.dart';

/// Re-asks the OS for its proxy when the app returns to the foreground or the
/// network changes, the two moments a laptop or phone typically moves between
/// office, home and travel networks.
class ProxyRefreshTriggers {
  ProxyRefreshTriggers(
    ProxyController controller, {
    Stream<Object?>? networkChanges,
    bool listenToLifecycle = true,
  }) {
    _network = (networkChanges ?? Connectivity().onConnectivityChanged).listen(
      (_) => unawaited(controller.refresh()),
    );
    if (listenToLifecycle) {
      _lifecycle = AppLifecycleListener(
        onResume: () => unawaited(controller.refresh()),
      );
    }
  }

  late final StreamSubscription<Object?> _network;
  AppLifecycleListener? _lifecycle;

  void dispose() {
    unawaited(_network.cancel());
    _lifecycle?.dispose();
  }
}
