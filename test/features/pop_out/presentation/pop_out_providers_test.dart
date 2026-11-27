import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/o2_cell_unit.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/pop_out/presentation/providers/pop_out_providers.dart';
import 'package:submersion/features/settings/presentation/providers/display_zoom_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class _FakeSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FakeSettingsNotifier() : super(const AppSettings());

  void set(AppSettings value) => state = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // The button lives in toolbars every platform shares (#5078); a phone or
  // tablet layout must never make room for it.
  test('pop-outs are offered on desktop platforms only', () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final offered = <TargetPlatform>[];
    for (final platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      final container = ProviderContainer();
      if (container.read(popOutAvailableProvider)) offered.add(platform);
      container.dispose();
    }
    expect(
      offered,
      unorderedEquals([
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]),
    );
  });

  // The main window resends its prefs when this changes. Settings in the
  // diver's row reach the pop-out through the shared database instead, so
  // they must not cause a resend.
  test('the prefs trigger follows the zoom and the device-local profile '
      'settings only', () async {
    SharedPreferences.setMockInitialValues({currentDiverIdKey: 'diver-1'});
    final prefs = await SharedPreferences.getInstance();
    final settings = _FakeSettingsNotifier();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => settings),
        currentDiverIdProvider.overrideWith(
          (ref) => CurrentDiverIdNotifier.readOnly(
            ref.watch(sharedPreferencesProvider),
            ref.watch(diverRepositoryProvider),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(popOutPrefsTriggerProvider, (_, _) {});
    final start = container.read(popOutPrefsTriggerProvider);

    settings.set(settings.state.copyWith(themeMode: ThemeMode.dark));
    expect(container.read(popOutPrefsTriggerProvider), start);

    container.read(displayZoomNotifierProvider.notifier).previewZoom(1.25);
    final zoomed = container.read(popOutPrefsTriggerProvider);
    expect(zoomed, isNot(start));

    settings.set(settings.state.copyWith(o2CellUnit: O2CellUnit.millivolts));
    expect(container.read(popOutPrefsTriggerProvider), isNot(zoomed));
  });
}
