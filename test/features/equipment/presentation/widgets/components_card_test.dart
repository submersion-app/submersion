import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/components_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeComponentRepository extends EquipmentComponentRepository {
  final removed = <String>[];
  final roles = <String, String>{};
  final reorders = <List<String>>[];

  @override
  Future<void> removeComponent(String id) async => removed.add(id);

  @override
  Future<void> updateRole(String id, String role) async => roles[id] = role;

  @override
  Future<void> reorder(String parentId, List<String> orderedIds) async =>
      reorders.add(orderedIds);

  @override
  Future<List<String>> distinctRoles() async => const ['Necklace', 'Primary'];
}

void main() {
  final t0 = DateTime(2026, 1, 1);

  const first = EquipmentItem(
    id: 'first',
    name: 'DGX first stage',
    type: EquipmentType.firstStage,
  );
  const hose = EquipmentItem(
    id: 'hose',
    name: 'Long hose',
    type: EquipmentType.hose,
    status: EquipmentStatus.retired,
    isActive: false,
  );

  EquipmentComponent part(
    String id,
    EquipmentItem item, {
    String role = '',
    int order = 0,
  }) => EquipmentComponent(
    id: id,
    parentEquipmentId: 'reg',
    componentEquipmentId: item.id,
    role: role,
    sortOrder: order,
    createdAt: t0,
    updatedAt: t0,
    component: item,
  );

  Widget build(List<EquipmentComponent> parts, _FakeComponentRepository repo) {
    return ProviderScope(
      overrides: [
        equipmentComponentRepositoryProvider.overrideWithValue(repo),
        equipmentComponentsProvider('reg').overrideWith((ref) async => parts),
        equipmentComponentsIndexProvider.overrideWith(
          (ref) async => ComponentsIndex.fromRows(parts),
        ),
        equipmentWorstClockProvider.overrideWith((ref) async => {}),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ComponentsCard(equipmentId: 'reg'),
          ),
        ),
      ),
    );
  }

  testWidgets('empty state shows the prompt and the add button', (
    tester,
  ) async {
    await tester.pumpWidget(build(const [], _FakeComponentRepository()));
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
      ], _FakeComponentRepository()),
    );
    await tester.pumpAndSettle();
    expect(find.text('DGX first stage'), findsOneWidget);
    expect(find.text('Primary'), findsOneWidget);
    expect(find.text('Long hose'), findsOneWidget);
    // A part with no role falls back to its type label.
    expect(find.text('Hose'), findsOneWidget);
    expect(find.text('Retired'), findsOneWidget);
  });

  testWidgets('a drag reorders the rows at once and persists the order', (
    tester,
  ) async {
    final repo = _FakeComponentRepository();
    await tester.pumpWidget(
      build([
        part('c1', first, role: 'Primary', order: 0),
        part('c2', hose, order: 1),
      ], repo),
    );
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

    // The rows swapped without waiting for the provider to refresh (the
    // override never changes), and the new order was persisted once.
    expect(
      tester.getTopLeft(find.text('Long hose')).dy,
      lessThan(tester.getTopLeft(find.text('DGX first stage')).dy),
    );
    expect(repo.reorders, [
      ['c2', 'c1'],
    ]);
  });

  testWidgets('the remove icon calls removeComponent with the row id', (
    tester,
  ) async {
    final repo = _FakeComponentRepository();
    await tester.pumpWidget(build([part('c1', first)], repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(repo.removed, ['c1']);
  });

  testWidgets('the edit icon opens the role dialog and saves the new role', (
    tester,
  ) async {
    final repo = _FakeComponentRepository();
    await tester.pumpWidget(build([part('c1', first, role: 'Primary')], repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Component role'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Backup');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.roles, {'c1': 'Backup'});
  });
}
