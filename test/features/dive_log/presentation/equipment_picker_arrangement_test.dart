import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/domain/models/equipment_picker_filter.dart';
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
    EquipmentType? typeFilter,
    List<EquipmentItem> gear = const [zeagle, faber, apeks],
    EquipmentPickerFilter filter = EquipmentPickerFilter.none,
    Locale locale = const Locale('en'),
    Size? surface,
  }) async {
    if (surface != null) {
      tester.view.physicalSize = surface;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeEquipmentProvider.overrideWith((ref) async => gear),
          equipmentArrangementProvider.overrideWithValue(arrangement),
          equipmentPickerFilterProvider.overrideWith((ref) => filter),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EquipmentPickerSheet(
              scrollController: ScrollController(),
              selectedEquipmentIds: selected,
              typeFilter: typeFilter,
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

  testWidgets('a type filter narrows the list and drops emptied headings', (
    tester,
  ) async {
    await pumpPicker(
      tester,
      filter: const EquipmentPickerFilter(type: EquipmentType.regulator),
    );

    expect(find.text('Apeks'), findsOneWidget);
    expect(find.text('Zeagle'), findsNothing);
    expect(find.text('Faber'), findsNothing);
    expect(
      tester
          .widgetList<EquipmentGroupHeader>(find.byType(EquipmentGroupHeader))
          .map((h) => h.type),
      [EquipmentType.regulator],
    );
  });

  testWidgets('a status filter narrows the list', (tester) async {
    await pumpPicker(
      tester,
      gear: const [
        zeagle,
        EquipmentItem(
          id: 'reg-loaned',
          name: 'Borrowed',
          type: EquipmentType.regulator,
          status: EquipmentStatus.loaned,
        ),
      ],
      filter: const EquipmentPickerFilter(status: EquipmentStatus.loaned),
    );

    expect(find.text('Borrowed'), findsOneWidget);
    expect(find.text('Zeagle'), findsNothing);
  });

  // Two tests rather than one re-pump: pumping again reuses the ProviderScope
  // element, so the StateProvider keeps the value the first pump gave it and
  // the second override never takes effect.
  testWidgets('the filter badge is hidden when nothing is narrowed', (
    tester,
  ) async {
    await pumpPicker(tester);

    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
  });

  testWidgets('the filter badge shows when something is narrowed', (
    tester,
  ) async {
    await pumpPicker(
      tester,
      filter: const EquipmentPickerFilter(type: EquipmentType.tank),
    );

    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
  });

  testWidgets('a filter that hides everything says so, not "all selected"', (
    tester,
  ) async {
    // The three empty states mean different things and must not be conflated.
    await pumpPicker(
      tester,
      filter: const EquipmentPickerFilter(type: EquipmentType.camera),
    );

    expect(find.text('No equipment in this category'), findsOneWidget);
    expect(find.text('All equipment already selected'), findsNothing);
    expect(find.text('Clear All'), findsOneWidget);
  });

  testWidgets('a fully-selected type is not offered as a filter chip', (
    tester,
  ) async {
    // Chips come from what the picker can show, not from everything the diver
    // owns. Offering Tank here would give a chip that could only ever produce
    // an empty list, and an empty state blaming the filter.
    await pumpPicker(tester, selected: {'tank-1'});

    await tester.tap(find.byTooltip('Filter Equipment'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('picker_filter_type_tank')), findsNothing);
    expect(
      find.byKey(const ValueKey('picker_filter_type_regulator')),
      findsOneWidget,
    );
  });

  testWidgets('the current filter stays offered even once nothing matches', (
    tester,
  ) async {
    // Otherwise an active filter would become unclearable from the sheet.
    await pumpPicker(
      tester,
      selected: {'tank-1'},
      filter: const EquipmentPickerFilter(type: EquipmentType.tank),
    );

    await tester.tap(find.byTooltip('Filter Equipment'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('picker_filter_type_tank')),
      findsOneWidget,
    );
  });

  testWidgets("the caller's typeFilter narrows the list and the chips", (
    tester,
  ) async {
    // A caller may constrain the picker (the transmitter registry offers
    // cylinders only). That constraint is not the diver's to clear, so the
    // filter sheet must not offer chips it already rules out.
    await pumpPicker(tester, typeFilter: EquipmentType.regulator);

    expect(find.text('Apeks'), findsOneWidget);
    expect(find.text('Faber'), findsNothing);
    expect(find.text('Zeagle'), findsNothing);

    await tester.tap(find.byTooltip('Filter Equipment'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('picker_filter_type_regulator')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('picker_filter_type_tank')), findsNothing);
  });

  testWidgets("a typeFilter matching nothing does not claim all are selected", (
    tester,
  ) async {
    // Nothing is selected here; the caller's constraint is what emptied the
    // list, so saying "all equipment already selected" would be a lie.
    await pumpPicker(tester, typeFilter: EquipmentType.camera);

    expect(find.text('No equipment in this category'), findsOneWidget);
    expect(find.text('All equipment already selected'), findsNothing);
  });

  testWidgets('the status axis is blamed when the category is not empty', (
    tester,
  ) async {
    // Regulators exist, but none are loaned. The category is populated, so
    // blaming it would be factually wrong: the status axis is what emptied
    // the list.
    await pumpPicker(
      tester,
      filter: const EquipmentPickerFilter(
        type: EquipmentType.regulator,
        status: EquipmentStatus.loaned,
      ),
    );

    expect(find.text('No equipment with this status'), findsOneWidget);
    expect(find.text('No equipment in this category'), findsNothing);
  });

  testWidgets('the category is blamed when it really holds nothing', (
    tester,
  ) async {
    await pumpPicker(
      tester,
      filter: const EquipmentPickerFilter(
        type: EquipmentType.camera,
        status: EquipmentStatus.loaned,
      ),
    );

    expect(find.text('No equipment in this category'), findsOneWidget);
    expect(find.text('No equipment with this status'), findsNothing);
  });

  testWidgets('the filter action opens the filter sheet', (tester) async {
    await pumpPicker(tester);

    await tester.tap(find.byTooltip('Filter Equipment'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('picker_filter_apply')), findsOneWidget);
    // Only categories actually present are offered.
    expect(
      find.byKey(const ValueKey('picker_filter_type_regulator')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('picker_filter_type_camera')),
      findsNothing,
    );
  });

  testWidgets('the header survives a narrow phone and a long title', (
    tester,
  ) async {
    // Three icon buttons sit beside the title, and the French title is 23
    // characters. An inflexible Text in that Row overflows on a small phone.
    await pumpPicker(
      tester,
      locale: const Locale('fr'),
      surface: const Size(320, 640),
    );

    expect(tester.takeException(), isNull);
  });
}
