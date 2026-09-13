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

/// Tag scope on the Tags management page (issue #1765), against a real
/// database so the narrowing path runs end to end.
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
      "INSERT INTO dive_sites (id, name, created_at, updated_at) "
      "VALUES ('s1', 'Site', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO tags (id, diver_id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites) "
      "VALUES ('t1', 'diver-1', 'To try', 0, 0, 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO site_tags (id, site_id, tag_id, created_at) "
      "VALUES ('st1', 's1', 't1', 0)",
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

  testWidgets('a row shows its scope and site usage', (tester) async {
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    expect(find.text('Dives · Sites'), findsOneWidget);
    expect(find.text('0 dives, 1 site'), findsOneWidget);
  });

  testWidgets('turning off sites confirms, then removes the site links', (
    tester,
  ) async {
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    await tester.tap(find.text('To try'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Use for sites'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('on 1 site'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    final links = await tester.runAsync(() async {
      final db = DatabaseService.instance.database;
      return db.select(db.siteTags).get();
    });
    expect(links, isEmpty);
    expect(find.text('Dives'), findsOneWidget);
  });

  testWidgets('cancelling the confirmation keeps the tag unchanged', (
    tester,
  ) async {
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    await tester.tap(find.text('To try'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Use for sites'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
    await tester.pumpAndSettle();

    final links = await tester.runAsync(() async {
      final db = DatabaseService.instance.database;
      return db.select(db.siteTags).get();
    });
    expect(links, hasLength(1));
  });

  testWidgets('unticking both scopes shows an error and does not save', (
    tester,
  ) async {
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    await tester.tap(find.text('To try'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Use for dives'));
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Use for sites'));
    await tester.pumpAndSettle();

    expect(find.text('Choose dives, sites, or both'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    // Still open, nothing written.
    expect(find.text('Choose dives, sites, or both'), findsOneWidget);
  });
}
