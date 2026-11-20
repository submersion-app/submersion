import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_history_rewrite.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/domain/services/assembly_totals.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_components_sitting.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/assembly_totals_section.dart';
import 'package:submersion/features/equipment/presentation/widgets/components_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';
import 'components_card_harness.dart';

void main() {
  // Issue #4527, phase 3: a part added in the item's sitting and removed
  // again was never on a dive, so there is nothing to ask about.
  testWidgets('in a sitting, removing a part added in it asks nothing', (
    tester,
  ) async {
    final session = EditSession(
      const EquipmentItem(
        id: 'reg',
        name: 'Reg',
        type: EquipmentType.regulator,
      ),
    );
    addTearDown(session.dispose);
    gearItemComponentsList.loadNone(session);
    gearItemComponentsList.set(session, [part('held', hose)]);
    await tester.pumpWidget(
      build(
        const [],
        FakeComponentRepository(),
        count: DiveCount()..diveCount = 3,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ComponentsCard(equipmentId: 'reg', editing: session),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(hose.name), findsOneWidget);

    await tester.tap(find.byTooltip('Remove component'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(hose.name), findsNothing);
    expect(session.hasHeldWrites, isFalse);
  });

  testWidgets('ends with what the parts add up to (#4443)', (tester) async {
    await tester.pumpWidget(
      build(
        [part('a', first)],
        FakeComponentRepository(),
        totals: const AssemblyTotals(
          partCount: 1,
          buoyancy: (kg: -4.0, parts: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AssemblyTotalsSection), findsOneWidget);
    expect(find.text('-4 kg'), findsOneWidget);
  });

  testWidgets('the open card\'s empty state shows the prompt and the add '
      'button', (tester) async {
    await tester.pumpWidget(
      build(
        const [],
        FakeComponentRepository(),
        home: openCard(sittingWith(const [])),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Components'), findsOneWidget);
    expect(find.textContaining('No components'), findsOneWidget);
    expect(find.text('Add component'), findsOneWidget);
  });

  testWidgets('renders one row per part with role, and a retired badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      build([
        part('c1', first, role: 'Primary', order: 0),
        part('c2', hose, order: 1),
      ], FakeComponentRepository()),
    );
    await tester.pumpAndSettle();
    expect(find.text('DGX first stage'), findsOneWidget);
    expect(find.text('Primary'), findsOneWidget);
    expect(find.text('Long hose'), findsOneWidget);
    // A part with no role falls back to its type label.
    expect(find.text('Hose'), findsOneWidget);
    expect(find.text('Retired'), findsOneWidget);
  });

  testWidgets('with no sitting the card offers no add, replace, remove, role '
      'edit or drag', (tester) async {
    await tester.pumpWidget(
      build([
        part('c1', first, role: 'Primary', order: 0),
        part('c2', hose, order: 1),
      ], FakeComponentRepository()),
    );
    await tester.pumpAndSettle();
    expect(find.text('DGX first stage'), findsOneWidget);
    expect(find.text('Add component'), findsNothing);
    expect(find.byTooltip('Replace component'), findsNothing);
    expect(find.byTooltip('Remove component'), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.drag_handle), findsNothing);
  });

  testWidgets('a part with a clock coming due gets the warn dot', (
    tester,
  ) async {
    final dueSoon = (
      item: first,
      status: ServiceClockStatus(
        schedule: ServiceSchedule(
          id: 's1',
          equipmentId: first.id,
          serviceKindId: 'annual',
          createdAt: t0,
          updatedAt: t0,
        ),
        kind: ServiceKind(
          id: 'annual',
          name: 'Annual service',
          createdAt: t0,
          updatedAt: t0,
        ),
        anchor: t0,
        dueDate: t0.add(const Duration(days: 360)),
        severity: ServiceClockSeverity.dueSoon,
        now: t0.add(const Duration(days: 340)),
      ),
    );
    await tester.pumpWidget(
      build(
        [part('c1', first, order: 0), part('c2', spare, order: 1)],
        FakeComponentRepository(),
        worst: {first.id: dueSoon},
      ),
    );
    await tester.pumpAndSettle();

    final dots = tester
        .widgetList<Icon>(find.byIcon(Icons.circle))
        .map((d) => d.color)
        .toList();
    expect(dots, contains(StatusColors.light.warn.accent));
    expect(dots, isNot(contains(StatusColors.light.alert.accent)));
  });

  testWidgets('a sold part keeps its Sold status, not Retired', (tester) async {
    const sold = EquipmentItem(
      id: 'sold',
      name: 'Sold hose',
      type: EquipmentType.hose,
      status: EquipmentStatus.sold,
      isActive: false,
    );
    await tester.pumpWidget(
      build([part('c1', sold)], FakeComponentRepository()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sold'), findsOneWidget);
    expect(find.text('Retired'), findsNothing);
  });

  testWidgets('a lost part still marked active is badged Lost', (tester) async {
    const lost = EquipmentItem(
      id: 'lost',
      name: 'Lost torch',
      type: EquipmentType.light,
      status: EquipmentStatus.lost,
    );
    await tester.pumpWidget(
      build([part('c1', lost)], FakeComponentRepository()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lost'), findsOneWidget);
  });

  testWidgets('a drag reorders the rows at once and holds the order', (
    tester,
  ) async {
    final repo = FakeComponentRepository();
    final rows = [
      part('c1', first, role: 'Primary', order: 0),
      part('c2', hose, order: 1),
    ];
    final session = sittingWith(rows);
    await tester.pumpWidget(build(rows, repo, home: openCard(session)));
    await tester.pumpAndSettle();
    final handles = find.byIcon(Icons.drag_handle);
    expect(handles, findsNWidgets(2));
    final firstBefore = tester.getTopLeft(find.text('DGX first stage')).dy;
    final hoseBefore = tester.getTopLeft(find.text('Long hose')).dy;
    expect(firstBefore, lessThan(hoseBefore));

    // Drag the first row's handle below the second row. The handle is a
    // ReorderableDragStartListener, so the drag starts on touch-down.
    final drag = await tester.startGesture(tester.getCenter(handles.first));
    await tester.pump();
    // A row is about 72 px tall; the dragged row must travel past the next
    // row's midpoint before the list commits the swap, so go well beyond.
    for (var i = 0; i < 10; i++) {
      await drag.moveBy(const Offset(0, 16));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await drag.up();
    await tester.pumpAndSettle();

    // The rows swapped, and the new order is held in the sitting until
    // Save rather than written.
    expect(
      tester.getTopLeft(find.text('Long hose')).dy,
      lessThan(tester.getTopLeft(find.text('DGX first stage')).dy),
    );
    expect(gearItemComponentsList.current(session)!.map((p) => p.id), [
      'c2',
      'c1',
    ]);
    expect(repo.reorders, isEmpty);
  });

  // The parts as stored, read into the open card's sitting: removing one
  // asks "Update past dives?", and both the removal and the answer wait for
  // Save, which writes through the fakes here.
  group('removing a stored part in a sitting', () {
    late FakeComponentRepository repo;
    late FakeDiveRepository dives;
    late EditSession<EquipmentItem> session;
    late EquipmentComponent stored;

    setUp(() async {
      await setUpTestDatabase();
      addTearDown(SyncCoordinator.reset);
      repo = FakeComponentRepository();
      dives = FakeDiveRepository();
      const reg = EquipmentItem(
        id: 'reg',
        name: 'Reg',
        type: EquipmentType.regulator,
      );
      final items = EquipmentRepository();
      for (final item in const [reg, first]) {
        await items.createEquipment(item);
      }
      await EquipmentComponentRepository().addComponent(
        parentId: 'reg',
        componentId: 'first',
      );
      session = EditSession(reg);
      addTearDown(session.dispose);
      T read<T>(ProviderListenable<T> provider) =>
          (identical(provider, equipmentComponentRepositoryProvider)
                  ? repo
                  : identical(provider, diveRepositoryProvider)
                  ? dives
                  : throw ArgumentError('$provider'))
              as T;
      holdGearItemComponents(session, read);
      await gearItemComponentsList.currentOrRead(session);
      stored = gearItemComponentsList.loaded(session)!.single;
    });
    tearDown(tearDownTestDatabase);

    Future<void> pumpOpenCard(WidgetTester tester, {DiveCount? count}) async {
      await tester.pumpWidget(
        build(
          const [],
          repo,
          count: count,
          dives: dives,
          home: openCard(session),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('DGX first stage'), findsOneWidget);
    }

    testWidgets('with no past dives it asks nothing, and Save rewrites the '
        'planned dives', (tester) async {
      await pumpOpenCard(tester);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('Update past dives?'), findsNothing);
      expect(find.text('DGX first stage'), findsNothing);
      expect(gearItemComponentsList.current(session), isEmpty);
      expect(repo.removed, isEmpty);
      expect(dives.rewrites, isEmpty);

      await session.runHeldWrites();

      expect(repo.removed, [stored.id]);
      // Planned dives still follow the change (issue #4283). Compared field
      // by field: a record holding a List compares that field by identity.
      expect(dives.rewrites.map((r) => r.$3), [true, false]);
      expect(dives.rewrites.first.$2, isEmpty);
      expect(dives.rewrites.last.$2, const [GearPartRemoved('first')]);
    });

    testWidgets('with past dives it asks, and Also update reaches the logged '
        'dives at Save', (tester) async {
      await pumpOpenCard(tester, count: DiveCount()..diveCount = 2);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('Update past dives?'), findsOneWidget);
      expect(find.textContaining('Remove the part'), findsOneWidget);
      await tester.tap(find.text('Also update 2 dives'));
      await tester.pumpAndSettle();
      expect(gearItemComponentsList.current(session), isEmpty);
      expect(repo.removed, isEmpty);
      expect(dives.rewrites, isEmpty);

      await session.runHeldWrites();

      expect(repo.removed, [stored.id]);
      expect(dives.rewrites.map((r) => (r.$1, r.$3)), [
        ('reg', true),
        ('reg', false),
      ]);
      expect(dives.rewrites.first.$2, const [GearPartRemoved('first')]);
      expect(dives.rewrites.last.$2, isEmpty);
    });

    testWidgets('From now on holds the removal for the planned dives only', (
      tester,
    ) async {
      await pumpOpenCard(tester, count: DiveCount()..diveCount = 2);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('From now on'));
      await tester.pumpAndSettle();
      expect(gearItemComponentsList.current(session), isEmpty);
      expect(repo.removed, isEmpty);

      await session.runHeldWrites();

      expect(repo.removed, [stored.id]);
      expect(dives.rewrites.map((r) => r.$3), [true, false]);
      expect(dives.rewrites.first.$2, isEmpty);
      expect(dives.rewrites.last.$2, const [GearPartRemoved('first')]);
    });

    testWidgets('a failed dive count is reported, and removes nothing', (
      tester,
    ) async {
      await pumpOpenCard(
        tester,
        count: DiveCount()..throwOnCount = StateError('no database'),
      );
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('Update past dives?'), findsNothing);
      expect(find.textContaining('no database'), findsOneWidget);
      expect(gearItemComponentsList.current(session), [stored]);
      expect(session.hasHeldWrites, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancelling the question changes nothing', (tester) async {
      await pumpOpenCard(tester, count: DiveCount()..diveCount = 2);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('DGX first stage'), findsOneWidget);
      expect(gearItemComponentsList.current(session), [stored]);
      expect(session.hasHeldWrites, isFalse);
      expect(repo.removed, isEmpty);
      expect(dives.rewrites, isEmpty);
    });
  });

  testWidgets('the replace icon opens the picker in single-select mode', (
    tester,
  ) async {
    final rows = [part('c1', first)];
    await tester.pumpWidget(
      build(rows, FakeComponentRepository(), home: openCard(sittingWith(rows))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Replace component'));
    await tester.pumpAndSettle();
    expect(find.text('Replace with'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Replace'), findsOneWidget);
    // The row being replaced is a current part, so it is not a candidate,
    // while the spare of the same type is.
    expect(find.text('Spare first stage'), findsOneWidget);
    expect(find.text('DGX first stage'), findsOneWidget);
  });

  testWidgets('the edit icon opens the role dialog and holds the new role', (
    tester,
  ) async {
    final repo = FakeComponentRepository();
    final rows = [part('c1', first, role: 'Primary')];
    final session = sittingWith(rows);
    await tester.pumpWidget(build(rows, repo, home: openCard(session)));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Component role'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Backup');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(gearItemComponentsList.current(session)!.single.role, 'Backup');
    expect(find.text('Backup'), findsOneWidget);
    expect(repo.roles, isEmpty);
  });
}
