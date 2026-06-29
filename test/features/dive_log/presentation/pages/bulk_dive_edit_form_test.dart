import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_collection_mode_selector.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_field_gate.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  group('DiveEditPage bulk mode', () {
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

    Future<void> pumpBulk(WidgetTester tester) async {
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(overrides).cast(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DiveEditPage(bulkDiveIds: ['d1', 'd2'], embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders gated Logistics + Notes fields', (tester) async {
      await pumpBulk(tester);

      // 4 Logistics + 9 Conditions + 6 Weather + 6 Rebreather + 1 Notes gates.
      // (dive type moved from a scalar gate to the collection lane, #414)
      expect(find.byType(BulkFieldGate), findsNWidgets(26));
      expect(find.text('Favorite'), findsOneWidget);
      // 7 collections (tags, diveTypes, equipment, buddies, weights, tanks,
      // sightings) each render a mode selector.
      expect(find.byType(BulkCollectionModeSelector), findsNWidgets(7));
    });

    testWidgets('toggling a gate enables its checkbox', (tester) async {
      await pumpBulk(tester);

      final firstCheckbox = find.byType(Checkbox).first;
      expect(tester.widget<Checkbox>(firstCheckbox).value, isFalse);
      await tester.tap(firstCheckbox);
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(firstCheckbox).value, isTrue);
    });

    testWidgets('enabling Favorite and saving applies to all dives', (
      tester,
    ) async {
      final d1 = await repository.createDive(
        createTestDiveWithBottomTime().copyWith(id: 'bulk-1'),
      );
      final d2 = await repository.createDive(
        createTestDiveWithBottomTime().copyWith(id: 'bulk-2'),
      );
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(overrides).cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DiveEditPage(bulkDiveIds: [d1.id, d2.id], embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enable the Favorite gate, then flip its toggle on.
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

      // Save, then confirm in the dialog.
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect((await repository.getDiveById(d1.id))!.isFavorite, isTrue);
      expect((await repository.getDiveById(d2.id))!.isFavorite, isTrue);
    });

    testWidgets('saving with nothing enabled shows a hint, no dialog', (
      tester,
    ) async {
      await pumpBulk(tester);

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // No confirm dialog (its Apply button is absent); a hint SnackBar shows.
      expect(find.text('Apply'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('selecting a collection mode is included in the save', (
      tester,
    ) async {
      final d1 = await repository.createDive(
        createTestDiveWithBottomTime().copyWith(id: 'coll-1'),
      );
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(overrides).cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DiveEditPage(bulkDiveIds: [d1.id], embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Turn on the first collection's "Add" mode (Tags).
      await tester.ensureVisible(find.text('Add').first);
      await tester.tap(find.text('Add').first);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // The apply path (collection op) ran and reported success.
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('OC mode with a rebreather field enabled is blocked', (
      tester,
    ) async {
      await pumpBulk(tester);

      // Enable the Dive Mode gate (mode stays OC) and a Setpoint gate.
      final modeGate = find.ancestor(
        of: find.text('Dive Mode'),
        matching: find.byType(BulkFieldGate),
      );
      await tester.ensureVisible(find.text('Dive Mode'));
      await tester.tap(
        find.descendant(of: modeGate, matching: find.byType(Checkbox)),
      );
      await tester.pumpAndSettle();
      final setpointGate = find.ancestor(
        of: find.text('Setpoint low'),
        matching: find.byType(BulkFieldGate),
      );
      await tester.ensureVisible(find.text('Setpoint low'));
      await tester.tap(
        find.descendant(of: setpointGate, matching: find.byType(Checkbox)),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Blocked: no confirm dialog, a contradiction hint instead.
      expect(find.text('Apply'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('numeric scalar fields convert and apply', (tester) async {
      final d1 = await repository.createDive(
        createTestDiveWithBottomTime().copyWith(id: 'num-1'),
      );
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(overrides).cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DiveEditPage(bulkDiveIds: [d1.id], embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enable + fill several numeric fields (exercises the conversion paths).
      for (final field in const [
        ('Humidity', '60'),
        ('Swell Height', '1.5'),
        ('Altitude', '300'),
        ('Wind Speed', '10'),
        ('Setpoint low', '0.7'),
      ]) {
        final gate = find.ancestor(
          of: find.text(field.$1),
          matching: find.byType(BulkFieldGate),
        );
        await tester.ensureVisible(find.text(field.$1));
        await tester.tap(
          find.descendant(of: gate, matching: find.byType(Checkbox)),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(of: gate, matching: find.byType(TextField)),
          field.$2,
        );
        await tester.pumpAndSettle();
      }

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect((await repository.getDiveById(d1.id))!.humidity, 60);
    });

    testWidgets('selecting every collection mode covers all op branches', (
      tester,
    ) async {
      final d1 = await repository.createDive(
        createTestDiveWithBottomTime().copyWith(id: 'all-1'),
      );
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(overrides).cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DiveEditPage(bulkDiveIds: [d1.id], embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Turn on "Add" for each of the six collections (reveals every editor
      // and exercises every _collectCollectionOps branch).
      final selectors = find.byType(BulkCollectionModeSelector);
      final count = tester.widgetList(selectors).length;
      for (var i = 0; i < count; i++) {
        final addChip = find.descendant(
          of: selectors.at(i),
          matching: find.widgetWithText(ChoiceChip, 'Add'),
        );
        await tester.ensureVisible(addChip);
        await tester.tap(addChip);
        await tester.pumpAndSettle();
      }

      // Add a tank so the tank-card editor + TanksOp payload are exercised.
      await tester.ensureVisible(find.text('Add Tank'));
      await tester.tap(find.text('Add Tank'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('notes Append mode applies an appended note', (tester) async {
      final d1 = await repository.createDive(
        createTestDiveWithBottomTime().copyWith(id: 'note-1'),
      );
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(overrides).cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DiveEditPage(bulkDiveIds: [d1.id], embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Notes is the last gate; enable it, switch to Append, and type.
      final notesGate = find.byType(BulkFieldGate).last;
      await tester.ensureVisible(notesGate);
      await tester.tap(
        find.descendant(of: notesGate, matching: find.byType(Checkbox)),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: notesGate, matching: find.text('Append')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(of: notesGate, matching: find.byType(TextField)),
        'extra log',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
