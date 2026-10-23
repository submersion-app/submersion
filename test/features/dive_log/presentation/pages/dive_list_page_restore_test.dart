import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/providers/table_details_pane_provider.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Coming back to the Dives section on a wide window reopens the dive the
/// diver last opened in the detail pane (#3301).
void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<({GoRouter router, ProviderContainer container})> pumpHarness(
    WidgetTester tester, {
    List<dynamic> extraOverrides = const [],
  }) async {
    final overrides = [
      ...await getBaseOverrides(),
      diveRepositoryProvider.overrideWithValue(repository),
      diveListNotifierProvider.overrideWith(
        (ref) => DiveListNotifier(repository, ref),
      ),
      paginatedDiveListProvider.overrideWith(
        (ref) => PaginatedDiveListNotifier(repository, ref),
      ),
      customTankPresetsProvider.overrideWith((ref) async => []),
      ...extraOverrides,
    ];

    final router = GoRouter(
      initialLocation: '/root',
      routes: [
        GoRoute(
          path: '/root',
          builder: (_, _) => const Scaffold(body: Text('ROOT')),
        ),
        GoRoute(path: '/dives', builder: (_, _) => const DiveListPage()),
      ],
    );
    addTearDown(router.dispose);

    final originalOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.toString().contains('overflowed')) return;
      originalOnError?.call(d);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MediaQuery(
          data: const MediaQueryData(size: Size(1400, 900)),
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    return (router: router, container: container);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  }

  String location(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  testWidgets('list view reopens the last-opened dive', (tester) async {
    await repository.createDive(
      createTestDiveWithBottomTime().copyWith(id: 'first'),
    );
    await repository.createDive(
      createTestDiveWithBottomTime().copyWith(id: 'opened'),
    );
    final h = await pumpHarness(tester);
    h.container.read(highlightedDiveIdProvider.notifier).state = 'opened';

    h.router.go('/dives');
    await settle(tester);

    expect(location(h.router), '/dives?selected=opened');
  });

  testWidgets('table view with its detail pane reopens the last-opened dive', (
    tester,
  ) async {
    await repository.createDive(
      createTestDiveWithBottomTime().copyWith(id: 'opened'),
    );
    final h = await pumpHarness(
      tester,
      extraOverrides: [
        diveListViewModeProvider.overrideWith((ref) => ListViewMode.table),
        tableDetailsPaneProvider('dives').overrideWith((ref) => true),
      ],
    );
    h.container.read(highlightedDiveIdProvider.notifier).state = 'opened';

    h.router.go('/dives');
    await settle(tester);

    expect(location(h.router), '/dives?selected=opened');
  });

  testWidgets('a deleted dive is not reopened', (tester) async {
    await repository.createDive(
      createTestDiveWithBottomTime().copyWith(id: 'kept'),
    );
    final h = await pumpHarness(tester);
    h.container.read(highlightedDiveIdProvider.notifier).state = 'deleted';

    h.router.go('/dives');
    await settle(tester);

    expect(location(h.router), '/dives');
  });
}
