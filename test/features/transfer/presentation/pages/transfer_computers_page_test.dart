import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/router/app_router.dart';
import 'package:submersion/core/router/nav_shortcut_pages.dart';
import 'package:submersion/features/dive_computer/presentation/providers/auto_connect_settings_provider.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/transfer/presentation/pages/transfer_computers_page.dart';
import 'package:submersion/features/transfer/presentation/widgets/computers_section_content.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The Dive Computers nav shortcut opens Transfer's section on a page of its
/// own (#4210).
void main() {
  String? previousDefaultLocale;

  setUp(() {
    previousDefaultLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousDefaultLocale;
  });

  Future<void> pumpShortcut(WidgetTester tester, {Size? size}) async {
    await tester.binding.setSurfaceSize(size ?? const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/shortcut/transfer-computers',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SizedBox()),
        navShortcutRoute(),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allDiveComputersProvider.overrideWith((ref) async => const []),
          // Off: a real scan against no platform channel shows an
          // indeterminate spinner that pumpAndSettle never settles on.
          autoConnectKnownComputersProvider.overrideWith(
            (ref) => AutoConnectKnownComputersNotifier.unstored(false),
          ),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the section under its own title, with no back arrow', (
    tester,
  ) async {
    await pumpShortcut(tester);

    expect(find.byType(TransferComputersPage), findsOneWidget);
    expect(find.byType(ComputersSectionContent), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Dive Computers'),
      ),
      findsOneWidget,
    );
    expect(find.byType(BackButton), findsNothing);
    expect(find.text('Connect New Computer'), findsOneWidget);
  });

  testWidgets('a wide window shows the same page', (tester) async {
    await pumpShortcut(tester, size: const Size(1200, 900));

    expect(find.byType(ComputersSectionContent), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  group('passive auto-connect scan on the alias route', () {
    late _FakeHostApi hostApi;

    /// Bounded pumps: the "Searching..." spinner never lets pumpAndSettle
    /// settle while the scan runs.
    Future<void> pumpBriefly(WidgetTester tester) async {
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    /// The alias route inside a shell, with the router-wide observer, as the
    /// app builds it; a page pushed on top stands for the discovery wizard
    /// or a download page.
    Future<GoRouter> pumpInShell(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      hostApi = _FakeHostApi();
      final service = pigeon.DiveComputerService(hostApi: hostApi);
      final now = DateTime(2026, 3, 1, 12);
      final known = [
        DiveComputer(
          id: 'dc-1',
          name: 'Perdix 2',
          manufacturer: 'Shearwater',
          model: 'Perdix 2',
          bluetoothAddress: 'AA:BB:CC:DD:EE:FF',
          createdAt: now,
          updatedAt: now,
        ),
      ];
      final router = GoRouter(
        navigatorKey: GlobalKey<NavigatorState>(),
        initialLocation: '/shortcut/transfer-computers',
        observers: [computersRouteObserver],
        routes: [
          ShellRoute(
            builder: (context, state, child) => child,
            routes: [
              GoRoute(path: '/', builder: (context, state) => const SizedBox()),
              navShortcutRoute(),
              GoRoute(
                path: '/covering',
                builder: (context, state) =>
                    const Scaffold(body: Text('Covering page')),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveComputerServiceProvider.overrideWithValue(service),
            allDiveComputersProvider.overrideWith((ref) async => known),
          ],
          child: MaterialApp.router(
            locale: const Locale('en'),
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await pumpBriefly(tester);
      return router;
    }

    testWidgets('starts on the shortcut page, pauses under a pushed page and '
        'resumes once back', (tester) async {
      final router = await pumpInShell(tester);
      expect(find.byType(TransferComputersPage), findsOneWidget);
      expect(hostApi.startDiscoveryCalls, 1);

      router.push('/covering');
      await pumpBriefly(tester);
      expect(find.text('Covering page'), findsOneWidget);
      expect(hostApi.stopDiscoveryCalls, 1);

      router.pop();
      await pumpBriefly(tester);
      expect(hostApi.startDiscoveryCalls, 2);
    });

    testWidgets('leaving the shortcut page stops the scan', (tester) async {
      final router = await pumpInShell(tester);
      expect(hostApi.startDiscoveryCalls, 1);

      router.go('/');
      await pumpBriefly(tester);

      expect(find.byType(TransferComputersPage), findsNothing);
      // Replacing the page reaches the section twice, as the new page lands
      // on top (didPushNext) and again as it is disposed; release() is
      // idempotent, so what matters is that the scan stopped and stays so.
      expect(hostApi.stopDiscoveryCalls, greaterThanOrEqualTo(1));
      expect(hostApi.startDiscoveryCalls, 1);
    });
  });
}

/// Host API stub that counts discovery calls without a platform channel, as
/// `transfer_computers_section_test.dart` does.
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
