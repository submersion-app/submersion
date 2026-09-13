import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_picker_filter.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

EquipmentItem _item(
  String id,
  EquipmentType type, {
  EquipmentStatus status = EquipmentStatus.active,
}) => EquipmentItem(id: id, name: 'Item $id', type: type, status: status);

Future<void> _pump(
  WidgetTester tester, {
  required List<EquipmentItem> equipment,
  Set<String> selectedIds = const {},
  bool hideSpare = false,
  EquipmentPickerFilter filter = EquipmentPickerFilter.none,
  void Function(EquipmentItem)? onSelected,
}) async {
  // Tall enough to render every row without scrolling. The picker groups
  // by type (#1486, #1576) and this fixture gives every type exactly one
  // item, so the list is one heading plus one tile per type; the assembly
  // part types (#1487) brought the enum to 36.
  tester.view.physicalSize = const Size(900, 6400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeEquipmentProvider.overrideWith((ref) async => equipment),
        equipmentPickerFilterProvider.overrideWith((ref) => filter),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: EquipmentPickerSheet(
            scrollController: ScrollController(),
            selectedEquipmentIds: selectedIds,
            hideSpare: hideSpare,
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

  group('spare gear (#1803)', () {
    final equipment = [
      _item('reg', EquipmentType.regulator),
      _item('hose', EquipmentType.other, status: EquipmentStatus.spare),
    ];

    testWidgets('hideSpare keeps spare gear out of the picker', (tester) async {
      await _pump(tester, equipment: equipment, hideSpare: true);

      expect(find.text('Item reg'), findsOneWidget);
      expect(find.text('Item hose'), findsNothing);
    });

    testWidgets('without hideSpare spare gear is still offered', (
      tester,
    ) async {
      // The transmitter registry links cylinders regardless of whether they
      // are in the dive rotation, so it does not opt in.
      await _pump(tester, equipment: equipment);

      expect(find.text('Item reg'), findsOneWidget);
      expect(find.text('Item hose'), findsOneWidget);
    });

    testWidgets('says the rest is spare when that is all that is left', (
      tester,
    ) async {
      // Blaming "no equipment" or "all selected" would send the diver to the
      // wrong place: the gear exists, it is just marked Spare.
      await _pump(
        tester,
        equipment: equipment,
        selectedIds: {'reg'},
        hideSpare: true,
      );

      expect(find.text('Remaining gear is marked Spare'), findsOneWidget);
      expect(
        find.text("Set an item's status to Active to add it to a dive"),
        findsOneWidget,
      );
      expect(find.text('No equipment yet'), findsNothing);
      expect(find.text('All equipment already selected'), findsNothing);
    });

    testWidgets('says the category is spare when the diver filters to one '
        'that only holds spare gear', (tester) async {
      // Active gear of another category keeps the picker non-empty overall,
      // so "No equipment in this category" would be a lie: the category does
      // hold gear, it is just marked Spare.
      await _pump(
        tester,
        equipment: equipment,
        hideSpare: true,
        filter: const EquipmentPickerFilter(type: EquipmentType.other),
      );

      expect(find.text('Remaining gear is marked Spare'), findsOneWidget);
      expect(find.text('No equipment in this category'), findsNothing);
    });

    testWidgets('still blames the category when it holds no gear at all', (
      tester,
    ) async {
      await _pump(
        tester,
        equipment: equipment,
        hideSpare: true,
        filter: const EquipmentPickerFilter(type: EquipmentType.fins),
      );

      expect(find.text('No equipment in this category'), findsOneWidget);
      expect(find.text('Remaining gear is marked Spare'), findsNothing);
    });

    testWidgets('the status filter never offers a Spare chip when hidden', (
      tester,
    ) async {
      await _pump(tester, equipment: equipment, hideSpare: true);

      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();

      expect(find.text('Active'), findsWidgets);
      expect(find.text('Spare'), findsNothing);
    });
  });
}
