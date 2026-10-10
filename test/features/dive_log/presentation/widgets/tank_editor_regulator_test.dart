import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _PresetListNotifier
    extends StateNotifier<AsyncValue<List<TankPresetEntity>>>
    implements TankPresetListNotifier {
  _PresetListNotifier(List<TankPresetEntity> presets)
    : super(AsyncValue.data(presets));

  @override
  Future<void> refresh() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const _apeks = EquipmentItem(
  id: 'reg-a',
  name: 'Apeks XTX',
  type: EquipmentType.regulator,
);

const _spareReg = EquipmentItem(
  id: 'reg-spare',
  name: 'Spare Octo',
  type: EquipmentType.regulator,
  status: EquipmentStatus.spare,
);

/// Bumped to make the overridden active-equipment list reload, the way a
/// dependency change (such as the current diver) reloads the real one. The
/// reload never finishes, so the editor is caught mid-reload.
final _reload = StateProvider<int>((ref) => 0);

Future<void> _pump(
  WidgetTester tester, {
  required List<EquipmentItem> equipment,
  DiveTank tank = const DiveTank(id: 'tank-1'),
  void Function(DiveTank)? onChanged,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final builtInPresets = TankPresets.all
      .map((p) => TankPresetEntity.fromBuiltIn(p))
      .toList();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        tankPresetListNotifierProvider.overrideWith(
          (ref) => _PresetListNotifier(builtInPresets),
        ),
        tankPresetsProvider.overrideWith((ref) => Future.value(builtInPresets)),
        activeEquipmentProvider.overrideWith((ref) async {
          if (ref.watch(_reload) > 0) await Completer<void>().future;
          return equipment;
        }),
      ].cast(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TankEditor(
              tank: tank,
              tankNumber: 1,
              onChanged: onChanged ?? (_) {},
              onRemove: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openRegulatorPicker(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('tank-regulator-picker')));
  await tester.tap(find.byKey(const Key('tank-regulator-picker')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('choosing a regulator reports it on the tank', (tester) async {
    DiveTank? changed;
    await _pump(
      tester,
      equipment: const [
        _apeks,
        EquipmentItem(id: 'mask', name: 'Mask', type: EquipmentType.mask),
      ],
      onChanged: (t) => changed = t,
    );

    await _openRegulatorPicker(tester);
    expect(find.text('Mask').hitTestable(), findsNothing);
    await tester.tap(find.text('Apeks XTX').hitTestable());
    await tester.pumpAndSettle();

    expect(changed?.regulatorEquipmentId, 'reg-a');
  });

  group('spare regulators (#1803)', () {
    testWidgets('are not offered for a tank that does not use one', (
      tester,
    ) async {
      await _pump(tester, equipment: const [_apeks, _spareReg]);

      await _openRegulatorPicker(tester);

      expect(find.text('Apeks XTX').hitTestable(), findsOneWidget);
      expect(find.text('Spare Octo').hitTestable(), findsNothing);
    });

    testWidgets('stay shown on a tank already breathing from one', (
      tester,
    ) async {
      // Marking a regulator Spare must not make an existing dive's tank read
      // "None" for a regulator it really used.
      await _pump(
        tester,
        equipment: const [_apeks, _spareReg],
        tank: const DiveTank(id: 'tank-1', regulatorEquipmentId: 'reg-spare'),
      );

      expect(find.text('Spare Octo'), findsOneWidget);
      expect(find.text('None'), findsNothing);
    });

    testWidgets('stay shown while the equipment list reloads', (tester) async {
      // A reload keeps the previous list available. Dropping it for the
      // loading state would read "None" for the tank's own regulator.
      await _pump(
        tester,
        equipment: const [_apeks, _spareReg],
        tank: const DiveTank(id: 'tank-1', regulatorEquipmentId: 'reg-spare'),
      );

      ProviderScope.containerOf(
        tester.element(find.byType(TankEditor)),
      ).read(_reload.notifier).state++;
      await tester.pump();

      expect(find.text('Spare Octo'), findsOneWidget);
      expect(find.text('None'), findsNothing);
    });
  });

  group('regulators with the same name (#3191)', () {
    EquipmentItem xtx(String id, String identifier) => EquipmentItem(
      id: id,
      name: 'Apeks XTX',
      type: EquipmentType.regulator,
      attributes: [
        EquipmentAttribute.curated(
          equipmentId: id,
          key: EquipmentAttrKeys.identifier,
          valueText: identifier,
        ),
      ],
    );

    testWidgets('are told apart by their ID in the picker', (tester) async {
      DiveTank? changed;
      await _pump(
        tester,
        equipment: [xtx('reg-1', 'Left'), xtx('reg-2', 'Right')],
        onChanged: (t) => changed = t,
      );

      await _openRegulatorPicker(tester);
      expect(
        find.textContaining('ID Left', findRichText: true).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(
        find.textContaining('ID Right', findRichText: true).hitTestable(),
      );
      await tester.pumpAndSettle();

      expect(changed?.regulatorEquipmentId, 'reg-2');
    });

    testWidgets('show the chosen one\'s ID in the closed field', (
      tester,
    ) async {
      await _pump(
        tester,
        equipment: [xtx('reg-1', 'Left'), xtx('reg-2', 'Right')],
        tank: const DiveTank(id: 'tank-1', regulatorEquipmentId: 'reg-2'),
      );

      expect(
        find.textContaining('ID Right', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('ID Left', findRichText: true), findsNothing);
    });

    testWidgets('lead with the ID, ahead of brand and model', (tester) async {
      // A cut-off label loses its end first; the ID is what tells these two
      // apart, so it must not be the part that goes.
      final withModel = xtx(
        'reg-2',
        'Right',
      ).copyWith(brand: 'Apeks', model: 'XTX50 Tungsten');
      await _pump(
        tester,
        equipment: [xtx('reg-1', 'Left'), withModel],
        tank: const DiveTank(id: 'tank-1', regulatorEquipmentId: 'reg-2'),
      );

      final label = tester
          .widget<RichText>(
            find.textContaining('ID Right', findRichText: true).first,
          )
          .text
          .toPlainText();
      expect(
        label.indexOf('ID Right'),
        lessThan(label.indexOf('Apeks XTX50 Tungsten')),
      );
    });
  });
}
