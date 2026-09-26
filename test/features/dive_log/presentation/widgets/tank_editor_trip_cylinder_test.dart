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
  testWidgets('an edit keeps the trip cylinder link', (tester) async {
    DiveTank? changed;
    await _pump(
      tester,
      equipment: const [_apeks],
      tank: const DiveTank(id: 'tank-1', tripCylinderId: 'slot-1'),
      onChanged: (t) => changed = t,
    );

    // Any edit rebuilds the tank field by field; picking a regulator is the
    // one edit this editor already has a keyed control for.
    await _openRegulatorPicker(tester);
    await tester.tap(find.text('Apeks XTX').last);
    await tester.pumpAndSettle();

    expect(changed?.regulatorEquipmentId, 'reg-a');
    expect(changed?.tripCylinderId, 'slot-1');
  });
}
