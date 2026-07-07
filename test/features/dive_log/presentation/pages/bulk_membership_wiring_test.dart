import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' hide Buddy, Dive;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_membership_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_set_picker_sheet.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Covers the bulk tri-state membership wiring in DiveEditPage: loading members
/// for every reference collection, the add-affordance dialogs/sheets, and the
/// delta -> add/remove op path through apply.
void main() {
  group('DiveEditPage bulk membership wiring', () {
    late DiveRepository repository;
    late BuddyRepository buddyRepo;
    late AppDatabase db;

    setUp(() async {
      db = await setUpTestDatabase();
      await db.customStatement('PRAGMA foreign_keys = OFF');
      repository = DiveRepository();
      buddyRepo = BuddyRepository();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    BuddyWithRole bwr(String id, String name) => BuddyWithRole(
      buddy: Buddy(
        id: id,
        name: name,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      role: BuddyRole.buddy,
    );

    Future<void> seedTag(String id, String name) => db
        .into(db.tags)
        .insert(
          TagsCompanion(
            id: Value(id),
            name: Value(name),
            createdAt: const Value(0),
            updatedAt: const Value(0),
          ),
        );

    Future<void> seedBuddy(String id, String name) => db
        .into(db.buddies)
        .insert(
          BuddiesCompanion(
            id: Value(id),
            name: Value(name),
            createdAt: const Value(0),
            updatedAt: const Value(0),
          ),
        );

    Future<void> seedDive(String id) => repository.createDive(
      Dive(id: id, dateTime: DateTime(2026, 1, 1), notes: ''),
    );

    Future<void> pump(WidgetTester tester, List<String> ids) async {
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
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DiveEditPage(bulkDiveIds: ids, embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder editorFor(String title) => find.ancestor(
      of: find.text(title),
      matching: find.byType(BulkMembershipEditor),
    );

    Future<void> tapAdd(WidgetTester tester, String title) async {
      final btn = find.descendant(
        of: editorFor(title),
        matching: find.widgetWithText(TextButton, 'Add'),
      );
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();
    }

    testWidgets(
      'loads and renders members for all four reference collections',
      (tester) async {
        await seedTag('t1', 'Nitrox');
        await seedBuddy('b1', 'Alice');
        await EquipmentRepository().createEquipment(
          const EquipmentItem(
            id: 'e1',
            name: 'Regulator',
            type: EquipmentType.regulator,
          ),
        );
        await seedDive('d1');
        await seedDive('d2');
        await repository.bulkAddTags(['d1'], ['t1']);
        await repository.bulkAddDiveTypes(['d1'], ['deep']);
        await buddyRepo.bulkAddBuddies(['d1'], [bwr('b1', 'Alice')]);
        await repository.bulkAddEquipment(['d1'], ['e1']);

        await pump(tester, ['d1', 'd2']);

        expect(find.byType(BulkMembershipEditor), findsNWidgets(4));
        expect(find.text('Nitrox'), findsOneWidget);
        expect(find.text('Alice'), findsOneWidget);
        expect(find.text('Regulator'), findsOneWidget);
        // Each seeded item is on 1 of the 2 selected dives.
        expect(find.text('on 1 of 2'), findsNWidgets(4));

        // Tapping a row body (not just the checkbox) also cycles the item.
        await tester.ensureVisible(find.text('Nitrox'));
        await tester.tap(find.text('Nitrox'));
        await tester.pumpAndSettle();
        expect(find.text('adding to all 2'), findsWidgets);
      },
    );

    testWidgets('toggling seeded members off applies remove ops on save', (
      tester,
    ) async {
      await seedTag('t1', 'Nitrox');
      await seedBuddy('b1', 'Alice');
      await seedDive('d1');
      await repository.bulkAddTags(['d1'], ['t1']);
      await repository.bulkAddDiveTypes(['d1'], ['deep', 'wreck']);
      await buddyRepo.bulkAddBuddies(['d1'], [bwr('b1', 'Alice')]);

      await pump(tester, ['d1']);

      // Single dive -> each is "on all 1" (checked); toggle each off.
      for (final id in ['t1', 'deep', 'b1']) {
        final f = find.byKey(ValueKey('membership-toggle-$id'));
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      final tags = await (db.select(
        db.diveTags,
      )..where((t) => t.diveId.equals('d1'))).get();
      final types = await (db.select(
        db.diveDiveTypes,
      )..where((t) => t.diveId.equals('d1'))).get();
      final buddies = await (db.select(
        db.diveBuddies,
      )..where((t) => t.diveId.equals('d1'))).get();
      expect(tags, isEmpty); // t1 removed
      expect(buddies, isEmpty); // b1 removed
      expect(
        types.map((r) => r.diveTypeId),
        isNot(contains('deep')),
      ); // removed
    });

    testWidgets('toggling "some" members on applies add ops on save', (
      tester,
    ) async {
      await seedTag('t1', 'Nitrox');
      await seedBuddy('b1', 'Alice');
      await EquipmentRepository().createEquipment(
        const EquipmentItem(
          id: 'e1',
          name: 'Regulator',
          type: EquipmentType.regulator,
        ),
      );
      await seedDive('d1');
      await seedDive('d2');
      // Each seeded on d1 only -> "on 1 of 2" (some).
      await repository.bulkAddTags(['d1'], ['t1']);
      await repository.bulkAddDiveTypes(['d1'], ['deep']);
      await buddyRepo.bulkAddBuddies(['d1'], [bwr('b1', 'Alice')]);
      await repository.bulkAddEquipment(['d1'], ['e1']);

      await pump(tester, ['d1', 'd2']);

      // "some" (dash) + one tap -> ensureOn (add to all).
      for (final id in ['t1', 'deep', 'b1', 'e1']) {
        final f = find.byKey(ValueKey('membership-toggle-$id'));
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // Each item was added to the previously-missing dive (d2).
      final d2tags = await (db.select(
        db.diveTags,
      )..where((t) => t.diveId.equals('d2'))).get();
      final d2types = await (db.select(
        db.diveDiveTypes,
      )..where((t) => t.diveId.equals('d2'))).get();
      final d2buddies = await (db.select(
        db.diveBuddies,
      )..where((t) => t.diveId.equals('d2'))).get();
      final d2equip = await (db.select(
        db.diveEquipment,
      )..where((t) => t.diveId.equals('d2'))).get();
      expect(d2tags.map((r) => r.tagId), contains('t1'));
      expect(d2types.map((r) => r.diveTypeId), contains('deep'));
      expect(d2buddies.map((r) => r.buddyId), contains('b1'));
      expect(d2equip.map((r) => r.equipmentId), contains('e1'));
    });

    testWidgets('reference-collection add dialogs open and confirm safely', (
      tester,
    ) async {
      await seedDive('d1');
      await seedDive('d2');
      await pump(tester, ['d1', 'd2']);

      // Tags: typing a name creates + selects a tag, then confirm merges it
      // as a member (covers onTagsChanged + the _addTagMembers construction).
      await tapAdd(tester, 'Tags');
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Deco',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Add'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Deco'), findsOneWidget); // added as a tag member

      // Dive Types and Buddies: open and confirm (empty is a safe no-op merge).
      for (final title in const ['Dive Types', 'Buddies']) {
        await tapAdd(tester, title);
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(FilledButton, 'Add'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      }
    });

    testWidgets('equipment add and use-set open their pickers', (tester) async {
      await EquipmentRepository().createEquipment(
        const EquipmentItem(id: 'e9', name: 'Fins', type: EquipmentType.fins),
      );
      await seedDive('d1');
      await seedDive('d2');
      await pump(tester, ['d1', 'd2']);

      // "+ Add" opens the equipment picker sheet.
      await tapAdd(tester, 'Equipment');
      expect(find.byType(EquipmentPickerSheet), findsOneWidget);
      await tester.tapAt(const Offset(20, 20)); // dismiss
      await tester.pumpAndSettle();

      // "Use Set" opens the equipment-set picker sheet.
      final useSet = find.descendant(
        of: editorFor('Equipment'),
        matching: find.widgetWithText(TextButton, 'Use Set'),
      );
      await tester.ensureVisible(useSet);
      await tester.tap(useSet);
      await tester.pumpAndSettle();
      expect(find.byType(EquipmentSetPickerSheet), findsOneWidget);
    });
  });
}
