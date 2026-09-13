import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/site_types/presentation/pages/site_types_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Settings > Manage > Site Types (issue #1765).
void main() {
  late MockCurrentDiverIdNotifier diverIdNotifier;

  setUp(() async {
    await setUpTestDatabase();
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
    );
    diverIdNotifier = MockCurrentDiverIdNotifier();
    await diverIdNotifier.setCurrentDiver('diver-1');
  });

  tearDown(() async => tearDownTestDatabase());

  Widget page() => ProviderScope(
    overrides: [
      currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1'),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SiteTypesPage(),
    ),
  );

  testWidgets('lists translated built-ins without row actions', (tester) async {
    // Tall enough that the list builds all 16 built-in rows.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    expect(find.text('Reef'), findsOneWidget);
    expect(find.text('Kelp forest'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  testWidgets('adds a custom type from the FAB', (tester) async {
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Mine');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Mine'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('renames a custom type from its edit icon', (tester) async {
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO site_types (id, diver_id, name, is_built_in, sort_order, "
      "created_at, updated_at) VALUES ('mine', 'diver-1', 'Mine', 0, 100, 0, 0)",
    );
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Flooded mine');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Flooded mine'), findsOneWidget);
  });

  testWidgets('deleting a type in use confirms with the site count', (
    tester,
  ) async {
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO site_types (id, diver_id, name, is_built_in, sort_order, "
      "created_at, updated_at) VALUES ('mine', 'diver-1', 'Mine', 0, 100, 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO dive_sites (id, name, created_at, updated_at) "
      "VALUES ('s1', 'Site', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO site_site_types (id, site_id, site_type_id, created_at) "
      "VALUES ('j', 's1', 'mine', 0)",
    );

    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.textContaining('used by 1 site'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Mine'), findsNothing);
  });
}
