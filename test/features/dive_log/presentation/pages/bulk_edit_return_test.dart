import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/pages/bulk_dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_field_gate.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Bulk edit opened from a dive list PUSHED over another page (a site's
/// dives, say) returns to that list on save, so the page under it and its
/// back arrow survive (#3292). Opened from the Dives tab it still goes to
/// /dives as before.
void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<GoRouter> pumpRouter(WidgetTester tester, String initial) async {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        ShellRoute(
          builder: (context, state, child) => Scaffold(body: child),
          routes: [
            GoRoute(
              path: '/root',
              builder: (_, _) => const Scaffold(body: Text('ROOT')),
            ),
            GoRoute(
              path: '/dives',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: Scaffold(body: Center(child: Text('Dive List'))),
              ),
              routes: [
                GoRoute(
                  path: 'bulk-edit',
                  builder: (context, state) => BulkDiveEditPage(
                    diveIds:
                        (state.extra as List<dynamic>?)?.cast<String>() ??
                        const [],
                    popOnSave: state.uri.queryParameters['return'] == 'pop',
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
        ].cast(),
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<List<String>> createDives() async {
    final d1 = await repository.createDive(
      createTestDiveWithBottomTime().copyWith(id: 'ret-1'),
    );
    final d2 = await repository.createDive(
      createTestDiveWithBottomTime().copyWith(id: 'ret-2'),
    );
    return [d1.id, d2.id];
  }

  /// Turns the Favorite field on, then Saves and confirms.
  Future<void> saveFavorite(WidgetTester tester) async {
    final favoriteGate = find.ancestor(
      of: find.text('Favorite'),
      matching: find.byType(BulkFieldGate),
    );
    await tester.tap(
      find.descendant(of: favoriteGate, matching: find.byType(Checkbox)),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: favoriteGate, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('from a pushed list, save returns to it and keeps the page '
      'under it', (tester) async {
    final ids = await createDives();
    final router = await pumpRouter(tester, '/root');
    router.push('/dives');
    await tester.pumpAndSettle();
    router.push('/dives/bulk-edit?return=pop', extra: ids);
    await tester.pumpAndSettle();

    await saveFavorite(tester);

    expect(find.text('Dive List'), findsOneWidget);
    expect(router.canPop(), isTrue, reason: 'save must not go()');
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('ROOT'), findsOneWidget);
  });

  testWidgets('from the Dives tab, save still goes to /dives', (tester) async {
    final ids = await createDives();
    final router = await pumpRouter(tester, '/dives');
    router.push('/dives/bulk-edit', extra: ids);
    await tester.pumpAndSettle();

    await saveFavorite(tester);

    expect(find.text('Dive List'), findsOneWidget);
    expect(router.canPop(), isFalse);
  });
}
