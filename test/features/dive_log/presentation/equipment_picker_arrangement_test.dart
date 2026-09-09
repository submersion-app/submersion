import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_group_header.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The Add Equipment picker carries the same arrangement as the gear lists
/// it feeds, which #1576 asked for by name.
void main() {
  const zeagle = EquipmentItem(
    id: 'bcd-1',
    name: 'Zeagle',
    type: EquipmentType.bcd,
  );
  const faber = EquipmentItem(
    id: 'tank-1',
    name: 'Faber',
    type: EquipmentType.tank,
  );
  const apeks = EquipmentItem(
    id: 'reg-1',
    name: 'Apeks',
    type: EquipmentType.regulator,
  );

  Future<void> pumpPicker(
    WidgetTester tester, {
    EquipmentArrangement arrangement = EquipmentArrangement.defaults,
    Set<String> selected = const {},
    List<EquipmentItem> gear = const [zeagle, faber, apeks],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeEquipmentProvider.overrideWith((ref) async => gear),
          equipmentArrangementProvider.overrideWithValue(arrangement),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EquipmentPickerSheet(
              scrollController: ScrollController(),
              selectedEquipmentIds: selected,
              onEquipmentSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('groups available gear by type', (tester) async {
    await pumpPicker(tester);

    final headers = tester
        .widgetList<EquipmentGroupHeader>(find.byType(EquipmentGroupHeader))
        .map((h) => h.type)
        .toList();

    expect(headers, [
      EquipmentType.bcd,
      EquipmentType.regulator,
      EquipmentType.tank,
    ]);
  });

  testWidgets('honours a non-default type order', (tester) async {
    await pumpPicker(
      tester,
      arrangement: EquipmentArrangement.defaults.copyWith(
        typeOrder: EquipmentTypeOrder.headToToe,
      ),
    );

    final headers = tester
        .widgetList<EquipmentGroupHeader>(find.byType(EquipmentGroupHeader))
        .map((h) => h.type)
        .toList();

    expect(headers, [
      EquipmentType.tank,
      EquipmentType.regulator,
      EquipmentType.bcd,
    ]);
  });

  testWidgets('already-selected gear is excluded, and its heading with it', (
    tester,
  ) async {
    await pumpPicker(tester, selected: {'tank-1'});

    expect(find.text('Faber'), findsNothing);
    expect(
      tester
          .widgetList<EquipmentGroupHeader>(find.byType(EquipmentGroupHeader))
          .map((h) => h.type),
      isNot(contains(EquipmentType.tank)),
    );
  });

  testWidgets('the empty state still renders when everything is selected', (
    tester,
  ) async {
    await pumpPicker(tester, selected: const {'bcd-1', 'tank-1', 'reg-1'});

    expect(find.text('All equipment already selected'), findsOneWidget);
  });

  testWidgets('the header action opens the arrange sheet', (tester) async {
    await pumpPicker(tester);

    await tester.tap(find.byTooltip('Arrange gear'));
    await tester.pumpAndSettle();

    expect(find.text('Order types by'), findsOneWidget);
  });
}
