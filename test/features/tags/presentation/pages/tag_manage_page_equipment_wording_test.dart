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

/// The equipment scope on the Tags management page (#1942), against a real
/// database so the usage line and the narrowing path run end to end.
void main() {
  late MockCurrentDiverIdNotifier diverIdNotifier;

  setUp(() async {
    await setUpTestDatabase();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
    );
    for (final id in ['e1', 'e2']) {
      await db.customStatement(
        'INSERT INTO equipment (id, name, type, created_at, updated_at) '
        "VALUES (?, ?, 'regulator', 0, 0)",
        [id, 'Gear $id'],
      );
    }
    await db.customStatement(
      'INSERT INTO tags (id, diver_id, name, created_at, updated_at, '
      'applies_to_dives, applies_to_sites, applies_to_equipment) '
      "VALUES ('kit', 'diver-1', 'Travel kit', 0, 0, 0, 0, 1)",
    );
    await db.customStatement(
      'INSERT INTO equipment_tags (id, equipment_id, tag_id, created_at) '
      "VALUES ('et1', 'e1', 'kit', 0), ('et2', 'e2', 'kit', 0)",
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

  // The row, editor checkboxes and narrowing path for equipment are pinned
  // by Task 3's tag_manage_page_equipment_scope_test.dart. This file covers
  // only the wording Task 7 changes.

  testWidgets('unticking the only scope shows an error and saves nothing', (
    tester,
  ) async {
    await openEditor(tester);

    await tester.ensureVisible(useForEquipment);
    await tester.tap(useForEquipment);
    await tester.pumpAndSettle();

    const required = 'Choose at least one: dives, sites, or equipment';
    expect(find.text(required), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text(required), findsOneWidget);
    final tag = await tester.runAsync(() async {
      final db = DatabaseService.instance.database;
      return db.select(db.tags).getSingle();
    });
    expect(tag!.appliesToEquipment, isTrue);
  });

  testWidgets('deleting from the editor names the equipment items', (
    tester,
  ) async {
    await openEditor(tester);

    await tester.tap(find.byKey(const ValueKey('tag_edit_delete')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '"Travel kit" will be removed from 2 equipment items. '
        'This cannot be undone.',
      ),
      findsOneWidget,
    );
  });
}
