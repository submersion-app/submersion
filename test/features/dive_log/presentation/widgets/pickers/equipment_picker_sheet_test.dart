import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

EquipmentItem _item(String id, EquipmentType type) =>
    EquipmentItem(id: id, name: 'Item $id', type: type);

Future<void> _pump(
  WidgetTester tester, {
  required List<EquipmentItem> equipment,
  Set<String> selectedIds = const {},
  void Function(EquipmentItem)? onSelected,
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [allEquipmentProvider.overrideWith((ref) async => equipment)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: EquipmentPickerSheet(
            scrollController: ScrollController(),
            selectedEquipmentIds: selectedIds,
            onEquipmentSelected: onSelected ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists equipment of every type with icons', (tester) async {
    // One item per type exercises the full icon mapping.
    final equipment = [
      for (final (i, type) in EquipmentType.values.indexed) _item('e$i', type),
    ];
    await _pump(tester, equipment: equipment);
    expect(find.text('Add Equipment'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(EquipmentType.values.length));
  });

  testWidgets('filters out already selected items and selects on tap', (
    tester,
  ) async {
    final equipment = [
      _item('a', EquipmentType.regulator),
      _item('b', EquipmentType.mask),
    ];
    EquipmentItem? selected;
    await _pump(
      tester,
      equipment: equipment,
      selectedIds: {'a'},
      onSelected: (item) => selected = item,
    );
    expect(find.text('Item a'), findsNothing);
    await tester.tap(find.text('Item b'));
    expect(selected?.id, 'b');
  });

  testWidgets('shows empty state when there is no equipment', (tester) async {
    await _pump(tester, equipment: const []);
    expect(find.text('No equipment yet'), findsOneWidget);
    expect(find.text('Add equipment from the Equipment tab'), findsOneWidget);
  });

  testWidgets('shows all-selected state when everything is on the dive', (
    tester,
  ) async {
    await _pump(
      tester,
      equipment: [_item('a', EquipmentType.fins)],
      selectedIds: {'a'},
    );
    expect(find.text('All equipment already selected'), findsOneWidget);
    expect(find.text('Remove items to add different ones'), findsOneWidget);
  });
}
