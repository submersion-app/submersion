import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_picker_filter.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

const _bcd = EquipmentItem(
  id: 'bcd',
  name: 'Hydros BCD',
  type: EquipmentType.bcd,
);

const _oldReg = EquipmentItem(
  id: 'old-reg',
  name: 'Old Reg',
  type: EquipmentType.regulator,
  status: EquipmentStatus.retired,
  isActive: false,
);

const _soldFins = EquipmentItem(
  id: 'sold-fins',
  name: 'Sold Fins',
  type: EquipmentType.fins,
  status: EquipmentStatus.sold,
  isActive: false,
);

const _wantedLight = EquipmentItem(
  id: 'wanted-light',
  name: 'Wanted Light',
  type: EquipmentType.light,
  status: EquipmentStatus.wanted,
  isActive: false,
);

const _oldTank = EquipmentItem(
  id: 'old-tank',
  name: 'Old Tank',
  type: EquipmentType.tank,
  status: EquipmentStatus.retired,
  isActive: false,
);

const _showLabel = 'Show retired and sold gear';

/// [all] is every row the diver can see, as the repository's unfiltered
/// query returns it; the active list is derived the way the repository's
/// active query narrows it.
Future<void> _pump(
  WidgetTester tester, {
  required List<EquipmentItem> all,
  bool offerLeftKit = true,
  EquipmentType? typeFilter,
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
            typeFilter: typeFilter,
            hideSpare: true,
            offerLeftKit: offerLeftKit,
            onEquipmentSelected: onSelected ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _showLeftKit(WidgetTester tester) async {
  await tester.tap(find.text(_showLabel));
  await tester.pumpAndSettle();
}

void main() {
  group('gear that has left the kit (#3210)', () {
    testWidgets('is hidden until the diver asks for it', (tester) async {
      await _pump(tester, all: const [_bcd, _oldReg, _soldFins]);

      expect(find.text('Hydros BCD'), findsOneWidget);
      expect(find.text('Old Reg'), findsNothing);
      expect(find.text('Sold Fins'), findsNothing);
      expect(find.text(_showLabel), findsOneWidget);
    });

    testWidgets('is listed with its status once shown', (tester) async {
      await _pump(tester, all: const [_bcd, _oldReg, _soldFins]);
      await _showLeftKit(tester);

      expect(find.text('Hydros BCD'), findsOneWidget);
      expect(find.text('Old Reg'), findsOneWidget);
      expect(find.text('Sold Fins'), findsOneWidget);
      expect(find.textContaining('Retired'), findsOneWidget);
      expect(find.textContaining('Sold'), findsWidgets);
    });

    testWidgets('can be picked for the dive once shown', (tester) async {
      EquipmentItem? picked;
      await _pump(
        tester,
        all: const [_bcd, _oldReg],
        onSelected: (e) => picked = e,
      );
      await _showLeftKit(tester);

      await tester.tap(find.text('Old Reg'));
      expect(picked?.id, 'old-reg');
    });

    testWidgets('never brings in wishlist gear, which was never owned', (
      tester,
    ) async {
      await _pump(tester, all: const [_bcd, _oldReg, _wantedLight]);
      await _showLeftKit(tester);

      expect(find.text('Wanted Light'), findsNothing);
    });

    testWidgets('is not offered by pickers for future dives', (tester) async {
      await _pump(tester, all: const [_bcd, _oldReg], offerLeftKit: false);

      expect(find.text(_showLabel), findsNothing);
      expect(find.text('Old Reg'), findsNothing);
    });

    testWidgets('offers no switch when no such gear exists', (tester) async {
      await _pump(tester, all: const [_bcd]);

      expect(find.text(_showLabel), findsNothing);
    });

    testWidgets('offers no switch when none of it fits the type filter', (
      tester,
    ) async {
      await _pump(tester, all: const [_oldReg], typeFilter: EquipmentType.tank);

      expect(find.text(_showLabel), findsNothing);
    });

    testWidgets('a type-filtered picker shows a retired cylinder', (
      tester,
    ) async {
      await _pump(
        tester,
        all: const [_oldTank, _oldReg],
        typeFilter: EquipmentType.tank,
      );
      await _showLeftKit(tester);

      expect(find.text('Old Tank'), findsOneWidget);
      expect(find.text('Old Reg'), findsNothing);
    });

    testWidgets('an empty list points at the switch, not the Equipment tab', (
      tester,
    ) async {
      await _pump(tester, all: const [_oldReg]);

      expect(find.text(_showLabel), findsOneWidget);
      expect(find.text('Add equipment from the Equipment tab'), findsNothing);
    });

    testWidgets('inactive lost gear keeps its Lost label', (tester) async {
      // Lost gear can be inactive too; it is gone, not retired.
      const lostMask = EquipmentItem(
        id: 'lost-mask',
        name: 'Lost Mask',
        type: EquipmentType.mask,
        status: EquipmentStatus.lost,
        isActive: false,
      );
      await _pump(tester, all: const [_bcd, lostMask]);
      await _showLeftKit(tester);

      expect(find.text('Lost Mask'), findsOneWidget);
      expect(find.text('Lost'), findsOneWidget);
      expect(find.textContaining('Retired'), findsNothing);
    });

    testWidgets('offers no switch when the diver filter rules it all out', (
      tester,
    ) async {
      await _pump(
        tester,
        all: const [_bcd, _oldReg],
        filter: const EquipmentPickerFilter(type: EquipmentType.bcd),
      );

      expect(find.text(_showLabel), findsNothing);
    });

    testWidgets('offers the switch when the diver filter keeps some', (
      tester,
    ) async {
      await _pump(
        tester,
        all: const [_bcd, _oldReg],
        filter: const EquipmentPickerFilter(type: EquipmentType.regulator),
      );

      expect(find.text(_showLabel), findsOneWidget);
    });

    testWidgets('a Retired filter finds a legacy row retired by isActive', (
      tester,
    ) async {
      const legacy = EquipmentItem(
        id: 'legacy',
        name: 'Legacy Reg',
        type: EquipmentType.regulator,
        isActive: false,
      );
      await _pump(
        tester,
        all: const [_bcd, legacy],
        filter: const EquipmentPickerFilter(status: EquipmentStatus.retired),
      );
      await _showLeftKit(tester);

      expect(find.text('Legacy Reg'), findsOneWidget);
      expect(find.text('Retired'), findsOneWidget);
    });

    testWidgets('leaves out gear already on the dive', (tester) async {
      await _pump(tester, all: const [_bcd, _oldReg], selectedIds: {'old-reg'});

      expect(find.text(_showLabel), findsNothing);
    });
  });
}
