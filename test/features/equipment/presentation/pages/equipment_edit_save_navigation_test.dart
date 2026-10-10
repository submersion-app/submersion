import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The full-page new-equipment form saves from the app bar only, then returns
/// to the list it was opened from. A second "Add Equipment" button at the end
/// of the form read as a second, different action (#3174).
void main() {
  group('EquipmentEditPage full-page save', () {
    late EquipmentRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = EquipmentRepository();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    Future<GoRouter> pumpNewItemForm(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 4000);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final router = GoRouter(
        initialLocation: '/equipment',
        routes: [
          ShellRoute(
            builder: (context, state, child) => Scaffold(body: child),
            routes: [
              GoRoute(
                path: '/equipment',
                builder: (context, state) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => context.push('/equipment/new'),
                      child: const Text('equipment list'),
                    ),
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const EquipmentEditPage(),
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
            equipmentRepositoryProvider.overrideWithValue(repository),
          ].cast(),
          child: MaterialApp.router(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('equipment list'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Primary Reg');
      await tester.pump();
      return router;
    }

    testWidgets('Save in the app bar is the only save action', (tester) async {
      await pumpNewItemForm(tester);

      expect(find.text('Save'), findsOneWidget);
      // The tall viewport lays out the whole lazy form, down to its end.
      expect(find.text('Notifications (Optional)'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('Add Equipment'), findsNothing);
    });

    testWidgets('Save stores the item and returns to the list', (tester) async {
      final router = await pumpNewItemForm(tester);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/equipment');
      expect(find.byType(EquipmentEditPage), findsNothing);
      final saved = await repository.getAllEquipment();
      expect(saved.map((e) => e.name), ['Primary Reg']);
    });
  });
}
