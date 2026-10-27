import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/database/database.dart' show NearbyPeer;
import 'package:submersion/core/services/nearby/nearby_link_manager.dart';
import 'package:submersion/core/services/nearby/nearby_sync_protocol.dart'
    show NearbySyncOutcome;
import 'package:submersion/core/services/nearby/nearby_peer_store.dart';
import 'package:submersion/features/settings/presentation/providers/nearby_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/sync/nearby_devices_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

class _Behavior extends StateNotifier<SyncBehaviorSettings>
    implements SyncBehaviorNotifier {
  _Behavior(bool nearby)
    : super(
        SyncBehaviorSettings(
          autoSyncEnabled: false,
          syncOnLaunch: true,
          syncOnResume: true,
          nearbyAutoEnabled: nearby,
        ),
      );

  final calls = <bool>[];

  @override
  Future<void> setNearbyAutoEnabled(bool value) async {
    calls.add(value);
    state = state.copyWith(nearbyAutoEnabled: value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The peers table in memory: a live Drift stream inside the widget tree
/// deadlocks testWidgets' fake clock, so the store's own tests cover Drift.
class _Peers implements NearbyPeerStore {
  final _rows = <NearbyPeer>[];
  final _controller = StreamController<List<NearbyPeer>>.broadcast();

  void _emit() => _controller.add(List.of(_rows));

  void add(NearbyPeer peer) {
    _rows.add(peer);
    _emit();
  }

  @override
  Stream<List<NearbyPeer>> watchAll() async* {
    yield List.of(_rows);
    yield* _controller.stream;
  }

  @override
  NearbyPeerError? errorOf(NearbyPeer peer) => nearbyPeerErrorOf(peer);

  @override
  Future<void> rename(String id, String name) async {
    final i = _rows.indexWhere((r) => r.peerDeviceId == id);
    _rows[i] = _rows[i].copyWith(displayName: name);
    _emit();
  }

  @override
  Future<void> remove(String id) async {
    _rows.removeWhere((r) => r.peerDeviceId == id);
    _emit();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Manager implements NearbyLinkManager {
  _Manager(this.peers);

  final _Peers peers;
  final syncs = <String>[];

  @override
  Future<NearbySyncOutcome?> syncNow(String peerDeviceId) async {
    syncs.add(peerDeviceId);
    return null;
  }

  @override
  Future<void> unpair(String peerDeviceId) => peers.remove(peerDeviceId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Peers store;
  late _Manager manager;

  setUp(() {
    store = _Peers();
    manager = _Manager(store);
  });

  Future<({_Behavior behavior, List<String> pushed})> pump(
    WidgetTester tester, {
    bool nearby = true,
    bool canAdvertise = true,
    Map<String, NearbySyncProgress> progress = const {},
  }) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final behavior = _Behavior(nearby);
    final pushed = <String>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: SingleChildScrollView(child: NearbyDevicesSection()),
          ),
        ),
        GoRoute(
          path: NearbyDevicesSection.pairRoute,
          builder: (_, _) {
            pushed.add(NearbyDevicesSection.pairRoute);
            return const Scaffold();
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(nearbyLinkManager: manager),
          syncBehaviorProvider.overrideWith((ref) => behavior),
          nearbyPeerStoreProvider.overrideWithValue(store),
          nearbyPeersProvider.overrideWith((ref) => store.watchAll()),
          nearbyProgressProvider.overrideWith((ref) => Stream.value(progress)),
          nearbyCanAdvertiseProvider.overrideWithValue(canAdvertise),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (behavior: behavior, pushed: pushed);
  }

  void seed() {
    final now = DateTime.now().millisecondsSinceEpoch;
    store
      ..add(
        NearbyPeer(
          peerDeviceId: 'mac',
          displayName: 'MacBook',
          pairedAt: 1,
          lastSyncedAt: now - 5 * 60 * 1000,
          lastSeenAt: now - 5 * 60 * 1000,
        ),
      )
      ..add(
        NearbyPeer(
          peerDeviceId: 'ipad',
          displayName: 'Old iPad',
          pairedAt: 2,
          lastError: NearbyPeerError.peerOlderApp.name,
        ),
      );
  }

  testWidgets('lists each paired device with its status line', (tester) async {
    seed();
    await pump(tester);
    expect(find.text('Nearby devices'), findsOneWidget);
    expect(find.text('MacBook'), findsOneWidget);
    expect(find.text('Synced 5 minutes ago'), findsOneWidget);
    expect(find.text('Old iPad'), findsOneWidget);
    expect(find.text('That device needs a newer app version'), findsOneWidget);
    expect(find.text('Pair a device'), findsOneWidget);
  });

  testWidgets('a running transfer shows its progress', (tester) async {
    seed();
    await pump(
      tester,
      progress: const {
        'mac': NearbySyncProgress(peerDeviceId: 'mac', done: 1024, total: 4096),
      },
    );
    expect(find.text('Syncing: 1.0 KB of 4.0 KB'), findsOneWidget);
  });

  testWidgets('toggling the switch saves the device-local setting', (
    tester,
  ) async {
    final r = await pump(tester);
    await tester.tap(find.byKey(const Key('nearby-auto')));
    await tester.pumpAndSettle();
    expect(r.behavior.calls, [false]);
  });

  testWidgets('Linux explains it can only be found by advertisers', (
    tester,
  ) async {
    await pump(tester, canAdvertise: false);
    expect(
      find.textContaining('Other devices cannot find this computer'),
      findsOneWidget,
    );
  });

  testWidgets('Pair a device pushes the pairing route', (tester) async {
    final r = await pump(tester);
    await tester.tap(find.byKey(const Key('nearby-pair')));
    await tester.pumpAndSettle();
    expect(r.pushed, [NearbyDevicesSection.pairRoute]);
  });

  testWidgets('the sheet renames a device', (tester) async {
    seed();
    await pump(tester);
    await tester.tap(find.text('MacBook'));
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Sync Now'), findsOneWidget);
    expect(find.text('Unpair'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nearby-sheet-rename')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('nearby-rename-field')),
      'Work Mac',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Work Mac'), findsOneWidget);
  });

  testWidgets('sync now on a device out of range says so', (tester) async {
    seed();
    await pump(tester);
    await tester.tap(find.text('MacBook'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nearby-sheet-sync')));
    await tester.pumpAndSettle();
    expect(find.text('MacBook is not nearby right now'), findsOneWidget);
  });

  testWidgets('unpair asks first, then removes the device', (tester) async {
    seed();
    await pump(tester);
    await tester.tap(find.text('Old iPad'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nearby-sheet-unpair')));
    await tester.pumpAndSettle();
    expect(
      find.text('Unpair Old iPad? It will need pairing again to sync nearby.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('nearby-unpair-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Old iPad'), findsNothing);
  });
}
