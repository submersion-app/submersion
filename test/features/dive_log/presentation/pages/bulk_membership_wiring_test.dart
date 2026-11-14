import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    hide Buddy, Dive, EquipmentSet;
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_picker.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_chip.dart';
import 'package:submersion/shared/bulk_edit/bulk_membership_editor.dart';
import 'package:submersion/shared/widgets/forms/edit_form_scaffold.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_set_picker_sheet.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/assembly_chips.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_picker_sheet.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';
import '../../../../helpers/role_sheet.dart';
import '../../../../helpers/folded_groups.dart';
import 'package:submersion/features/weight_presets/data/repositories/weight_preset_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';

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

    final instructorRole = DiveRole(
      id: DiveRole.instructorId,
      name: 'Instructor',
      isBuiltIn: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    BuddyWithRole bwr(String id, String name, [DiveRole? role]) =>
        BuddyWithRole(
          buddy: Buddy(
            id: id,
            name: name,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
          roles: [role ?? DiveRole.builtInBuddy()],
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

    /// Hosted in the shell shape rather than straight under `MaterialApp.home`.
    /// Every add-affordance below is a dialog, a sheet, or a sheet opened from
    /// a dialog, and `showDialog` defaults to the root navigator while
    /// `showModalBottomSheet` defaults to the nearest one. Under `home` those
    /// are the same object, so a sheet pushed onto the wrong navigator still
    /// lands on top and the test sees nothing wrong; under the app's real
    /// `ShellRoute` it opens *behind* the dialog instead (#1366).
    Future<void> pump(
      WidgetTester tester,
      List<String> ids, {
      List<EquipmentSet> sets = const [],
      List<Override> extraOverrides = const [],
    }) async {
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        testAppInShell(
          // Every assertion below matches an English label, so pin the
          // locale instead of inheriting the ambient platform one.
          locale: const Locale('en'),
          overrides: [
            ...overrides,
            diveRepositoryProvider.overrideWithValue(repository),
            diveListNotifierProvider.overrideWith(
              (ref) => DiveListNotifier(repository, ref),
            ),
            customTankPresetsProvider.overrideWith((ref) async => []),
            if (sets.isNotEmpty) ...[
              equipmentSetsProvider.overrideWith((ref) async => sets),
              equipmentSetWithItemsProvider.overrideWith(
                (ref, id) async => sets.firstWhere((s) => s.id == id),
              ),
            ],
            ...extraOverrides,
          ],
          child: DiveEditPage(bulkDiveIds: ids, embedded: true),
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
      // Equipment pickers open with their groups folded (#3364).
      await openFoldedGroups(tester);
    }

    testWidgets(
      'loads and renders members for all four reference collections',
      (tester) async {
        await seedTag('t1', 'Nitrox');
        await seedBuddy('b1', 'Alice');
        await EquipmentRepository().createEquipment(
          const EquipmentItem(
            id: 'e1',
            name: 'Apeks XTX50',
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

        // Tags, dive types, training courses (#2515), equipment, buddies.
        expect(find.byType(BulkMembershipEditor), findsNWidgets(5));
        expect(find.text('Nitrox'), findsOneWidget);
        expect(find.text('Alice'), findsOneWidget);
        expect(find.text('Apeks XTX50'), findsOneWidget);
        // Each seeded item is on 1 of the 2 selected dives.
        expect(find.text('on 1 of 2'), findsNWidgets(4));

        // Tapping a row body (not just the checkbox) also cycles the item.
        await tester.ensureVisible(find.text('Nitrox'));
        await tester.tap(find.text('Nitrox'));
        await tester.pumpAndSettle();
        expect(find.text('adding to all 2'), findsWidgets);
      },
    );

    // A part of an assembly with a long name used to render its "Part of"
    // chip in the row's trailing slot. ListTile sizes trailing before the
    // title, so the chip took nearly the whole width and the name and status
    // line wrapped one character per line (#2276).
    testWidgets('a long "Part of" chip does not squeeze the gear row', (
      tester,
    ) async {
      const rig = EquipmentItem(
        id: 'rig',
        name:
            'Camera Assembly - DJI Osmo Action 5 Pro / Wide & Macro Lens / '
            'Red Tray / Lens Mounts',
        type: EquipmentType.camera,
      );
      const lens = EquipmentItem(
        id: 'lens',
        name: 'Lens',
        type: EquipmentType.camera,
      );
      const fins = EquipmentItem(
        id: 'fins',
        name: 'Fins',
        type: EquipmentType.fins,
      );
      for (final item in [rig, lens, fins]) {
        await EquipmentRepository().createEquipment(item);
      }
      await seedDive('d1');
      await seedDive('d2');
      await repository.bulkAddEquipment(['d1'], ['lens', 'fins']);

      final t0 = DateTime(2026, 1, 1);
      await pump(
        tester,
        ['d1', 'd2'],
        extraOverrides: [
          equipmentComponentsIndexProvider.overrideWith(
            (ref) async => ComponentsIndex.fromRows([
              EquipmentComponent(
                id: 'c1',
                parentEquipmentId: 'rig',
                componentEquipmentId: 'lens',
                createdAt: t0,
                updatedAt: t0,
              ),
            ]),
          ),
          activeEquipmentProvider.overrideWith(
            (ref) async => [rig, lens, fins],
          ),
        ],
      );

      final chip = find.text('Part of ${rig.name}');
      expect(chip, findsOneWidget);

      // Both rows read "on 1 of 2"; the one carrying the chip must lay it
      // out on a single line just like the row without one.
      final statuses = find.descendant(
        of: editorFor('Equipment'),
        matching: find.text('on 1 of 2'),
      );
      expect(statuses, findsNWidgets(2));
      expect(
        tester.getSize(statuses.at(0)).height,
        tester.getSize(statuses.at(1)).height,
      );

      // The chip sits under the item's name, not beside it.
      expect(
        tester.getTopLeft(chip).dy,
        greaterThan(tester.getBottomLeft(find.text('Lens')).dy),
      );

      // Plain gear builds no chip slot at all, so its subtitle is the status
      // line alone, as before the chips moved there.
      expect(
        find.descendant(
          of: editorFor('Equipment'),
          matching: find.byType(AssemblyChips),
        ),
        findsOneWidget,
      );
      final finsTile = find.ancestor(
        of: find.text('Fins'),
        matching: find.byType(ListTile),
      );
      expect(tester.widget<ListTile>(finsTile).subtitle, isA<Text>());
    });

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

    testWidgets('bulk-adding a buddy keeps the role picked in the picker', (
      tester,
    ) async {
      await seedBuddy('b1', 'Alice');
      await seedDive('d1');
      await seedDive('d2');
      await pump(tester, ['d1', 'd2']);

      // Buddies "+ Add" -> dialog hosting the BuddyPicker.
      await tapAdd(tester, 'Buddies');
      // The picker's own "+ Add" -> buddy selection sheet.
      await tester.tap(
        find.descendant(
          of: find.byType(BuddyPicker),
          matching: find.widgetWithText(TextButton, 'Add'),
        ),
      );
      await tester.pumpAndSettle();

      // Pick Alice -> role selector -> Instructor.
      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();
      expect(find.text('Select Role for Alice'), findsOneWidget);
      await pickOnlyRole(tester, 'Instructor');

      // Done (close the sheet) then Add (merge into the membership editor).
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Add'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      final rows = await db.select(db.diveBuddies).get();
      expect(rows.map((r) => r.diveId), containsAll(['d1', 'd2']));
      expect(rows.map((r) => r.role), everyElement(DiveRole.instructorId));
    });

    testWidgets('adding an existing buddy to the rest keeps their role', (
      tester,
    ) async {
      await seedBuddy('b1', 'Alice');
      await seedDive('d1');
      await seedDive('d2');
      // Alice is an Instructor on d1 only -> the row reads "on 1 of 2".
      await buddyRepo.bulkAddBuddies(
        ['d1'],
        [bwr('b1', 'Alice', instructorRole)],
      );

      await pump(tester, ['d1', 'd2']);

      final toggle = find.byKey(const ValueKey('membership-toggle-b1'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      final rows = await db.select(db.diveBuddies).get();
      expect(rows.map((r) => r.diveId), containsAll(['d1', 'd2']));
      // Neither the pre-existing link nor the new one may fall back to "buddy".
      expect(rows.map((r) => r.role), everyElement(DiveRole.instructorId));
    });

    testWidgets('re-picking a role for an already-listed buddy applies it', (
      tester,
    ) async {
      await seedBuddy('b1', 'Alice');
      await seedDive('d1');
      await seedDive('d2');
      // Alice is already on both dives as a plain Buddy.
      await buddyRepo.bulkAddBuddies(['d1', 'd2'], [bwr('b1', 'Alice')]);

      await pump(tester, ['d1', 'd2']);

      await tapAdd(tester, 'Buddies');
      await tester.tap(
        find.descendant(
          of: find.byType(BuddyPicker),
          matching: find.widgetWithText(TextButton, 'Add'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(DraggableScrollableSheet),
          matching: find.text('Alice'),
        ),
      );
      await tester.pumpAndSettle();
      await pickOnlyRole(tester, 'Instructor');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Add'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      final rows = await db.select(db.diveBuddies).get();
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.role), everyElement(DiveRole.instructorId));
    });

    testWidgets('equipment add and use-set open their pickers', (tester) async {
      await EquipmentRepository().createEquipment(
        const EquipmentItem(id: 'e9', name: 'Fins', type: EquipmentType.fins),
      );
      await seedDive('d1');
      await seedDive('d2');
      await pump(tester, ['d1', 'd2']);

      // "+ Add" opens the equipment picker sheet, which leaves out the
      // components of an assembly it offers (#2514).
      await tapAdd(tester, 'Equipment');
      expect(find.byType(EquipmentPickerSheet), findsOneWidget);
      expect(
        tester
            .widget<EquipmentPickerSheet>(find.byType(EquipmentPickerSheet))
            .hideAssemblyParts,
        isTrue,
      );
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

    // Issue #2175: the picker is multi-select, so several items go on in one
    // pass, and Cancel leaves the list as it was.
    testWidgets('equipment add takes several items in one pass', (
      tester,
    ) async {
      await EquipmentRepository().createEquipment(
        const EquipmentItem(
          id: 'e8',
          name: 'Frameless',
          type: EquipmentType.mask,
        ),
      );
      await EquipmentRepository().createEquipment(
        const EquipmentItem(id: 'e9', name: 'Jets', type: EquipmentType.fins),
      );
      await seedDive('d1');
      await seedDive('d2');
      await pump(tester, ['d1', 'd2']);

      Finder inEditor(String name) => find.descendant(
        of: editorFor('Equipment'),
        matching: find.text(name),
      );

      await tapAdd(tester, 'Equipment');
      await tester.tap(find.text('Frameless'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(EquipmentPickerSheet), findsNothing);
      expect(inEditor('Frameless'), findsNothing);

      await tapAdd(tester, 'Equipment');
      await tester.tap(find.text('Frameless'));
      await tester.tap(find.text('Jets'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add 2'));
      await tester.pumpAndSettle();

      expect(find.byType(EquipmentPickerSheet), findsNothing);
      expect(inEditor('Frameless'), findsOneWidget);
      expect(inEditor('Jets'), findsOneWidget);
    });

    // Issue #1754 (found in #1720): clearing the old gear and then applying a
    // set must keep every set item, including the ones already on the dives.
    testWidgets('use-set keeps set items the diver had unchecked', (
      tester,
    ) async {
      const wing = EquipmentItem(
        id: 'e1',
        name: 'Wing',
        type: EquipmentType.bcd,
      );
      const dsmb = EquipmentItem(
        id: 'e2',
        name: 'DSMB',
        type: EquipmentType.smb,
      );
      const camera = EquipmentItem(
        id: 'e3',
        name: 'Camera',
        type: EquipmentType.camera,
      );
      const knife = EquipmentItem(
        id: 'e4',
        name: 'Knife',
        type: EquipmentType.knife,
      );
      for (final item in [wing, dsmb, camera, knife]) {
        await EquipmentRepository().createEquipment(item);
      }
      await seedDive('d1');
      await seedDive('d2');
      await repository.bulkAddEquipment(['d1', 'd2'], ['e1', 'e2', 'e3']);
      final tripKit = EquipmentSet(
        id: 's1',
        name: 'Trip kit',
        equipmentIds: const ['e1', 'e2', 'e4'],
        items: const [wing, dsmb, knife],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      await pump(tester, ['d1', 'd2'], sets: [tripKit]);

      // Clear the old gear, then apply the set.
      for (final id in ['e1', 'e2', 'e3']) {
        final f = find.byKey(ValueKey('membership-toggle-$id'));
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }
      final useSet = find.descendant(
        of: editorFor('Equipment'),
        matching: find.widgetWithText(TextButton, 'Use Set'),
      );
      await tester.ensureVisible(useSet);
      await tester.tap(useSet);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trip kit'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      for (final diveId in ['d1', 'd2']) {
        final rows = await (db.select(
          db.diveEquipment,
        )..where((t) => t.diveId.equals(diveId))).get();
        expect(rows.map((r) => r.equipmentId).toSet(), {
          'e1',
          'e2',
          'e4',
        }, reason: 'dive $diveId keeps the set and drops only the camera');
      }
    });

    // Issue #4284: gear "Use Set" switches on carries the set, as on one dive.
    testWidgets('use-set tags the gear it adds with the set', (tester) async {
      const wing = EquipmentItem(
        id: 'e1',
        name: 'Wing',
        type: EquipmentType.bcd,
      );
      const dsmb = EquipmentItem(
        id: 'e2',
        name: 'DSMB',
        type: EquipmentType.smb,
      );
      for (final item in [wing, dsmb]) {
        await EquipmentRepository().createEquipment(item);
      }
      await seedDive('d1');
      await seedDive('d2');
      final tripKit = EquipmentSet(
        id: 's1',
        name: 'Trip kit',
        equipmentIds: const ['e1', 'e2'],
        items: const [wing, dsmb],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      await pump(tester, ['d1', 'd2'], sets: [tripKit]);
      final useSet = find.descendant(
        of: editorFor('Equipment'),
        matching: find.widgetWithText(TextButton, 'Use Set'),
      );
      await tester.ensureVisible(useSet);
      await tester.tap(useSet);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trip kit'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      final rows = await db.select(db.diveEquipment).get();
      expect(rows, hasLength(4));
      expect(rows.map((r) => r.viaSetId).toSet(), {'s1'});
    });

    // Issue #4525: a set that carries only weights has no gear to list, so
    // the set itself is staged and its weights go on dives that have none.
    testWidgets('use-set stages a set with only weights and applies them', (
      tester,
    ) async {
      await seedDive('d1');
      await seedDive('d2');
      final preset = await WeightPresetRepository().createPreset(
        diverId: 'diver-1',
        displayName: 'Belt',
        entries: const [
          (weightType: WeightType.belt, amountKg: 3.63, notes: '', label: ''),
        ],
      );
      final created = await EquipmentSetRepository().createSet(
        EquipmentSet(
          id: 'lead',
          name: 'Lead only',
          weightPresetIds: [preset.id],
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );

      await pump(
        tester,
        ['d1', 'd2'],
        sets: [created.copyWith(items: const [])],
      );
      final useSet = find.descendant(
        of: editorFor('Equipment'),
        matching: find.widgetWithText(TextButton, 'Use Set'),
      );
      await tester.ensureVisible(useSet);
      await tester.tap(useSet);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lead only'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bulk-used-set-lead')), findsOneWidget);

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      final weights = await db.select(db.diveWeights).get();
      expect(weights.map((w) => w.diveId).toSet(), {'d1', 'd2'});
      expect(await db.select(db.diveEquipment).get(), isEmpty);
    });

    // Issue #2046: a set member another profile owns and has not shared
    // stays in the set but is not applied, as when the set is used on one
    // dive.
    testWidgets('use-set leaves off a member not shared with the diver', (
      tester,
    ) async {
      const wing = EquipmentItem(
        id: 'e1',
        name: 'Wing',
        type: EquipmentType.bcd,
        diverId: 'me',
      );
      const camera = EquipmentItem(
        id: 'e2',
        name: 'Borrowed camera',
        type: EquipmentType.camera,
        diverId: 'other',
      );
      for (final item in [wing, camera]) {
        await EquipmentRepository().createEquipment(item);
      }
      await seedDive('d1');
      await seedDive('d2');
      final tripKit = EquipmentSet(
        id: 's1',
        name: 'Trip kit',
        equipmentIds: const ['e1', 'e2'],
        items: const [wing, camera],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      await pump(
        tester,
        ['d1', 'd2'],
        sets: [tripKit],
        extraOverrides: [
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
        ],
      );
      final useSet = find.descendant(
        of: editorFor('Equipment'),
        matching: find.widgetWithText(TextButton, 'Use Set'),
      );
      await tester.ensureVisible(useSet);
      await tester.tap(useSet);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trip kit'));
      await tester.pumpAndSettle();
      expect(find.text('Borrowed camera'), findsNothing);
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      for (final diveId in ['d1', 'd2']) {
        final rows = await (db.select(
          db.diveEquipment,
        )..where((t) => t.diveId.equals(diveId))).get();
        expect(rows.map((r) => r.equipmentId), ['e1'], reason: diveId);
      }
    });

    // A set whose only gear cannot go on these dives, and which carries no
    // weights or tanks either, has nothing to stage.
    testWidgets('use-set stages nothing for a set that would apply '
        'nothing', (tester) async {
      const camera = EquipmentItem(
        id: 'e2',
        name: 'Borrowed camera',
        type: EquipmentType.camera,
        diverId: 'other',
      );
      await EquipmentRepository().createEquipment(camera);
      await seedDive('d1');
      final borrowed = EquipmentSet(
        id: 's9',
        name: 'Borrowed kit',
        equipmentIds: const ['e2'],
        items: const [camera],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      await pump(
        tester,
        ['d1'],
        sets: [borrowed],
        extraOverrides: [
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
        ],
      );
      final useSet = find.descendant(
        of: editorFor('Equipment'),
        matching: find.widgetWithText(TextButton, 'Use Set'),
      );
      await tester.ensureVisible(useSet);
      await tester.tap(useSet);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Borrowed kit'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bulk-used-set-s9')), findsNothing);
    });

    // Issue #4284: a set item the diver unchecks after "Use Set" stays off,
    // though on no dive unchecking it makes no remove of its own.
    testWidgets('use-set leaves off a set item the diver unchecked', (
      tester,
    ) async {
      const wing = EquipmentItem(
        id: 'e1',
        name: 'Wing',
        type: EquipmentType.bcd,
      );
      const dsmb = EquipmentItem(
        id: 'e2',
        name: 'DSMB',
        type: EquipmentType.smb,
      );
      for (final item in [wing, dsmb]) {
        await EquipmentRepository().createEquipment(item);
      }
      await seedDive('d1');
      await seedDive('d2');
      final tripKit = EquipmentSet(
        id: 's1',
        name: 'Trip kit',
        equipmentIds: const ['e1', 'e2'],
        items: const [wing, dsmb],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      await pump(tester, ['d1', 'd2'], sets: [tripKit]);
      final useSet = find.descendant(
        of: editorFor('Equipment'),
        matching: find.widgetWithText(TextButton, 'Use Set'),
      );
      await tester.ensureVisible(useSet);
      await tester.tap(useSet);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trip kit'));
      await tester.pumpAndSettle();
      final dsmbToggle = find.byKey(const ValueKey('membership-toggle-e2'));
      await tester.ensureVisible(dsmbToggle);
      await tester.tap(dsmbToggle);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      for (final diveId in ['d1', 'd2']) {
        final rows = await (db.select(
          db.diveEquipment,
        )..where((t) => t.diveId.equals(diveId))).get();
        expect(rows.map((r) => r.equipmentId), ['e1'], reason: diveId);
      }
    });

    // Issue #4284: a set staged for removal is named in the confirmation and
    // takes off only the gear it brought.
    testWidgets('remove-set stages a set and takes off what it brought', (
      tester,
    ) async {
      const wing = EquipmentItem(
        id: 'e1',
        name: 'Wing',
        type: EquipmentType.bcd,
      );
      const dsmb = EquipmentItem(
        id: 'e2',
        name: 'DSMB',
        type: EquipmentType.smb,
      );
      const camera = EquipmentItem(
        id: 'e3',
        name: 'Camera',
        type: EquipmentType.camera,
      );
      for (final item in [wing, dsmb, camera]) {
        await EquipmentRepository().createEquipment(item);
      }
      await db.customStatement(
        'INSERT INTO equipment_sets (id, name, created_at, updated_at) '
        "VALUES ('s1', 'Trip kit', 0, 0)",
      );
      await db.customStatement(
        'INSERT INTO equipment_set_items (set_id, equipment_id) '
        "VALUES ('s1', 'e1'), ('s1', 'e2')",
      );
      await seedDive('d1');
      await seedDive('d2');
      await repository.bulkAddEquipmentSets(['d1', 'd2'], ['s1']);
      await repository.bulkAddEquipment(['d1', 'd2'], ['e3']);
      final tripKit = EquipmentSet(
        id: 's1',
        name: 'Trip kit',
        equipmentIds: const ['e1', 'e2'],
        items: const [wing, dsmb],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      await pump(tester, ['d1', 'd2'], sets: [tripKit]);
      Future<void> stage() async {
        final removeSet = find.byKey(const ValueKey('bulk-remove-set'));
        await tester.ensureVisible(removeSet);
        await tester.tap(removeSet);
        await tester.pumpAndSettle();
        expect(find.text('Remove Equipment Set'), findsOneWidget);
        await tester.tap(find.text('Trip kit'));
        await tester.pumpAndSettle();
      }

      final chip = find.byKey(const ValueKey('bulk-staged-set-s1'));
      bool guarded() => tester
          .widget<EditFormScaffold>(find.byType(EditFormScaffold))
          .hasUnsavedChanges;
      expect(guarded(), isFalse);
      await stage();
      expect(chip, findsOneWidget);
      // A staged removal arms the unsaved-changes guard.
      expect(guarded(), isTrue);
      // Unstaged again, then staged for good.
      await tester.ensureVisible(chip);
      await tester.tap(
        find.descendant(of: chip, matching: find.byIcon(Icons.close)),
      );
      await tester.pumpAndSettle();
      expect(chip, findsNothing);
      await stage();

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      Finder inDialog(String text) =>
          find.descendant(of: dialog, matching: find.text(text));
      expect(inDialog('Equipment sets'), findsOneWidget);
      expect(inDialog('Removing from all 2 dives'), findsOneWidget);
      expect(inDialog('Trip kit'), findsOneWidget);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      for (final diveId in ['d1', 'd2']) {
        final rows = await (db.select(
          db.diveEquipment,
        )..where((t) => t.diveId.equals(diveId))).get();
        expect(rows.map((r) => r.equipmentId), ['e3'], reason: diveId);
      }
    });

    // Issue #4284: "Remove Set A" plus "Use Set B" in one edit keeps the gear
    // the two share, now tagged with B, though it was on every dive already.
    testWidgets('swapping one set for another keeps the gear they share', (
      tester,
    ) async {
      const wing = EquipmentItem(
        id: 'e1',
        name: 'Wing',
        type: EquipmentType.bcd,
      );
      const dsmb = EquipmentItem(
        id: 'e2',
        name: 'DSMB',
        type: EquipmentType.smb,
      );
      const lamp = EquipmentItem(
        id: 'e3',
        name: 'Lamp',
        type: EquipmentType.light,
      );
      for (final item in [wing, dsmb, lamp]) {
        await EquipmentRepository().createEquipment(item);
      }
      await db.customStatement(
        'INSERT INTO equipment_sets (id, name, created_at, updated_at) '
        "VALUES ('sa', 'Set A', 0, 0), ('sb', 'Set B', 0, 0)",
      );
      await db.customStatement(
        'INSERT INTO equipment_set_items (set_id, equipment_id) '
        "VALUES ('sa', 'e1'), ('sa', 'e2'), ('sb', 'e2'), ('sb', 'e3')",
      );
      await seedDive('d1');
      await seedDive('d2');
      await repository.bulkAddEquipmentSets(['d1', 'd2'], ['sa']);
      EquipmentSet set(String id, String name, List<EquipmentItem> items) =>
          EquipmentSet(
            id: id,
            name: name,
            equipmentIds: [for (final i in items) i.id],
            items: items,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          );

      await pump(
        tester,
        ['d1', 'd2'],
        sets: [
          set('sa', 'Set A', const [wing, dsmb]),
          set('sb', 'Set B', const [dsmb, lamp]),
        ],
      );
      final removeSet = find.byKey(const ValueKey('bulk-remove-set'));
      await tester.ensureVisible(removeSet);
      await tester.tap(removeSet);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set A'));
      await tester.pumpAndSettle();
      final useSet = find.descendant(
        of: editorFor('Equipment'),
        matching: find.widgetWithText(TextButton, 'Use Set'),
      );
      await tester.ensureVisible(useSet);
      await tester.tap(useSet);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set B'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      for (final diveId in ['d1', 'd2']) {
        final rows = await (db.select(
          db.diveEquipment,
        )..where((t) => t.diveId.equals(diveId))).get();
        expect(
          {for (final r in rows) r.equipmentId: r.viaSetId},
          {'e2': 'sb', 'e3': 'sb'},
          reason: diveId,
        );
      }
    });

    // Issue #1942 moved the editor to lib/shared; the page still supplies
    // the dive wording, so a row and an empty collection read as before.
    testWidgets('the rows and the empty state keep their dive wording', (
      tester,
    ) async {
      await seedTag('t1', 'Nitrox');
      await seedDive('d1');
      await repository.bulkAddTags(['d1'], ['t1']);

      await pump(tester, ['d1']);

      final tags = editorFor('Tags');
      expect(
        find.descendant(of: tags, matching: find.text('on all 1')),
        findsOneWidget,
      );
      final toggle = find.byKey(const ValueKey('membership-toggle-t1'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: tags, matching: find.text('removing from all')),
        findsOneWidget,
      );
      // No buddy is on the dive.
      expect(
        find.descendant(
          of: editorFor('Buddies'),
          matching: find.text('No items on the selected dives yet'),
        ),
        findsOneWidget,
      );
    });

    // Issue #1754: the confirmation must say what the save is about to change,
    // so a stray removal is caught before it lands on every dive.
    testWidgets('the confirmation names what the save adds and removes', (
      tester,
    ) async {
      await seedTag('t1', 'Nitrox');
      await EquipmentRepository().createEquipment(
        const EquipmentItem(
          id: 'e3',
          name: 'Camera',
          type: EquipmentType.camera,
        ),
      );
      await EquipmentRepository().createEquipment(
        const EquipmentItem(id: 'e5', name: 'Fins', type: EquipmentType.fins),
      );
      await seedDive('d1');
      await seedDive('d2');
      await repository.bulkAddTags(['d1', 'd2'], ['t1']);
      await repository.bulkAddEquipment(['d1', 'd2'], ['e3']);
      await repository.bulkAddEquipment(['d1'], ['e5']);

      await pump(tester, ['d1', 'd2']);

      // Remove the tag and the camera from both dives; put the fins on both.
      for (final id in ['t1', 'e3', 'e5']) {
        final f = find.byKey(ValueKey('membership-toggle-$id'));
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      Finder inDialog(String text) =>
          find.descendant(of: dialog, matching: find.text(text));
      expect(inDialog('Adding to all 2 dives'), findsOneWidget);
      expect(inDialog('Fins'), findsOneWidget);
      expect(inDialog('Removing from all 2 dives'), findsNWidgets(2));
      expect(inDialog('Nitrox'), findsOneWidget);
      expect(inDialog('Camera'), findsOneWidget);
    });

    testWidgets('the bulk tag dialog can browse previously used tags', (
      tester,
    ) async {
      // Seeded but unattached, so it is absent from the member list and
      // available in the picker.
      await seedTag('t9', 'Nitrox');
      await seedDive('d1');
      await seedDive('d2');
      await pump(tester, ['d1', 'd2']);

      await tapAdd(tester, 'Tags');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Browse'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TagPickerSheet), findsOneWidget);
      await tester.tap(find.text('Nitrox'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add 1 tag'));
      await tester.pumpAndSettle();

      // Back in the dialog with the browsed tag staged as a chip.
      expect(find.byType(TagPickerSheet), findsNothing);
      expect(find.widgetWithText(TagChip, 'Nitrox'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Add'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nitrox'), findsOneWidget); // added as a tag member
    });
  });
}
