import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';
import 'package:submersion/features/equipment/presentation/editing/equipment_set_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_detail_page.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/test_database.dart';
import 'equipment_set_detail_page_unlock_harness.dart';

/// A new set and a set clone open on the set page, already unlocked (issue
/// #4527, phase 3, plan 11).
void main() {
  final l = AppLocalizationsEn();

  setUp(() async => seedSetPage());
  tearDown(tearDownTestDatabase);

  Finder nameField() => find.byKey(const ValueKey('set-edit-name'));

  EditSession<EquipmentSet> sessionOf(WidgetTester tester) {
    final element = tester.element(
      find.byType(RecordCardFrame<EquipmentSet>).first,
    );
    return RecordEditScope.maybeOf<EquipmentSet>(element)!.session!;
  }

  /// Runs [sql] on the test database, outside the test's fake clock.
  Future<void> sql(WidgetTester tester, String sql) => tester.runAsync(
    () => DatabaseService.instance.database.customStatement(sql),
  );

  Future<List<EquipmentSet>> setsOf(
    WidgetTester tester,
    String diverId,
  ) async => (await tester.runAsync(
    () => EquipmentSetRepository().getAllSets(diverId: diverId),
  ))!;

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_save));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('a new set opens unlocked, and Save creates it and pops its id', (
    tester,
  ) async {
    final harness = await pumpNewSetPage(tester);

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text(l.equipment_setEdit_appBar_newTitle), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);

    await tester.enterText(nameField(), 'Travel kit');
    await tester.pumpAndSettle();
    await save(tester);

    final id = harness.popped! as String;
    final created = await storedSet(tester, id);
    expect(created.name, 'Travel kit');
    expect(created.showFigure, isTrue);
    expect(created.diverId, 'd1');
  });

  testWidgets('a set opened before the profile was read is the profile '
      "active at Save's", (tester) async {
    final harness = await pumpNewSetPage(tester, diverAtOpen: null);
    await tester.enterText(nameField(), 'Travel kit');
    await tester.pumpAndSettle();
    ProviderScope.containerOf(
      tester.element(find.byType(EquipmentSetDetailPage)),
    ).read(newSetPageDiverProvider.notifier).state = 'd1';
    await tester.pumpAndSettle();

    await save(tester);

    final created = await storedSet(tester, harness.popped! as String);
    expect(created.diverId, 'd1');
  });

  testWidgets('an untouched new set leaves without asking', (tester) async {
    final harness = await pumpNewSetPage(tester);

    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();

    expect(find.text(l.forms_discard_title), findsNothing);
    expect(harness.poppedAtAll, isTrue);
    expect(harness.popped, isNull);
  });

  testWidgets('a clone opens named as a copy, and saving leaves the source '
      'as it was', (tester) async {
    final harness = await pumpNewSetPage(tester, cloneFromId: 's1');

    expect(find.text(l.equipment_setEdit_appBar_cloneTitle), findsOneWidget);
    expect(find.text(l.equipment_clone_nameCopy('Cold water')), findsWidgets);
    await save(tester);

    final clone = await storedSet(tester, harness.popped! as String);
    expect(clone.name, l.equipment_clone_nameCopy('Cold water'));
    expect(clone.equipmentIds.toSet(), {'e1', 'e2'});
    // Not the default, no geofence: a clone does not compete.
    expect(clone.isDefault, isFalse);
    expect(clone.geofences, isEmpty);
    final source = await storedSet(tester);
    expect(source.name, 'Cold water');
    expect(source.geofences.single.id, 'g1');
  });

  testWidgets('a clone of a set that is gone opens as not found', (
    tester,
  ) async {
    await pumpNewSetPage(tester, cloneFromId: 'gone');

    expect(find.text(l.equipment_setDetail_notFoundMessage), findsOneWidget);
    expect(find.byType(RecordEditBar), findsNothing);
  });
  testWidgets('a profile switch before Save drops the clone', (tester) async {
    final harness = await pumpNewSetPage(tester, cloneFromId: 's1');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RecordEditBar)),
    );

    container.read(newSetPageDiverProvider.notifier).state = 'other';
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    expect(harness.poppedAtAll, isTrue);
    expect(harness.popped, isNull);
  });
  testWidgets('Save on an untouched new set asks for a name and creates '
      'nothing', (tester) async {
    final harness = await pumpNewSetPage(tester);

    await save(tester);

    expect(find.text(l.equipment_setEdit_nameValidation), findsOneWidget);
    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(harness.poppedAtAll, isFalse);
    expect(await setsOf(tester, 'd1'), hasLength(2));
  });

  testWidgets('a new default set with a geofence saves both', (tester) async {
    final harness = await pumpNewSetPage(tester);
    await tester.enterText(nameField(), 'Travel kit');
    await tester.pumpAndSettle();
    final session = sessionOf(tester);
    session
      ..set(setDefaultField, true)
      ..set(
        setGeofencesField,
        geofencesEdited(session, [
          EquipmentSetGeofence(
            id: 'ng',
            setId: session.stored.id,
            label: 'Pier',
            latitude: 1,
            longitude: 2,
            radiusMeters: 150,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ]),
      );
    await tester.pumpAndSettle();

    await save(tester);

    final created = await storedSet(tester, harness.popped! as String);
    expect(created.isDefault, isTrue);
    expect(created.geofences.single.label, 'Pier');
    expect((await storedSet(tester, 's2')).isDefault, isFalse);
  });

  testWidgets('a new set saved with the figure off stores it off', (
    tester,
  ) async {
    final harness = await pumpNewSetPage(tester);
    await tester.enterText(nameField(), 'Travel kit');
    await tester.pumpAndSettle();
    sessionOf(tester).set(setShowFigureField, false);
    await tester.pumpAndSettle();

    await save(tester);

    expect(
      (await storedSet(tester, harness.popped! as String)).showFigure,
      isFalse,
    );
  });

  testWidgets('a clone copies the description, figure and only the gear the '
      'diver can see, not the default or auto-apply, and the source keeps '
      'them', (tester) async {
    await sql(
      tester,
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('d2', 'd2', 0, 0)",
    );
    await sql(
      tester,
      "INSERT INTO equipment (id, name, type, diver_id, "
      "created_at, updated_at) VALUES ('e9', 'Their light', 'light', 'd2', "
      "0, 0)",
    );
    await tester.runAsync(() async {
      final sets = EquipmentSetRepository();
      await sets.addItemToSet('s1', 'e9');
      await sets.setAsDefault('s1');
    });
    await sql(
      tester,
      "UPDATE equipment_sets SET description = 'Drysuit kit', "
      "auto_apply_on_computer_import = 1 WHERE id = 's1'",
    );

    final harness = await pumpNewSetPage(tester, cloneFromId: 's1');
    await save(tester);

    final clone = await storedSet(tester, harness.popped! as String);
    expect(clone.description, 'Drysuit kit');
    expect(clone.showFigure, isFalse);
    expect(clone.equipmentIds.toSet(), {'e1', 'e2'});
    expect(clone.isDefault, isFalse);
    expect(clone.autoApplyOnComputerImport, isFalse);
    final source = await storedSet(tester);
    expect(source.isDefault, isTrue);
    expect(source.autoApplyOnComputerImport, isTrue);
  });

  testWidgets('Cancel on an untouched clone asks first, since nothing is '
      'saved yet', (tester) async {
    final harness = await pumpNewSetPage(tester, cloneFromId: 's1');

    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();
    expect(find.text(l.forms_discard_title), findsOneWidget);
    await tester.tap(find.text(l.forms_discard_keepEditing));
    await tester.pumpAndSettle();
    expect(find.byType(RecordEditBar), findsOneWidget);

    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.forms_discard_discard));
    await tester.pumpAndSettle();

    expect(harness.poppedAtAll, isTrue);
    expect(harness.popped, isNull);
    expect(await setsOf(tester, 'd1'), hasLength(2));
  });

  testWidgets('a set with no owner is not cloned while a diver is active', (
    tester,
  ) async {
    await sql(
      tester,
      "INSERT INTO equipment_sets (id, name, created_at, "
      "updated_at) VALUES ('loose', 'Loose', 0, 0)",
    );

    await pumpNewSetPage(tester, cloneFromId: 'loose');

    expect(find.text(l.equipment_setDetail_notFoundMessage), findsOneWidget);
    expect(find.byType(RecordEditBar), findsNothing);
  });

  testWidgets("another diver's set is not cloned", (tester) async {
    await sql(
      tester,
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('d2', 'd2', 0, 0)",
    );
    await sql(
      tester,
      "INSERT INTO equipment_sets (id, diver_id, name, "
      "created_at, updated_at) VALUES ('theirs', 'd2', 'Their Rig', 0, 0)",
    );

    await pumpNewSetPage(tester, cloneFromId: 'theirs');

    expect(find.text(l.equipment_setDetail_notFoundMessage), findsOneWidget);
    expect(find.text(l.equipment_clone_nameCopy('Their Rig')), findsNothing);
  });
}
