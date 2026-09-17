import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/data/services/bulk_equipment_tag_service.dart';
import 'package:submersion/features/equipment/presentation/providers/bulk_equipment_tag_provider.dart';
import 'package:submersion/features/equipment/presentation/widgets/bulk_equipment_tag_sheet.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_picker_sheet.dart';
import 'package:submersion/shared/selection/bulk_action.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// A real service whose restore fails, as it would with the database gone.
class _FailingUndoService extends BulkEquipmentTagService {
  _FailingUndoService(super.repository);

  @override
  Future<void> undo(Map<String, List<String>> prior) =>
      Future.error(StateError('database unavailable'));
}

/// A real service whose apply fails, as it would with the database gone.
class _FailingApplyService extends BulkEquipmentTagService {
  _FailingApplyService(super.repository);

  @override
  Future<Map<String, List<String>>> apply({
    required List<String> equipmentIds,
    required Set<String> addTagIds,
    required Set<String> removeTagIds,
  }) => Future.error(StateError('database unavailable'));
}

/// The equipment bulk tag sheet end to end on a real database (issue #1942).
void main() {
  late AppDatabase db;
  late EquipmentTagRepository repository;
  BulkActionOutcome? outcome;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = EquipmentTagRepository();
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) VALUES "
      "('e1', 'Wing', 'bcd', 0, 0), ('e2', 'Reg', 'regulator', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites, applies_to_equipment) VALUES "
      "('t1', 'Travel kit', 0, 0, 0, 0, 1), "
      "('t2', 'Rental', 0, 0, 0, 0, 1), "
      "('t3', 'Cold water', 0, 0, 0, 0, 1), "
      "('t4', 'Nitrox', 0, 0, 1, 0, 0), "
      "('t5', 'Night', 0, 0, 1, 0, 0)",
    );
    // e1: Travel kit, Rental and the dive-only Nitrox. e2: Travel kit.
    await db.customStatement(
      "INSERT INTO equipment_tags (id, equipment_id, tag_id, created_at) "
      "VALUES ('l1', 'e1', 't1', 0), ('l2', 'e1', 't2', 1), "
      "('l3', 'e1', 't4', 2), ('l4', 'e2', 't1', 3)",
    );
  });

  tearDown(() async => tearDownTestDatabase());

  Future<Set<String>> tagIdsOf(String equipmentId) async =>
      ((await repository.getTagIdsByEquipment([equipmentId]))[equipmentId] ??
              const <String>[])
          .toSet();

  /// Hosted in the shell shape, because the sheet opens dialogs and a sheet
  /// from a dialog (#1366).
  Future<void> openSheet(
    WidgetTester tester, {
    List<Object> extraOverrides = const [],
  }) async {
    outcome = null;
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testAppInShell(
        locale: const Locale('en'),
        overrides: [...overrides, ...extraOverrides].cast(),
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () async {
              outcome = await showBulkEquipmentTagSheet(
                context,
                ref,
                equipmentIds: const ['e1', 'e2'],
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Checkbox toggleOf(WidgetTester tester, String tagId) =>
      tester.widget<Checkbox>(find.byKey(ValueKey('membership-toggle-$tagId')));

  Future<void> tapToggle(WidgetTester tester, String tagId) async {
    final toggle = find.byKey(ValueKey('membership-toggle-$tagId'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
  }

  Finder inDialog(String text) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

  testWidgets(
    'lists equipment tags and tags already on an item, with tri-state counts',
    (tester) async {
      await openSheet(tester);

      expect(find.text('Edit tags on 2 items'), findsOneWidget);
      // Travel kit is on both items, Rental on one, Cold water on neither.
      expect(toggleOf(tester, 't1').value, isTrue);
      expect(find.text('on all 2'), findsOneWidget);
      expect(toggleOf(tester, 't2').value, isNull);
      expect(toggleOf(tester, 't3').value, isFalse);
      // Nitrox is a dive tag, listed only because an item carries it.
      expect(toggleOf(tester, 't4').value, isNull);
      expect(find.text('on 1 of 2'), findsNWidgets(2)); // Rental, Nitrox
      expect(find.text('Night'), findsNothing);
      // Nothing changed yet, so there is nothing to apply.
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('bulkEquipmentTags_apply')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('apply confirms the change, then Undo restores every item', (
    tester,
  ) async {
    await openSheet(tester);
    await tapToggle(tester, 't3'); // on none -> add to all
    await tapToggle(tester, 't1'); // on all -> remove from all

    await tester.tap(find.byKey(const ValueKey('bulkEquipmentTags_apply')));
    await tester.pumpAndSettle();

    expect(inDialog('Adding to all 2 equipment items'), findsOneWidget);
    expect(inDialog('Cold water'), findsOneWidget);
    expect(inDialog('Removing from all 2 equipment items'), findsOneWidget);
    expect(inDialog('Travel kit'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bulkEquipmentTags_confirm')));
    await tester.pumpAndSettle();

    expect(outcome, BulkActionOutcome.completed);
    expect(await tagIdsOf('e1'), {'t2', 't3', 't4'});
    expect(await tagIdsOf('e2'), {'t3'});
    expect(find.text('Updated tags on 2 items'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(await tagIdsOf('e1'), {'t1', 't2', 't4'});
    expect(await tagIdsOf('e2'), {'t1'});
  });

  testWidgets('an apply that fails says so and changes nothing', (
    tester,
  ) async {
    await openSheet(
      tester,
      extraOverrides: [
        bulkEquipmentTagServiceProvider.overrideWithValue(
          _FailingApplyService(repository),
        ),
      ],
    );
    await tapToggle(tester, 't3');
    await tester.tap(find.byKey(const ValueKey('bulkEquipmentTags_apply')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bulkEquipmentTags_confirm')));
    await tester.pumpAndSettle();

    expect(outcome, BulkActionOutcome.failed);
    expect(
      find.textContaining('Could not update tags:'),
      findsOneWidget,
      reason: 'the error names what failed',
    );
    expect(await tagIdsOf('e1'), {'t1', 't2', 't4'});
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('an Undo that fails says so', (tester) async {
    await openSheet(
      tester,
      extraOverrides: [
        bulkEquipmentTagServiceProvider.overrideWithValue(
          _FailingUndoService(repository),
        ),
      ],
    );
    await tapToggle(tester, 't1'); // on all -> remove from all
    await tester.tap(find.byKey(const ValueKey('bulkEquipmentTags_apply')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bulkEquipmentTags_confirm')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't undo the tag change."), findsOneWidget);
    expect(await tagIdsOf('e1'), {'t2', 't4'}, reason: 'nothing restored');
  });

  testWidgets('cancelling the sheet changes nothing and reports cancelled', (
    tester,
  ) async {
    await openSheet(tester);
    await tapToggle(tester, 't3');

    await tester.tap(find.byKey(const ValueKey('bulkEquipmentTags_cancel')));
    await tester.pumpAndSettle();

    expect(outcome, BulkActionOutcome.cancelled);
    expect(await tagIdsOf('e1'), {'t1', 't2', 't4'});
    expect(await tagIdsOf('e2'), {'t1'});
  });

  testWidgets('cancelling the confirmation keeps the sheet and its edits', (
    tester,
  ) async {
    await openSheet(tester);
    await tapToggle(tester, 't3');
    await tester.tap(find.byKey(const ValueKey('bulkEquipmentTags_apply')));
    await tester.pumpAndSettle();

    await tester.tap(inDialog('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(toggleOf(tester, 't3').value, isTrue);
    expect(outcome, isNull);
    expect(await tagIdsOf('e2'), {'t1'});
  });

  testWidgets('a tag picked through Add is switched on for every item', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Add'));
    await tester.pumpAndSettle();
    await tester.tap(inDialog('Browse'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(TagPickerSheet),
        matching: find.text('Cold water'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add 1 tag'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Add'),
      ),
    );
    await tester.pumpAndSettle();

    expect(toggleOf(tester, 't3').value, isTrue);
    expect(find.text('adding to all 2'), findsOneWidget);
  });
}
