import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_role_option.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The dive editor's Role picker shows the glyph each role is drawn with on
/// the dive's Tanks card, so the diver learns the icons where they choose the
/// role (issue #2901).
void main() {
  testWidgets('the role field and every role option carry the role glyph', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final presets = TankPresets.all
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
            (ref) => _Presets(presets),
          ),
          tankPresetsProvider.overrideWith((ref) => Future.value(presets)),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: TankEditor(
                tank: const DiveTank(
                  id: 'tank-1',
                  volume: 12,
                  gasMix: GasMix(o2: 50),
                  role: TankRole.deco,
                ),
                tankNumber: 1,
                onChanged: (_) {},
                onRemove: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.byType(DropdownButtonFormField<TankRole>);
    expect(
      find.descendant(of: field, matching: find.byIcon(TankRole.deco.icon)),
      findsOneWidget,
    );

    await tester.tap(field);
    await tester.pumpAndSettle();

    for (final role in TankRole.values) {
      expect(
        find.descendant(
          of: find.byType(DropdownMenuItem<TankRole>),
          matching: find.byWidgetPredicate(
            (w) => w is TankRoleOption && w.role == role,
          ),
        ),
        findsWidgets,
        reason: role.name,
      );
    }
  });
}

class _Presets extends StateNotifier<AsyncValue<List<TankPresetEntity>>>
    implements TankPresetListNotifier {
  _Presets(List<TankPresetEntity> presets) : super(AsyncValue.data(presets));

  @override
  Future<void> refresh() async {}

  @override
  Future<TankPresetEntity> addPreset(TankPresetEntity preset) async => preset;

  @override
  Future<void> updatePreset(TankPresetEntity preset) async {}

  @override
  Future<void> deletePreset(String id) async {}
}
