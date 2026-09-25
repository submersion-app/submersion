import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/domain/gas_limits.dart';
import 'package:submersion/features/gas_calculators/domain/mod_calculator_preferences.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/mod_calculator_providers.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class _FakeRepository extends AppSettingsRepository {
  _FakeRepository([this.stored]);

  String? stored;
  final writes = <String>[];
  Completer<void>? readGate;

  @override
  Future<String?> getRawSetting(String key) async {
    await readGate?.future;
    return key == modCalculatorPrefsKey ? stored : null;
  }

  @override
  Future<void> setRawSetting(String key, String value) async {
    writes.add(value);
    stored = value;
  }
}

class _FixedSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FixedSettings(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container(
  _FakeRepository repo, {
  AppSettings settings = const AppSettings(),
}) {
  final container = ProviderContainer(
    overrides: [
      appSettingsRepositoryProvider.overrideWithValue(repo),
      settingsProvider.overrideWith((ref) => _FixedSettings(settings)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('ModCalculatorNotifier', () {
    test('restores the stored preferences', () async {
      final stored = ModCalculatorPreferences.defaults.copyWith(
        mode: ModCalculatorMode.ocTec,
        workingPpO2: 1.3,
      );
      final repo = _FakeRepository(jsonEncode(stored.toJson()));
      final container = _container(repo);
      container.read(modCalculatorNotifierProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(modCalculatorNotifierProvider), stored);
    });

    test('keeps the defaults when nothing or garbage is stored', () async {
      for (final raw in [null, 'not json', '[1, 2]']) {
        final container = _container(_FakeRepository(raw));
        container.read(modCalculatorNotifierProvider);
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(modCalculatorNotifierProvider),
          ModCalculatorPreferences.defaults,
        );
      }
    });

    test('a late load never overwrites an edit made meanwhile', () async {
      final repo = _FakeRepository(
        jsonEncode(
          ModCalculatorPreferences.defaults
              .copyWith(mode: ModCalculatorMode.ccrTec)
              .toJson(),
        ),
      )..readGate = Completer<void>();
      final container = _container(repo);
      container
          .read(modCalculatorNotifierProvider.notifier)
          .setMode(ModCalculatorMode.ocTec);
      repo.readGate!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(modCalculatorNotifierProvider).mode,
        ModCalculatorMode.ocTec,
      );
    });

    test('saves once after a burst of changes settles', () {
      fakeAsync((async) {
        final repo = _FakeRepository();
        final container = _container(repo);
        final notifier = container.read(modCalculatorNotifierProvider.notifier);
        for (final o2 in [33.0, 34.0, 35.0, 36.0]) {
          notifier.setO2Percent(o2);
          async.elapse(const Duration(milliseconds: 100));
        }
        expect(repo.writes, isEmpty);
        async.elapse(ModCalculatorNotifier.saveDelay);
        expect(repo.writes, hasLength(1));
        final saved = ModCalculatorPreferences.fromJson(
          jsonDecode(repo.writes.single) as Map<String, dynamic>,
        );
        expect(saved.rec.o2Percent, 36);
      });
    });

    test('each mode keeps its own mix', () {
      final container = _container(_FakeRepository());
      final notifier = container.read(modCalculatorNotifierProvider.notifier)
        ..setO2Percent(36)
        ..setMode(ModCalculatorMode.ocTec)
        ..setO2Percent(18)
        ..setHePercent(45);
      expect(container.read(modCalculatorNotifierProvider).rec.o2Percent, 36);
      notifier.setMode(ModCalculatorMode.rec);
      final prefs = container.read(modCalculatorNotifierProvider);
      expect(prefs.inputsFor(prefs.mode).o2Percent, 36);
      expect(prefs.ocTec.o2Percent, 18);
      expect(prefs.ocTec.hePercent, 45);
    });

    test('raising O2 pulls helium into the room left', () {
      final container = _container(_FakeRepository());
      container.read(modCalculatorNotifierProvider.notifier)
        ..setMode(ModCalculatorMode.ocTec)
        ..setHePercent(70)
        ..setO2Percent(40);
      expect(container.read(modCalculatorNotifierProvider).ocTec.hePercent, 60);
    });

    test('an override equal to the profile value follows the profile', () {
      final container = _container(_FakeRepository());
      final notifier = container.read(modCalculatorNotifierProvider.notifier)
        ..setWorkingPpO2(1.3, profileValue: 1.4);
      expect(container.read(modCalculatorNotifierProvider).workingPpO2, 1.3);
      notifier.setWorkingPpO2(1.4, profileValue: 1.4);
      expect(container.read(modCalculatorNotifierProvider).workingPpO2, isNull);
      notifier
        ..setFlushPpO2(1.5, profileValue: 1.6)
        ..resetFlushPpO2();
      expect(container.read(modCalculatorNotifierProvider).flushPpO2, isNull);
    });
  });

  group('modCalculatorInputsProvider', () {
    test('limits come from the profile unless overridden', () {
      const settings = AppSettings(
        ppO2MaxWorking: 1.3,
        ppO2MaxDeco: 1.5,
        endLimit: 35,
        o2Narcotic: false,
      );
      final container = _container(_FakeRepository(), settings: settings);
      var inputs = container.read(modCalculatorInputsProvider);
      expect(inputs.workingPpO2, 1.3);
      expect(inputs.decoPpO2, 1.5);
      expect(inputs.flushPpO2, 1.5);
      expect(inputs.endLimitMeters, 35);
      expect(inputs.o2Narcotic, isFalse);

      container
          .read(modCalculatorNotifierProvider.notifier)
          .setWorkingPpO2(1.2, profileValue: 1.3);
      inputs = container.read(modCalculatorInputsProvider);
      expect(inputs.workingPpO2, 1.2);
    });

    test('the water type defaults to the planner setting', () {
      final fresh = _container(
        _FakeRepository(),
        settings: const AppSettings(
          defaultPlannerWaterType: PlannerWaterType.fresh,
        ),
      );
      expect(
        fresh.read(modCalculatorInputsProvider).waterType,
        WaterType.fresh,
      );

      final custom = _container(
        _FakeRepository(),
        settings: const AppSettings(
          defaultPlannerWaterType: PlannerWaterType.custom,
        ),
      );
      expect(
        custom.read(modCalculatorInputsProvider).waterType,
        WaterType.salt,
      );

      custom
          .read(modCalculatorNotifierProvider.notifier)
          .setWaterType(WaterType.fresh);
      expect(
        custom.read(modCalculatorInputsProvider).waterType,
        WaterType.fresh,
      );
    });

    test('the target depth is only passed on while it is checked', () {
      final container = _container(_FakeRepository());
      expect(
        container.read(modCalculatorInputsProvider).targetDepthMeters,
        isNull,
      );
      container
          .read(modCalculatorNotifierProvider.notifier)
          .setCheckTargetDepth(true);
      expect(container.read(modCalculatorInputsProvider).targetDepthMeters, 30);
    });
  });
}
