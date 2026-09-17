import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/presentation/pages/tag_manage_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The equipment scope on the Tags management page (issue #1942), against a
/// real database so the usage line and the narrowing path run end to end.
void main() {
  late MockCurrentDiverIdNotifier diverIdNotifier;

  setUp(() async {
    await setUpTestDatabase();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
    );
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('d1', 0, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dive_sites (id, name, created_at, updated_at) '
      "VALUES ('s1', 'Site', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO equipment (id, name, type, created_at, updated_at) '
      "VALUES ('e1', 'Wing', 'bcd', 0, 0), ('e2', 'Fins', 'fins', 0, 0)",
    );
    // Travel kit: equipment only, on both items. Everywhere: every scope,
    // on one item of each.
    await db.customStatement(
      'INSERT INTO tags (id, diver_id, name, created_at, updated_at, '
      'applies_to_dives, applies_to_sites, applies_to_equipment) VALUES '
      "('kit', 'diver-1', 'Travel kit', 0, 0, 0, 0, 1), "
      "('all', 'diver-1', 'Everywhere', 0, 0, 1, 1, 1)",
    );
    await db.customStatement(
      'INSERT INTO equipment_tags (id, equipment_id, tag_id, created_at) '
      "VALUES ('et1', 'e1', 'kit', 0), ('et2', 'e2', 'kit', 0), "
      "('et3', 'e1', 'all', 0)",
    );
    await db.customStatement(
      'INSERT INTO dive_tags (id, dive_id, tag_id, created_at) '
      "VALUES ('dt1', 'd1', 'all', 0)",
    );
    await db.customStatement(
      'INSERT INTO site_tags (id, site_id, tag_id, created_at) '
      "VALUES ('st1', 's1', 'all', 0)",
    );
    diverIdNotifier = MockCurrentDiverIdNotifier();
    await diverIdNotifier.setCurrentDiver('diver-1');
  });

  tearDown(() async => tearDownTestDatabase());

  Widget page() => ProviderScope(
    overrides: [
      currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1'),
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TagManagePage(),
    ),
  );

  final useForEquipment = find.widgetWithText(
    CheckboxListTile,
    'Use for equipment',
  );

  Future<void> openEditor(WidgetTester tester) async {
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag_edit_kit')));
    await tester.pumpAndSettle();
  }

  /// The items [tagId] is linked to, read from the database.
  Future<List<String>> itemsTaggedWith(
    WidgetTester tester,
    String tagId,
  ) async {
    final rows = await tester.runAsync(() async {
      final db = DatabaseService.instance.database;
      return (db.select(
        db.equipmentTags,
      )..where((t) => t.tagId.equals(tagId))).get();
    });
    return [for (final r in rows!) r.equipmentId];
  }

  /// Turns [openEditor]'s tag from equipment-only to dives-only and saves,
  /// which asks before unlinking the two items.
  Future<void> narrowToDives(WidgetTester tester) async {
    await openEditor(tester);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Use for dives'));
    await tester.ensureVisible(useForEquipment);
    await tester.tap(useForEquipment);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('a row names its equipment scope and counts equipment items', (
    tester,
  ) async {
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    expect(find.text('Equipment'), findsOneWidget);
    // The dive count always shows, as it did before sites and equipment.
    expect(find.text('0 dives, 2 equipment items'), findsOneWidget);
    expect(find.text('Dives · Sites · Equipment'), findsOneWidget);
    expect(find.text('1 dive, 1 site, 1 equipment item'), findsOneWidget);
  });

  testWidgets('the editor offers every scope, equipment ticked', (
    tester,
  ) async {
    await openEditor(tester);

    final boxes = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList();
    expect(boxes.map((b) => (b.title! as Text).data), [
      'Use for dives',
      'Use for sites',
      'Use for equipment',
    ]);
    expect(boxes.map((b) => b.value), [false, false, true]);
  });

  testWidgets('turning off equipment confirms, then removes the links', (
    tester,
  ) async {
    await narrowToDives(tester);

    expect(
      find.text(
        'This tag is on 2 equipment items. Turning off "Use for equipment" '
        'removes it from those items.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(await itemsTaggedWith(tester, 'kit'), isEmpty);
    expect(await itemsTaggedWith(tester, 'all'), [
      'e1',
    ], reason: 'another tag on the same item keeps its link');
    expect(find.text('Dives'), findsOneWidget);
    expect(find.text('0 dives'), findsOneWidget);
  });

  testWidgets('cancelling the confirmation keeps the equipment links', (
    tester,
  ) async {
    await narrowToDives(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
    await tester.pumpAndSettle();

    expect(await itemsTaggedWith(tester, 'kit'), unorderedEquals(['e1', 'e2']));
    expect(find.text('Edit Tag'), findsOneWidget);
  });

  testWidgets('a new tag can be offered for equipment only', (tester) async {
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Rental');
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Use for dives'));
    await tester.ensureVisible(useForEquipment);
    await tester.tap(useForEquipment);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    final flags = await tester.runAsync(() async {
      final row = await DatabaseService.instance.database
          .customSelect(
            'SELECT applies_to_dives AS d, applies_to_sites AS s, '
            "applies_to_equipment AS e FROM tags WHERE name = 'Rental'",
          )
          .getSingle();
      return (row.read<int>('d'), row.read<int>('s'), row.read<int>('e'));
    });
    expect(flags, (0, 0, 1));
    expect(find.text('Rental'), findsOneWidget);
  });
}
