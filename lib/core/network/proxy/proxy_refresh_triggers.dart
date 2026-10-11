import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import 'package:submersion/core/network/proxy/proxy_controller.dart';

/// Re-asks the OS for its proxy when the app returns to the foreground or the
/// network changes, the two moments a laptop or phone typically moves between
/// office, home and travel networks.
///
/// On desktop every window focus is a resume, so resume refreshes are
/// limited to one per [resumeInterval]; a network change always refreshes.
class ProxyRefreshTriggers {
  ProxyRefreshTriggers(
    this._controller, {
    Stream<Object?>? networkChanges,
    bool listenToLifecycle = true,
    this.resumeInterval = const Duration(minutes: 1),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _network = (networkChanges ?? Connectivity().onConnectivityChanged).listen(
      (_) => unawaited(_controller.refresh()),
    );
    if (listenToLifecycle) {
      _lifecycle = AppLifecycleListener(onResume: onResume);
    }
  }

  final ProxyController _controller;
  final Duration resumeInterval;
  final DateTime Function() _clock;
  late final StreamSubscription<Object?> _network;
  AppLifecycleListener? _lifecycle;
  DateTime? _lastResumeRefresh;

  /// The app came back to the foreground.
  @visibleForTesting
  void onResume() {
    final now = _clock();
    final last = _lastResumeRefresh;
    if (last != null && now.difference(last) < resumeInterval) return;
    _lastResumeRefresh = now;
    unawaited(_controller.refresh());
  }

  void dispose() {
    unawaited(_network.cancel());
    _lifecycle?.dispose();
  }
}
