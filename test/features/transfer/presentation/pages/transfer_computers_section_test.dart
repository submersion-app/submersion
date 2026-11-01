import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/router/app_router.dart';
import 'package:submersion/features/dive_computer/presentation/providers/auto_connect_settings_provider.dart';
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/clock_sync_global_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/transfer/presentation/pages/transfer_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Host API stub that records discovery calls without touching a platform
/// channel, mirroring `discovery_scan_for_address_test.dart`.
class _FakeHostApi extends pigeon.DiveComputerHostApi {
  int startDiscoveryCalls = 0;
  int stopDiscoveryCalls = 0;

  @override
  Future<void> startDiscovery(pigeon.TransportType transport) async {
    startDiscoveryCalls++;
  }

  @override
  Future<void> stopDiscovery() async {
    stopDiscoveryCalls++;
  }
}

/// The Dive Computers tab was the last place leaking hardcoded English
/// (#152): its section header, dive count, download tooltip and
/// last-download label all render here.
void main() {
  String? previousDefaultLocale;

  setUp(() {
    previousDefaultLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousDefaultLocale;
  });

  final now = DateTime(2026, 3, 1, 12);

  DiveComputer computer({
    String id = 'dc-1',
    String name = 'Perdix 2',
    int diveCount = 3,
    DateTime? lastDownload,
    String? bluetoothAddress,
  }) => DiveComputer(
    id: id,
    name: name,
    manufacturer: 'Shearwater',
    model: name,
    diveCount: diveCount,
    lastDownload: lastDownload,
    bluetoothAddress: bluetoothAddress,
    createdAt: now,
    updatedAt: now,
  );

  Future<void> pumpComputersSection(
    WidgetTester tester,
    List<DiveComputer> computers, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/transfer?selected=computers',
      routes: [
        GoRoute(
          path: '/transfer',
          builder: (context, state) => const TransferPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allDiveComputersProvider.overrideWith((ref) async => computers),
          // Off by default here: none of these tests exercise auto-connect
          // (that is its own group below), and leaving it on would start a
          // real scan against no platform channel, whose "Searching..."
          // indicator is an indeterminate spinner that `pumpAndSettle`
          // never settles on.
          autoConnectKnownComputersProvider.overrideWith(
            (ref) => AutoConnectKnownComputersNotifier.unstored(false),
          ),
        ],
        child: MaterialApp.router(
          locale: locale,
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the known-computers section renders localized strings', (
    tester,
  ) async {
    await pumpComputersSection(tester, [
      computer(lastDownload: DateTime.now().subtract(const Duration(days: 3))),
    ]);

    expect(find.text('Known Computers'), findsOneWidget);
    expect(find.text('3 dives'), findsOneWidget);
    expect(find.text('3 days ago'), findsOneWidget);
    expect(find.byTooltip('Download dives'), findsOneWidget);
  });

  testWidgets('a single dive uses the singular count', (tester) async {
    await pumpComputersSection(tester, [computer(diveCount: 1)]);

    expect(find.text('1 dive'), findsOneWidget);
    expect(
      find.text('Never'),
      findsOneWidget,
      reason: 'a computer with no lastDownload reads Never',
    );
  });

  testWidgets('the section is omitted when no computers are known', (
    tester,
  ) async {
    await pumpComputersSection(tester, const []);

    expect(find.text('Known Computers'), findsNothing);
  });

  group('clock sync switch (#1910)', () {
    const switchKey = ValueKey('clock_sync_global_switch');

    testWidgets('sits above the connect card when no computers are known', (
      tester,
    ) async {
      await pumpComputersSection(tester, const []);

      expect(find.byKey(switchKey), findsOneWidget);
      expect(find.text('Sync dive computer clocks'), findsOneWidget);
      expect(tester.widget<Switch>(find.byKey(switchKey)).value, isFalse);
      expect(
        tester.getTopLeft(find.byKey(switchKey)).dy,
        lessThan(tester.getTopLeft(find.text('Connect New Computer')).dy),
      );
    });

    testWidgets('toggling it updates the installation setting', (tester) async {
      await pumpComputersSection(tester, [computer()]);

      await tester.tap(find.byKey(switchKey));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TransferPage)),
      );
      expect(
        container.read(clockSyncSettingsNotifierProvider).globalEnabled,
        isTrue,
      );
      expect(tester.widget<Switch>(find.byKey(switchKey)).value, isTrue);
    });

    testWidgets('the info icon shows the explanation as a tap tooltip', (
      tester,
    ) async {
      await pumpComputersSection(tester, const []);

      // Scoped to the clock sync switch: the auto-connect switch right
      // below it (issue #3361) has its own info icon on the same screen.
      await tester.tap(
        find.descendant(
          of: find.byType(ClockSyncGlobalSwitch),
          matching: find.byIcon(Icons.info_outline),
        ),
      );
      await tester.pump();

      expect(
        find.text(
          "Sets the clock to this device's time after each download. "
          'Applies to this device only.',
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('the strings follow the locale, not hardcoded English', (
    tester,
  ) async {
    await pumpComputersSection(tester, [
      computer(diveCount: 2),
    ], locale: const Locale('de'));

    expect(find.text('Bekannte Computer'), findsOneWidget);
    expect(find.text('2 Tauchgänge'), findsOneWidget);
    expect(find.text('Nie'), findsOneWidget);
    expect(find.byTooltip('Tauchgänge herunterladen'), findsOneWidget);
  });

  group('passive auto-connect scan, route-aware (issue #3361)', () {
    late _FakeHostApi hostApi;
    late pigeon.DiveComputerService service;

    /// A few bounded pumps, not `pumpAndSettle`: while this group's scan is
    /// active, the "Searching..." indicator's `CircularProgressIndicator`
    /// is an indeterminate animation `pumpAndSettle` never settles on.
    Future<void> pumpBriefly(WidgetTester tester) async {
      // Long enough to clear a route transition (~300ms default) and flush
      // pending microtasks, short enough to never reach the indeterminate
      // "Searching..." spinner's own animation loop.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    /// Registers `computersRouteObserver` on this test's own `GoRouter`,
    /// unlike `pumpComputersSection` above: only this group exercises the
    /// push/pop pause-resume path, so only it pays for the extra route.
    Future<GoRouter> pumpWithRouteObserver(
      WidgetTester tester, {
      List<DiveComputer> computers = const [],
    }) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      hostApi = _FakeHostApi();
      service = pigeon.DiveComputerService(hostApi: hostApi);
      final router = GoRouter(
        initialLocation: '/transfer?selected=computers',
        observers: [computersRouteObserver],
        routes: [
          GoRoute(
            path: '/transfer',
            builder: (context, state) => const TransferPage(),
            routes: [
              GoRoute(
                path: 'second',
                builder: (context, state) =>
                    const Scaffold(body: Text('Second page')),
              ),
            ],
          ),
          GoRoute(
            path: '/dive-computers/:id/download',
            builder: (context, state) => Scaffold(
              body: Text('Download page ${state.pathParameters['id']}'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveComputerServiceProvider.overrideWithValue(service),
            allDiveComputersProvider.overrideWith((ref) async => computers),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await pumpBriefly(tester);
      return router;
    }

    testWidgets('starts scanning once the section is on screen', (
      tester,
    ) async {
      await pumpWithRouteObserver(tester);

      expect(hostApi.startDiscoveryCalls, 1);
    });

    testWidgets('pauses while a child route (the discovery wizard, a computer '
        'detail or download page) is pushed on top, and resumes once back', (
      tester,
    ) async {
      final router = await pumpWithRouteObserver(tester);
      expect(hostApi.startDiscoveryCalls, 1);

      router.push('/transfer/second');
      await pumpBriefly(tester);
      expect(find.text('Second page'), findsOneWidget);
      expect(hostApi.stopDiscoveryCalls, 1);

      router.pop();
      await pumpBriefly(tester);
      expect(hostApi.startDiscoveryCalls, 2);
    });

    testWidgets('leaving the section stops the scan without modifying a '
        'provider while the tree is being torn down', (tester) async {
      await pumpWithRouteObserver(tester);
      expect(hostApi.startDiscoveryCalls, 1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(hostApi.stopDiscoveryCalls, 1);
    });

    testWidgets('a known computer in range opens its download page, the one '
        'that imports the dives', (tester) async {
      await pumpWithRouteObserver(
        tester,
        computers: [computer(bluetoothAddress: '11:22:33:44:55:66')],
      );

      service.onDeviceDiscovered(
        pigeon.DiscoveredDevice(
          vendor: 'Shearwater',
          product: 'Perdix 2',
          model: 10,
          address: '11:22:33:44:55:66',
          name: 'Perdix 2',
          transport: pigeon.TransportType.ble,
        ),
      );
      await pumpBriefly(tester);

      expect(find.text('Download page dc-1'), findsOneWidget);
    });
  });
}
