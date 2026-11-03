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
  Set<String> selectedIds = const {},
  EquipmentPickerFilter filter = EquipmentPickerFilter.none,
  void Function(EquipmentItem)? onSelected,
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
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
        home: Scaffold(
          body: EquipmentPickerSheet(
            scrollController: ScrollController(),
            selectedEquipmentIds: selectedIds,
            hideSpare: true,
            hideAssemblyParts: hideAssemblyParts,
            onEquipmentSelected: onSelected ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _showParts(WidgetTester tester) async {
  await tester.tap(find.text(_showLabel));
  await tester.pumpAndSettle();
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
  });
}
