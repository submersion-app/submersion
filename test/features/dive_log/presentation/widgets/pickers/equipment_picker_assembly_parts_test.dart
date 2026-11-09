import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_picker_filter.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/folded_groups.dart';

const _reg = EquipmentItem(
  id: 'reg',
  name: 'Cold Water Reg',
  type: EquipmentType.regulator,
);

const _first = EquipmentItem(
  id: 'first',
  name: 'DIN First Stage',
  type: EquipmentType.firstStage,
);

const _second = EquipmentItem(
  id: 'second',
  name: 'Primary Second Stage',
  type: EquipmentType.secondStage,
);

const _bcd = EquipmentItem(
  id: 'bcd',
  name: 'Hydros BCD',
  type: EquipmentType.bcd,
);

const _showLabel = 'Show components of assemblies';

final _t0 = DateTime(2026, 1, 1);

EquipmentComponent _edge(String parent, String child) => EquipmentComponent(
  id: '$parent>$child',
  parentEquipmentId: parent,
  componentEquipmentId: child,
  createdAt: _t0,
  updatedAt: _t0,
);

/// The reg is an assembly of the first and second stage.
final _regIndex = ComponentsIndex.fromRows([
  _edge('reg', 'first'),
  _edge('reg', 'second'),
]);

Future<void> _pump(
  WidgetTester tester, {
  required List<EquipmentItem> all,
  ComponentsIndex? index,
  bool hideAssemblyParts = true,
  bool offerLeftKit = false,
  Set<String> selectedIds = const {},
  EquipmentPickerFilter filter = EquipmentPickerFilter.none,
  void Function(EquipmentItem)? onSelected,
  ValueNotifier<bool>? sheetOpen,
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final scrollController = ScrollController();
  addTearDown(scrollController.dispose);
  final sheet = EquipmentPickerSheet(
    scrollController: scrollController,
    selectedEquipmentIds: selectedIds,
    hideSpare: true,
    hideAssemblyParts: hideAssemblyParts,
    offerLeftKit: offerLeftKit,
    onEquipmentSelected: onSelected ?? (_) {},
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeEquipmentProvider.overrideWith(
          (ref) async => all.where((e) => e.isFitted).toList(),
        ),
        allEquipmentProvider.overrideWith((ref) async => all),
        equipmentComponentsIndexProvider.overrideWith(
          (ref) async => index ?? _regIndex,
        ),
        equipmentPickerFilterProvider.overrideWith((ref) => filter),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        allDiversProvider.overrideWith((ref) async => const []),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // With [sheetOpen], the sheet can be closed and reopened inside the
        // same ProviderScope, as a caller's bottom sheet is.
        home: Scaffold(
          body: sheetOpen == null
              ? sheet
              : ValueListenableBuilder<bool>(
                  valueListenable: sheetOpen,
                  builder: (_, open, _) =>
                      open ? sheet : const SizedBox.shrink(),
                ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // The picker opens with its groups folded (#3364).
  await openFoldedGroups(tester);
}

Future<void> _showParts(WidgetTester tester) async {
  await tester.tap(find.text(_showLabel));
  await tester.pumpAndSettle();
  await openFoldedGroups(tester);
}

void main() {
  group('components of an offered assembly (#2514)', () {
    testWidgets('are hidden, since picking the assembly brings them', (
      tester,
    ) async {
      await _pump(tester, all: const [_reg, _first, _second, _bcd]);

      expect(find.text('Cold Water Reg'), findsOneWidget);
      expect(find.text('Hydros BCD'), findsOneWidget);
      expect(find.text('DIN First Stage'), findsNothing);
      expect(find.text('Primary Second Stage'), findsNothing);
      expect(find.text(_showLabel), findsOneWidget);
    });

    testWidgets('come back with the switch and can be picked', (tester) async {
      EquipmentItem? picked;
      await _pump(
        tester,
        all: const [_reg, _first, _second, _bcd],
        onSelected: (e) => picked = e,
      );
      await _showParts(tester);

      expect(find.text('DIN First Stage'), findsOneWidget);
      expect(find.text('Primary Second Stage'), findsOneWidget);
      await tester.tap(find.text('DIN First Stage'));
      expect(picked?.id, 'first');
    });

    testWidgets('are offered when their assembly is already on the dive', (
      tester,
    ) async {
      // The diver dropped the second stage from this one dive and wants it
      // back; the assembly row on the dive cannot bring it.
      await _pump(
        tester,
        all: const [_reg, _first, _second, _bcd],
        selectedIds: {'reg', 'first'},
      );

      expect(find.text('Primary Second Stage'), findsOneWidget);
      expect(find.text(_showLabel), findsNothing);
    });

    testWidgets('are offered when their assembly is Spare', (tester) async {
      const spareReg = EquipmentItem(
        id: 'reg',
        name: 'Cold Water Reg',
        type: EquipmentType.regulator,
        status: EquipmentStatus.spare,
      );
      await _pump(tester, all: const [spareReg, _first, _second]);

      expect(find.text('Cold Water Reg'), findsNothing);
      expect(find.text('DIN First Stage'), findsOneWidget);
      expect(find.text('Primary Second Stage'), findsOneWidget);
      expect(find.text(_showLabel), findsNothing);
    });

    testWidgets('are offered when their assembly is retired', (tester) async {
      const oldReg = EquipmentItem(
        id: 'reg',
        name: 'Cold Water Reg',
        type: EquipmentType.regulator,
        status: EquipmentStatus.retired,
        isActive: false,
      );
      await _pump(tester, all: const [oldReg, _first, _second]);

      expect(find.text('DIN First Stage'), findsOneWidget);
      expect(find.text(_showLabel), findsNothing);
    });

    testWidgets('stay listed for a caller that does not hide them', (
      tester,
    ) async {
      await _pump(
        tester,
        all: const [_reg, _first, _second],
        hideAssemblyParts: false,
      );

      expect(find.text('DIN First Stage'), findsOneWidget);
      expect(find.text('Primary Second Stage'), findsOneWidget);
      expect(find.text(_showLabel), findsNothing);
    });

    testWidgets('offer no switch when no item is an assembly', (tester) async {
      await _pump(
        tester,
        all: const [_reg, _first, _bcd],
        index: ComponentsIndex.empty,
      );

      expect(find.text('DIN First Stage'), findsOneWidget);
      expect(find.text(_showLabel), findsNothing);
    });

    testWidgets('offer no switch when the diver filter rules them all out', (
      tester,
    ) async {
      await _pump(
        tester,
        all: const [_reg, _first, _second, _bcd],
        filter: const EquipmentPickerFilter(type: EquipmentType.bcd),
      );

      expect(find.text(_showLabel), findsNothing);
    });

    testWidgets('an empty list says the rest is components, not missing', (
      tester,
    ) async {
      await _pump(
        tester,
        all: const [_reg, _first, _second],
        filter: const EquipmentPickerFilter(type: EquipmentType.firstStage),
      );

      expect(
        find.text('Remaining gear is part of an assembly'),
        findsOneWidget,
      );
      expect(find.text('No equipment in this category'), findsNothing);
      expect(find.text(_showLabel), findsOneWidget);

      await _showParts(tester);
      expect(find.text('DIN First Stage'), findsOneWidget);
    });

    testWidgets('a retired part stays listed, since the assembly skips it', (
      tester,
    ) async {
      // The expander attaches only active parts, so picking the reg would
      // not bring this first stage along.
      const oldFirst = EquipmentItem(
        id: 'first',
        name: 'DIN First Stage',
        type: EquipmentType.firstStage,
        status: EquipmentStatus.retired,
        isActive: false,
      );
      await _pump(
        tester,
        all: const [_reg, oldFirst, _second, _bcd],
        offerLeftKit: true,
      );
      await tester.tap(find.text('Show retired and sold gear'));
      await tester.pumpAndSettle();
      await openFoldedGroups(tester);

      expect(find.text('DIN First Stage'), findsOneWidget);
      expect(find.text('Primary Second Stage'), findsNothing);
    });

    testWidgets('a retired sub-assembly hides nothing below it', (
      tester,
    ) async {
      // reg > retired first stage > hose: the expander skips the retired
      // first stage and so never reaches the hose, so picking the reg brings
      // neither, and the hose must stay listed with or without the switch.
      const oldFirst = EquipmentItem(
        id: 'first',
        name: 'DIN First Stage',
        type: EquipmentType.firstStage,
        status: EquipmentStatus.retired,
        isActive: false,
      );
      const hose = EquipmentItem(
        id: 'hose',
        name: 'Braided Hose',
        type: EquipmentType.hose,
      );
      await _pump(
        tester,
        all: const [_reg, oldFirst, hose],
        index: ComponentsIndex.fromRows([
          _edge('reg', 'first'),
          _edge('first', 'hose'),
        ]),
        offerLeftKit: true,
      );
      expect(find.text('Braided Hose'), findsOneWidget);

      await tester.tap(find.text('Show retired and sold gear'));
      await tester.pumpAndSettle();
      await openFoldedGroups(tester);

      expect(find.text('DIN First Stage'), findsOneWidget);
      expect(find.text('Braided Hose'), findsOneWidget);
      expect(find.text(_showLabel), findsNothing);
    });

    testWidgets('a retired assembly listed by the left-kit switch hides none', (
      tester,
    ) async {
      const oldReg = EquipmentItem(
        id: 'reg',
        name: 'Cold Water Reg',
        type: EquipmentType.regulator,
        status: EquipmentStatus.retired,
        isActive: false,
      );
      await _pump(
        tester,
        all: const [oldReg, _first, _second],
        offerLeftKit: true,
      );
      await tester.tap(find.text('Show retired and sold gear'));
      await tester.pumpAndSettle();
      await openFoldedGroups(tester);

      expect(find.text('Cold Water Reg'), findsOneWidget);
      expect(find.text('DIN First Stage'), findsOneWidget);
      expect(find.text('Primary Second Stage'), findsOneWidget);
      expect(find.text(_showLabel), findsNothing);
    });

    testWidgets('a shared part stays when its other assembly is on the dive', (
      tester,
    ) async {
      const stage = EquipmentItem(
        id: 'stage',
        name: 'Stage Reg',
        type: EquipmentType.regulator,
      );
      await _pump(
        tester,
        all: const [_reg, _first, _second, stage],
        index: ComponentsIndex.fromRows([
          _edge('reg', 'first'),
          _edge('reg', 'second'),
          _edge('stage', 'second'),
        ]),
        selectedIds: {'reg', 'first'},
      );

      expect(find.text('Stage Reg'), findsOneWidget);
      expect(find.text('Primary Second Stage'), findsOneWidget);
    });

    testWidgets('an empty list points at the switch before Spare', (
      tester,
    ) async {
      const looseSecond = EquipmentItem(
        id: 'loose',
        name: 'Loose Second Stage',
        type: EquipmentType.secondStage,
        status: EquipmentStatus.spare,
      );
      await _pump(
        tester,
        all: const [_reg, _first, _second, looseSecond],
        filter: const EquipmentPickerFilter(type: EquipmentType.secondStage),
      );

      expect(
        find.text('Remaining gear is part of an assembly'),
        findsOneWidget,
      );
      expect(find.text('Remaining gear is marked Spare'), findsNothing);
      expect(
        find.text('Set an item\'s status to Active to add it to a dive'),
        findsNothing,
      );
      expect(find.text(_showLabel), findsOneWidget);
    });

    testWidgets('an empty list blames components only if one matches', (
      tester,
    ) async {
      // Every first stage is a component, but none is retired, so the switch
      // could not bring a row back under this filter and the message must
      // not point at it.
      await _pump(
        tester,
        all: const [_reg, _first, _second],
        filter: const EquipmentPickerFilter(
          type: EquipmentType.firstStage,
          status: EquipmentStatus.retired,
        ),
      );

      expect(find.text('DIN First Stage'), findsNothing);
      expect(find.text('Remaining gear is part of an assembly'), findsNothing);
      expect(find.text(_showLabel), findsNothing);
    });

    testWidgets('the filter sheet offers no chip only components match', (
      tester,
    ) async {
      await _pump(tester, all: const [_reg, _first, _second, _bcd]);
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ChoiceChip, 'Regulator'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'First Stage'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Second Stage'), findsNothing);
    });

    testWidgets('the switch is off again when the sheet reopens', (
      tester,
    ) async {
      final sheetOpen = ValueNotifier(true);
      addTearDown(sheetOpen.dispose);
      await _pump(
        tester,
        all: const [_reg, _first, _second, _bcd],
        sheetOpen: sheetOpen,
      );
      await _showParts(tester);
      expect(find.text('DIN First Stage'), findsOneWidget);

      sheetOpen.value = false;
      await tester.pumpAndSettle();
      sheetOpen.value = true;
      await tester.pumpAndSettle();

      expect(find.text('DIN First Stage'), findsNothing);
      expect(find.text(_showLabel), findsOneWidget);
    });
  });
}
