import 'dart:async';

import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_hello.dart';
import 'package:submersion/core/services/nearby/nearby_link_manager.dart';
import 'package:submersion/core/services/nearby/nearby_sync_protocol.dart';

/// A link manager that touches no radio, for widget tests of screens that
/// start or read the nearby link. Records the calls the app root makes.
class FakeNearbyLinkManager implements NearbyLinkManager {
  final foreground = <bool>[];
  int refreshes = 0;
  NearbyAvailability availability = NearbyAvailability.ready;

  @override
  Future<void> setForeground(bool inForeground) async =>
      foreground.add(inForeground);

  @override
  Future<void> refresh() async => refreshes++;

  @override
  Future<void> enterPairingMode() async {}

  @override
  Future<void> leavePairingMode() async {}

  @override
  Future<NearbyAvailability> checkAvailability() async => availability;

  @override
  Future<NearbySyncOutcome?> syncNow(String peerDeviceId) async => null;

  @override
  Future<void> unpair(String peerDeviceId) async {}

  @override
  Stream<NearbySyncProgress> get progress => const Stream.empty();

  @override
  Stream<void> get applied => const Stream.empty();

  @override
  Stream<NearbyLinkState> get states => const Stream.empty();

  @override
  Stream<List<NearbyPairingHandle>> get pendingPairings => const Stream.empty();

  @override
  List<NearbyPairingHandle> get currentPairings => const [];

  @override
  Stream<NearbyErrorCode> get pairingRefusals => const Stream.empty();

  @override
  NearbyLinkState get state => NearbyLinkState.off;

  @override
  bool get canAdvertise => true;

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
