import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart';
import 'package:submersion/features/dive_roles/presentation/pages/dive_roles_page.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

Future<void> _insertDiver() async {
  final db = DatabaseService.instance.database;
  await db.customStatement(
    "INSERT INTO divers (id, name, created_at, updated_at) "
    "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
  );
}

Widget _buildPage(MockCurrentDiverIdNotifier diverIdNotifier) {
  return ProviderScope(
    overrides: [
      currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1'),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DiveRolesPage(),
    ),
  );
}

void main() {
  late MockCurrentDiverIdNotifier diverIdNotifier;

  setUp(() async {
    await setUpTestDatabase();
    await _insertDiver();
    diverIdNotifier = MockCurrentDiverIdNotifier();
    await diverIdNotifier.setCurrentDiver('diver-1');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  testWidgets('shows built-in section with localized roles and no delete '
      'affordance on built-ins', (tester) async {
    await tester.pumpWidget(_buildPage(diverIdNotifier));
    await tester.pumpAndSettle();

    expect(find.text('Built-in Dive Roles'), findsOneWidget);
    expect(find.text('Rear Guard'), findsOneWidget);
    expect(find.text('Divemaster'), findsOneWidget);
    // Built-ins only: no custom header and no delete icons.
    expect(find.text('Custom Dive Roles'), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('add dialog creates a custom role listed under Custom', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPage(diverIdNotifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Hekkensluiter');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Custom Dive Roles'), findsOneWidget);
    expect(find.text('Hekkensluiter'), findsWidgets);
  });

  testWidgets('rename dialog renames a custom role', (tester) async {
    final repo = DiveRoleRepository();
    await repo.createDiveRole(name: 'Hekkensluiter', diverId: 'diver-1');

    await tester.pumpWidget(_buildPage(diverIdNotifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Rename Dive Role'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Sweep');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Sweep'), findsOneWidget);
    expect(find.text('Hekkensluiter'), findsNothing);
  });

  testWidgets('deleting an in-use custom role is blocked with a snackbar', (
    tester,
  ) async {
    final repo = DiveRoleRepository();
    final custom = await repo.createDiveRole(
      name: 'Hekkensluiter',
      diverId: 'diver-1',
    );
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO dives (id, dive_date_time, created_at, updated_at, "
      "diver_role) VALUES ('d1', 1000, 1000, 1000, '${custom.id}')",
    );

    await tester.pumpWidget(_buildPage(diverIdNotifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.textContaining('used by existing dives'), findsOneWidget);
    expect(find.text('Hekkensluiter'), findsOneWidget); // still listed
  });

  testWidgets('add dialog validates an empty name and can be cancelled', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPage(diverIdNotifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Submitting an empty name trips the validator instead of closing.
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a name'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Custom Dive Roles'), findsNothing);
  });

  testWidgets('add failure shows an error snackbar', (tester) async {
    // No valid diver profile: addDiveRoleByName throws.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiveRolesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Hekkensluiter');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Error adding dive role'), findsOneWidget);
  });

  testWidgets('rename failure shows an error snackbar', (tester) async {
    final repo = DiveRoleRepository();
    final created = await repo.createDiveRole(
      name: 'Hekkensluiter',
      diverId: 'diver-1',
    );

    await tester.pumpWidget(_buildPage(diverIdNotifier));
    await tester.pumpAndSettle();

    // Remove the row behind the page's back (customStatement does not
    // notify drift table watchers, so the tile stays visible).
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "DELETE FROM dive_roles WHERE id = '${created.id}'",
    );

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Sweep');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Dive role not found'), findsOneWidget);
  });

  testWidgets('delete failure after confirmation shows an error snackbar', (
    tester,
  ) async {
    final repo = DiveRoleRepository();
    final created = await repo.createDiveRole(
      name: 'Hekkensluiter',
      diverId: 'diver-1',
    );

    await tester.pumpWidget(_buildPage(diverIdNotifier));
    await tester.pumpAndSettle();

    // Flip the row to built-in behind the page's back (customStatement does
    // not notify drift watchers) so deleteDiveRole throws after confirm.
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "UPDATE dive_roles SET is_built_in = 1 WHERE id = '${created.id}'",
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Cannot delete built-in dive roles'),
      findsOneWidget,
    );
  });

  testWidgets('cancelling the delete confirmation keeps the role', (
    tester,
  ) async {
    final repo = DiveRoleRepository();
    await repo.createDiveRole(name: 'Hekkensluiter', diverId: 'diver-1');

    await tester.pumpWidget(_buildPage(diverIdNotifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete Dive Role?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Hekkensluiter'), findsOneWidget);
  });

  testWidgets('deleting an unused custom role removes it after confirm', (
    tester,
  ) async {
    final repo = DiveRoleRepository();
    await repo.createDiveRole(name: 'Hekkensluiter', diverId: 'diver-1');

    await tester.pumpWidget(_buildPage(diverIdNotifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Delete Dive Role?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Hekkensluiter'), findsNothing);
    expect(find.text('Custom Dive Roles'), findsNothing);
  });
}
