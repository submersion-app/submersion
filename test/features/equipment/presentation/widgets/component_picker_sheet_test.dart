import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/component_picker_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeComponentRepository extends EquipmentComponentRepository {
  final added = <(String, String)>[];
  bool throwCycle = false;
  Object? throwOther;

  @override
  Future<EquipmentComponent> addComponent({
    required String parentId,
    required String componentId,
    String role = '',
  }) async {
    if (throwCycle) {
      throw EquipmentComponentCycleException(parentId, componentId);
    }
    if (throwOther != null) throw throwOther!;
    added.add((parentId, componentId));
    return EquipmentComponent(
      id: 'new-$componentId',
      parentEquipmentId: parentId,
      componentEquipmentId: componentId,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }
}

void main() {
  final t0 = DateTime(2026, 1, 1);
  EquipmentItem item(String id, EquipmentType type) =>
      EquipmentItem(id: id, name: 'Name $id', type: type);
  var seq = 0;
  EquipmentComponent edge(String parent, String child) => EquipmentComponent(
    id: 'c${seq++}',
    parentEquipmentId: parent,
    componentEquipmentId: child,
    createdAt: t0,
    updatedAt: t0,
  );

  final active = [
    item('kit', EquipmentType.other),
    item('reg', EquipmentType.regulator),
    item('first', EquipmentType.firstStage),
    item('hose', EquipmentType.hose),
    item('fins', EquipmentType.fins),
  ];
  // kit > reg > first; the picker for reg must hide kit (ancestor), reg
  // (self), first (already a part), and offer hose and fins.
  final edges = [edge('kit', 'reg'), edge('reg', 'first')];

  Widget build(
    _FakeComponentRepository repo, {
    Future<ComponentsIndex>? index,
  }) => ProviderScope(
    overrides: [
      equipmentComponentRepositoryProvider.overrideWithValue(repo),
      activeEquipmentProvider.overrideWith((ref) async => active),
      equipmentComponentsIndexProvider.overrideWith(
        (ref) => index ?? Future.value(ComponentsIndex.fromRows(edges)),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ComponentPickerSheet(
          parentId: 'reg',
          scrollController: ScrollController(),
        ),
      ),
    ),
  );

  testWidgets('hides self, ancestors, and current parts', (tester) async {
    await tester.pumpWidget(build(_FakeComponentRepository()));
    await tester.pumpAndSettle();
    expect(find.text('Name hose'), findsOneWidget);
    expect(find.text('Name fins'), findsOneWidget);
    expect(find.text('Name reg'), findsNothing);
    expect(find.text('Name kit'), findsNothing);
    expect(find.text('Name first'), findsNothing);
  });

  testWidgets('confirm adds every checked item under the parent', (
    tester,
  ) async {
    final repo = _FakeComponentRepository();
    await tester.pumpWidget(build(repo));
    await tester.pumpAndSettle();
    expect(find.text('Add'), findsOneWidget);
    await tester.tap(find.text('Name hose'));
    await tester.pump();
    expect(find.text('Add 1'), findsOneWidget);
    await tester.tap(find.text('Name fins'));
    await tester.pump();
    await tester.tap(find.text('Add 2'));
    await tester.pumpAndSettle();
    expect(repo.added, unorderedEquals([('reg', 'hose'), ('reg', 'fins')]));
  });

  testWidgets('offers nothing while the index is still loading', (
    tester,
  ) async {
    // An empty stand-in index would list the parent and its relatives as
    // candidates until the real one arrived.
    final pending = Completer<ComponentsIndex>();
    await tester.pumpWidget(
      build(_FakeComponentRepository(), index: pending.future),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
    pending.complete(ComponentsIndex.fromRows(edges));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Name hose'), findsOneWidget);
    expect(find.text('Name reg'), findsNothing);
  });

  testWidgets('a non-cycle failure reports itself and re-enables the sheet', (
    tester,
  ) async {
    final repo = _FakeComponentRepository()..throwOther = StateError('boom');
    await tester.pumpWidget(build(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name hose'));
    await tester.pump();
    await tester.tap(find.text('Add 1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('boom'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('a cycle refused by the repository shows the explanation', (
    tester,
  ) async {
    final repo = _FakeComponentRepository()..throwCycle = true;
    await tester.pumpWidget(build(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name hose'));
    await tester.pump();
    await tester.tap(find.text('Add 1'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('cannot be added as a component'),
      findsOneWidget,
    );
  });
}
