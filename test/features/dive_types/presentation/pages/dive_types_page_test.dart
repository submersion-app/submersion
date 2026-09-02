import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_type_badge.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/dive_types/presentation/pages/dive_types_page.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// End-to-end coverage for issue #643: Settings / Manage / Dive Types showed the
/// seeded English built-in names under every locale.
Future<void> _insertDiver() async {
  final db = DatabaseService.instance.database;
  await db.customStatement(
    "INSERT INTO divers (id, name, created_at, updated_at) "
    "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
  );
}

Widget _buildPage(MockCurrentDiverIdNotifier diverIdNotifier, Locale locale) {
  return ProviderScope(
    overrides: [
      currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1'),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const DiveTypesPage(),
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

  testWidgets('English locale shows the built-in names', (tester) async {
    await tester.pumpWidget(_buildPage(diverIdNotifier, const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Recreational'), findsOneWidget);
    expect(find.text('Wreck'), findsOneWidget);
  });

  testWidgets('German locale translates the built-in names', (tester) async {
    await tester.pumpWidget(_buildPage(diverIdNotifier, const Locale('de')));
    await tester.pumpAndSettle();

    expect(find.text('Sporttauchen'), findsOneWidget);
    expect(find.text('Wracktauchen'), findsOneWidget);
    // The seeded English literals must not leak through anywhere on the page.
    expect(find.text('Recreational'), findsNothing);
    expect(find.text('Wreck'), findsNothing);
    expect(find.text('Night'), findsNothing);
  });

  group('custom dive type short name', () {
    testWidgets(
      'adding a custom type with a short name shows both on its tile',
      (tester) async {
        await tester.pumpWidget(
          _buildPage(diverIdNotifier, const Locale('en')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField).at(0),
          'Search & Recovery',
        );
        await tester.enterText(find.byType(TextFormField).at(1), 'S&R');
        await tester.tap(find.widgetWithText(FilledButton, 'Add'));
        await tester.pumpAndSettle();

        expect(find.text('Search & Recovery'), findsOneWidget);
        expect(find.text('S&R'), findsOneWidget);
      },
    );

    testWidgets('a custom type added with no short name shows no badge', (
      tester,
    ) async {
      await tester.pumpWidget(_buildPage(diverIdNotifier, const Locale('en')));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Cenote');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      final tile = find.ancestor(
        of: find.text('Cenote'),
        matching: find.byType(ListTile),
      );
      expect(tile, findsOneWidget);
      // Built-in types elsewhere on the page (Recreational -> "Rec", etc.)
      // legitimately carry their own badge, so the check is scoped to this
      // tile rather than asserting no DiveTypeBadge exists anywhere.
      expect(
        find.descendant(of: tile, matching: find.byType(DiveTypeBadge)),
        findsNothing,
      );
    });
  });

  group('edit dialog', () {
    Future<void> openEditDialogFor(WidgetTester tester, String name) async {
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }

    testWidgets('tapping a built-in type opens the edit dialog', (
      tester,
    ) async {
      await tester.pumpWidget(_buildPage(diverIdNotifier, const Locale('en')));
      await tester.pumpAndSettle();

      await openEditDialogFor(tester, 'Wreck');

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(2));
      for (final element in tester.widgetList<Checkbox>(
        find.byType(Checkbox),
      )) {
        expect(element.value, isTrue);
      }
      // The name field exists but is disabled for a built-in type.
      final nameField = tester.widget<TextFormField>(
        find.byType(TextFormField).first,
      );
      expect(nameField.enabled, isFalse);
      // No short-name field for built-ins -- it's never used for them.
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets(
      'a built-in type\'s disabled name field shows the localized name, '
      'not the seeded English value',
      (tester) async {
        await tester.pumpWidget(
          _buildPage(diverIdNotifier, const Locale('de')),
        );
        await tester.pumpAndSettle();

        await openEditDialogFor(tester, 'Wracktauchen');

        final nameField = tester.widget<TextFormField>(
          find.byType(TextFormField).first,
        );
        expect(nameField.controller?.text, 'Wracktauchen');
        expect(nameField.controller?.text, isNot('Wreck'));
      },
    );

    testWidgets(
      'unchecking "Header" and saving persists and survives a rebuild',
      (tester) async {
        await tester.pumpWidget(
          _buildPage(diverIdNotifier, const Locale('en')),
        );
        await tester.pumpAndSettle();

        await openEditDialogFor(tester, 'Wreck');
        await tester.tap(find.byType(Checkbox).first);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        final updated = await DiveTypeRepository().getDiveTypeById('wreck');
        expect(updated?.showInDetailHeader, isFalse);
        expect(updated?.showInListView, isTrue);

        // Rebuilding the page (simulating navigating away and back) must not
        // silently revert the toggle.
        await tester.pumpWidget(
          _buildPage(diverIdNotifier, const Locale('en')),
        );
        await tester.pumpAndSettle();
        await openEditDialogFor(tester, 'Wreck');
        final reloadedCheckbox = tester
            .widgetList<Checkbox>(find.byType(Checkbox))
            .first;
        expect(reloadedCheckbox.value, isFalse);
      },
    );

    testWidgets('unchecking "List" and saving leaves "Header" untouched', (
      tester,
    ) async {
      await tester.pumpWidget(_buildPage(diverIdNotifier, const Locale('en')));
      await tester.pumpAndSettle();

      await openEditDialogFor(tester, 'Wreck');
      await tester.tap(find.byType(Checkbox).last);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final updated = await DiveTypeRepository().getDiveTypeById('wreck');
      expect(updated?.showInListView, isFalse);
      expect(updated?.showInDetailHeader, isTrue);
    });

    testWidgets('cancelling the dialog persists nothing', (tester) async {
      await tester.pumpWidget(_buildPage(diverIdNotifier, const Locale('en')));
      await tester.pumpAndSettle();

      await openEditDialogFor(tester, 'Wreck');
      await tester.tap(find.byType(Checkbox).first);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final updated = await DiveTypeRepository().getDiveTypeById('wreck');
      expect(updated?.showInDetailHeader, isTrue);
    });

    testWidgets('editing a custom type\'s name and short name persists', (
      tester,
    ) async {
      await tester.pumpWidget(_buildPage(diverIdNotifier, const Locale('en')));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Cenote');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      await openEditDialogFor(tester, 'Cenote');
      // The name field is enabled for a custom type, and a short-name field
      // is offered too (unlike the built-in dialog above).
      expect(find.byType(TextFormField), findsNWidgets(2));
      final nameField = tester.widget<TextFormField>(
        find.byType(TextFormField).at(0),
      );
      expect(nameField.enabled, isTrue);

      await tester.enterText(find.byType(TextFormField).at(0), 'Cave System');
      await tester.enterText(find.byType(TextFormField).at(1), 'Cave');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Cave System'), findsOneWidget);
      expect(find.text('Cenote'), findsNothing);

      final dive = await DiveTypeRepository().getAllDiveTypes(
        diverId: 'diver-1',
      );
      final saved = dive.firstWhere((t) => t.name == 'Cave System');
      expect(saved.shortName, 'Cave');
    });

    testWidgets('clearing a custom type\'s short name field removes it '
        '(regression: copyWith could not clear shortName)', (tester) async {
      await tester.pumpWidget(_buildPage(diverIdNotifier, const Locale('en')));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Cenote');
      await tester.enterText(find.byType(TextFormField).at(1), 'Cen');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      var dive = await DiveTypeRepository().getAllDiveTypes(diverId: 'diver-1');
      expect(dive.firstWhere((t) => t.name == 'Cenote').shortName, 'Cen');

      await openEditDialogFor(tester, 'Cenote');
      await tester.enterText(find.byType(TextFormField).at(1), '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      dive = await DiveTypeRepository().getAllDiveTypes(diverId: 'diver-1');
      expect(dive.firstWhere((t) => t.name == 'Cenote').shortName, isNull);
    });
  });
}
