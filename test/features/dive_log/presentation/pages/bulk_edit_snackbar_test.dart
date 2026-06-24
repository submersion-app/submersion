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

/// Regression tests for issue #406: the "Updated N dives" banner shown after a
/// bulk edit must auto-hide AND offer a way to close it.
///
/// Root cause: `SnackBar.persist` defaults to `true` when an `action` is set
/// (Flutter's `persist = persist ?? action != null`), so the Undo snackbar's
/// auto-dismiss timer fired but did nothing, and without `showCloseIcon` there
/// was no neutral way to dismiss it.
void main() {
  group('Bulk edit "Updated N dives" snackbar (issue #406)', () {
    late DiveRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = DiveRepository();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    List<dynamic> buildOverrides(List<dynamic> base) {
      return [
        ...base,
        diveRepositoryProvider.overrideWithValue(repository),
        diveListNotifierProvider.overrideWith((ref) {
          return DiveListNotifier(repository, ref);
        }),
        customTankPresetsProvider.overrideWith((ref) async => []),
      ];
    }

    /// Pumps the real (non-embedded) bulk-edit flow inside a router whose
    /// `/dives` destination mirrors production navigation, enables the Favorite
    /// field, then Saves + confirms. Returns with the snackbar on screen.
    Future<void> pumpBulkSaveFlow(WidgetTester tester) async {
      final d1 = await repository.createDive(
        createTestDiveWithBottomTime().copyWith(id: 'snack-1'),
      );
      final d2 = await repository.createDive(
        createTestDiveWithBottomTime().copyWith(id: 'snack-2'),
      );

      final router = GoRouter(
        initialLocation: '/dives',
        routes: [
          ShellRoute(
            builder: (context, state, child) => Scaffold(
              body: child,
              bottomNavigationBar: const SizedBox(height: 56),
            ),
            routes: [
              GoRoute(
                path: '/dives',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: Scaffold(body: Center(child: Text('Dive List'))),
                ),
                routes: [
                  GoRoute(
                    path: 'bulk-edit',
                    builder: (context, state) {
                      final ids = (state.extra as List<dynamic>?)
                          ?.cast<String>();
                      return BulkDiveEditPage(diveIds: ids ?? const []);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(overrides).cast(),
          child: MaterialApp.router(
            scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      router.go('/dives/bulk-edit', extra: [d1.id, d2.id]);
      await tester.pumpAndSettle();

      // Enable the Favorite gate + flip its toggle on so the save has an effect.
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
      // Stage pumps so the SnackBar entrance completes and the auto-dismiss
      // timer is created (a single large pump would skip that build).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('auto-hides after its duration', (tester) async {
      await pumpBulkSaveFlow(tester);

      expect(find.text('Updated 2 dives'), findsOneWidget);

      // Wait past the 5s duration + exit animation.
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('Updated 2 dives'),
        findsNothing,
        reason: 'the banner must auto-dismiss after its duration',
      );
    });

    testWidgets('offers a close affordance that dismisses it', (tester) async {
      await pumpBulkSaveFlow(tester);

      expect(find.text('Updated 2 dives'), findsOneWidget);

      // A close icon must exist so the user can dismiss the banner without
      // tapping Undo (which would revert the edit).
      final closeIcon = find.descendant(
        of: find.byType(SnackBar),
        matching: find.byIcon(Icons.close),
      );
      expect(closeIcon, findsOneWidget, reason: 'banner needs a close button');

      await tester.tap(closeIcon);
      await tester.pumpAndSettle();

      expect(
        find.text('Updated 2 dives'),
        findsNothing,
        reason: 'tapping the close icon must dismiss the banner',
      );
    });
  });
}
