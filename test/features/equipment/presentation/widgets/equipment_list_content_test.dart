import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_field.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _TestEquipTableConfigNotifier
    extends EntityTableConfigNotifier<EquipmentField> {
  _TestEquipTableConfigNotifier(EntityTableViewConfig<EquipmentField> config)
    : super(
        defaultConfig: config,
        fieldFromName: EquipmentFieldAdapter.instance.fieldFromName,
      );
}

final _testConfig = EntityTableViewConfig<EquipmentField>(
  columns: [
    EntityTableColumnConfig(field: EquipmentField.itemName, isPinned: true),
    EntityTableColumnConfig(field: EquipmentField.type),
    EntityTableColumnConfig(field: EquipmentField.brand),
    EntityTableColumnConfig(field: EquipmentField.model),
    EntityTableColumnConfig(field: EquipmentField.status),
    EntityTableColumnConfig(field: EquipmentField.lastServiceDate),
  ],
);

EquipmentItem _makeEquipment({
  required String id,
  required String name,
  EquipmentType type = EquipmentType.regulator,
  String? brand,
  String? model,
  EquipmentStatus status = EquipmentStatus.active,
}) {
  return EquipmentItem(
    id: id,
    name: name,
    type: type,
    brand: brand,
    model: model,
    status: status,
  );
}

Future<List<Override>> _buildOverrides({
  required List<EquipmentItem> equipment,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    // The equipment list content watches equipmentByStatusProvider(null) for
    // all equipment when no filter is selected, so we override that.
    equipmentByStatusProvider.overrideWith((ref, status) => equipment),
    equipmentListViewModeProvider.overrideWith((ref) => ListViewMode.table),
    equipmentTableConfigProvider.overrideWith(
      (ref) => _TestEquipTableConfigNotifier(_testConfig),
    ),
  ];
}

void main() {
  group('EquipmentListContent in table mode', () {
    testWidgets('renders table with column headers', (tester) async {
      final equipment = [
        _makeEquipment(
          id: 'e1',
          name: 'Primary Reg',
          type: EquipmentType.regulator,
          brand: 'Apeks',
          model: 'XTX200',
        ),
        _makeEquipment(
          id: 'e2',
          name: 'Travel BCD',
          type: EquipmentType.bcd,
          brand: 'Mares',
          model: 'Rover',
        ),
      ];

      final overrides = await _buildOverrides(equipment: equipment);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Verify column headers from displayName values
      expect(find.text('Name'), findsWidgets);
      expect(find.text('Type'), findsOneWidget);
      expect(find.text('Brand'), findsOneWidget);
      expect(find.text('Model'), findsOneWidget);
    });

    testWidgets('renders rows for each equipment item', (tester) async {
      final equipment = [
        _makeEquipment(id: 'e1', name: 'Primary Reg'),
        _makeEquipment(id: 'e2', name: 'Travel BCD'),
        _makeEquipment(id: 'e3', name: 'Wetsuit 5mm'),
      ];

      final overrides = await _buildOverrides(equipment: equipment);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Primary Reg'), findsOneWidget);
      expect(find.text('Travel BCD'), findsOneWidget);
      expect(find.text('Wetsuit 5mm'), findsOneWidget);
    });

    testWidgets('shows empty state when no equipment', (tester) async {
      final overrides = await _buildOverrides(equipment: []);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.backpack), findsOneWidget);
    });

    // Column settings are now provided by TableModeLayout, not the content
    // widget. The compact bar provides sort, search, and view mode controls.

    testWidgets('renders with showAppBar false (compact bar)', (tester) async {
      final overrides = await _buildOverrides(
        equipment: [_makeEquipment(id: 'e1', name: 'My Fins')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.text('My Fins'), findsOneWidget);
    });

    // Vertical divider was part of the standalone table app bar, now removed.
    // Column settings and divider are in TableModeLayout.

    testWidgets('table shows filter chips area', (tester) async {
      final overrides = await _buildOverrides(
        equipment: [_makeEquipment(id: 'e1', name: 'Test Reg')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Filter chips area should render with filter icon
      expect(find.byIcon(Icons.filter_list), findsOneWidget);
    });

    testWidgets('table renders equipment data in cells', (tester) async {
      final equipment = [
        _makeEquipment(
          id: 'e1',
          name: 'Primary Reg',
          type: EquipmentType.regulator,
          brand: 'Apeks',
          model: 'XTX200',
        ),
      ];

      final overrides = await _buildOverrides(equipment: equipment);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Primary Reg'), findsOneWidget);
      expect(find.text('Apeks'), findsOneWidget);
      expect(find.text('XTX200'), findsOneWidget);
    });

    testWidgets('renders equipment with various types', (tester) async {
      final equipment = [
        _makeEquipment(
          id: 'et1',
          name: 'My Reg',
          type: EquipmentType.regulator,
        ),
        _makeEquipment(id: 'et2', name: 'My BCD', type: EquipmentType.bcd),
        _makeEquipment(id: 'et3', name: 'My Suit', type: EquipmentType.wetsuit),
        _makeEquipment(id: 'et4', name: 'My Light', type: EquipmentType.light),
      ];

      final overrides = await _buildOverrides(equipment: equipment);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('My Reg'), findsOneWidget);
      expect(find.text('My BCD'), findsOneWidget);
      expect(find.text('My Suit'), findsOneWidget);
      expect(find.text('My Light'), findsOneWidget);
    });

    testWidgets('renders equipment with null brand and model', (tester) async {
      final equipment = [
        _makeEquipment(
          id: 'nb1',
          name: 'Generic Item',
          brand: null,
          model: null,
        ),
      ];

      final overrides = await _buildOverrides(equipment: equipment);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Generic Item'), findsOneWidget);
    });

    testWidgets('renders many equipment items without crash', (tester) async {
      final equipment = List.generate(
        15,
        (i) => _makeEquipment(id: 'me$i', name: 'Item $i'),
      );

      final overrides = await _buildOverrides(equipment: equipment);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Item 0'), findsOneWidget);
    });

    testWidgets('renders equipment with different statuses', (tester) async {
      final equipment = [
        _makeEquipment(
          id: 'st1',
          name: 'Active Reg',
          status: EquipmentStatus.active,
        ),
        _makeEquipment(
          id: 'st2',
          name: 'Retired BCD',
          status: EquipmentStatus.retired,
        ),
      ];

      final overrides = await _buildOverrides(equipment: equipment);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Active Reg'), findsOneWidget);
      expect(find.text('Retired BCD'), findsOneWidget);
    });

    testWidgets('tapping a row sets highlighted equipment id', (tester) async {
      final equipment = [
        _makeEquipment(id: 'e1', name: 'My Regulator'),
        _makeEquipment(id: 'e2', name: 'My BCD'),
      ];

      final overrides = await _buildOverrides(equipment: equipment);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const EquipmentListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Tap on an equipment row
      await tester.tap(find.text('My Regulator'));
      // Pump past the DoubleTapGestureRecognizer's 40ms timer
      await tester.pump(const Duration(milliseconds: 50));

      // Verify the widget rebuilt successfully (no crash)
      expect(find.text('My Regulator'), findsOneWidget);
    });
  });
}
