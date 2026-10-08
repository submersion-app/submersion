import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gas_calculators/domain/gas_limits.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/gas_calculators/domain/mod_calculator_preferences.dart';
import 'package:submersion/features/gas_calculators/domain/mod_limit_overrides.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/mod_calculator_providers.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/mock_providers.dart';

class _FakeRepository extends AppSettingsRepository {
  _FakeRepository([this.stored]);

  String? stored;
  final writes = <String>[];
  Completer<void>? readGate;
  final ticks = StreamController<void>.broadcast();

  @override
  Stream<void> watchSettingsChanges() => ticks.stream;

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
      currentDiverIdProvider.overrideWith(
        (ref) => MockCurrentDiverIdNotifier()..state = 'diver-a',
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('ModCalculatorNotifier', () {
    test('restores the stored preferences', () async {
      final stored = ModCalculatorPreferences.defaults
          .copyWith(mode: ModCalculatorMode.ocTec)
          .withOverrides('diver-a', const ModLimitOverrides(workingPpO2: 1.3));
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
      ModLimitOverrides overrides() =>
          container.read(modCalculatorNotifierProvider).overridesFor('diver-a');
      final notifier = container.read(modCalculatorNotifierProvider.notifier)
        ..setWorkingPpO2(1.3);
      expect(overrides().workingPpO2, 1.3);
      notifier.setWorkingPpO2(1.4);
      expect(overrides().workingPpO2, isNull);
      notifier
        ..setFlushPpO2(1.5)
        ..resetFlushPpO2();
      expect(overrides().flushPpO2, isNull);
    });

    test('overrides belong to the active diver', () async {
      final container = _container(_FakeRepository());
      container.read(modCalculatorNotifierProvider.notifier)
        ..setWorkingPpO2(1.2)
        ..setSetpoint(1.0);
      expect(container.read(modCalculatorLimitsProvider).workingPpO2, 1.2);

      await container
          .read(currentDiverIdProvider.notifier)
          .setCurrentDiver('diver-b');
      final limits = container.read(modCalculatorLimitsProvider);
      expect(limits.workingPpO2, 1.4, reason: 'diver-b follows the profile');
      expect(limits.setpointBar, 1.3);
      expect(limits.workingOverridden, isFalse);
    });

    test('raising working pulls deco up; lowering deco pulls working down', () {
      final container = _container(_FakeRepository());
      ModResolvedLimits limits() => container.read(modCalculatorLimitsProvider);
      final notifier = container.read(modCalculatorNotifierProvider.notifier)
        ..setDecoPpO2(1.5)
        ..setWorkingPpO2(1.6);
      expect(limits().workingPpO2, 1.6);
      expect(limits().decoPpO2, 1.6);

      notifier.setDecoPpO2(1.2);
      expect(limits().decoPpO2, 1.2);
      expect(limits().workingPpO2, 1.2);
      expect(
        container.read(modCalculatorInputsProvider).decoPpO2,
        greaterThanOrEqualTo(
          container.read(modCalculatorInputsProvider).workingPpO2,
        ),
      );

      // Back to the profile deco (1.6) keeps working where it is.
      notifier.resetDecoPpO2();
      expect(limits().decoPpO2, 1.6);
      expect(limits().workingPpO2, 1.2);
    });

    test(
      'a change synced from another device reaches the open calculator',
      () async {
        final repo = _FakeRepository();
        final container = _container(repo);
        container.read(modCalculatorNotifierProvider);
        await Future<void>.delayed(Duration.zero);

        repo.stored = jsonEncode(
          ModCalculatorPreferences.defaults
              .copyWith(mode: ModCalculatorMode.ccrTec)
              .toJson(),
        );
        repo.ticks.add(null);
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(modCalculatorNotifierProvider).mode,
          ModCalculatorMode.ccrTec,
        );
      },
    );

    test('a sync tick never overwrites an edit not yet saved', () {
      fakeAsync((async) {
        final repo = _FakeRepository(
          jsonEncode(
            ModCalculatorPreferences.defaults
                .copyWith(mode: ModCalculatorMode.ccrTec)
                .toJson(),
          ),
        );
        final container = _container(repo);
        container.read(modCalculatorNotifierProvider);
        async.flushMicrotasks();
        container
            .read(modCalculatorNotifierProvider.notifier)
            .setMode(ModCalculatorMode.ocTec);
        repo.ticks.add(null);
        async.flushMicrotasks();
        expect(
          container.read(modCalculatorNotifierProvider).mode,
          ModCalculatorMode.ocTec,
        );
        async.elapse(ModCalculatorNotifier.saveDelay);
        expect(repo.writes, hasLength(1));
      });
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
      // The diluent MOD comes from the CCR limits (default 1.6), not deco.
      expect(inputs.flushPpO2, 1.6);
      expect(inputs.endLimitMeters, 35);
      expect(inputs.o2Narcotic, isFalse);

      container
          .read(modCalculatorNotifierProvider.notifier)
          .setWorkingPpO2(1.2);
      inputs = container.read(modCalculatorInputsProvider);
      expect(inputs.workingPpO2, 1.2);
    });

    test('CCR Tec starts from the profile CCR ppO2 limits (#2342)', () {
      const settings = AppSettings(
        ppO2MaxDeco: 1.5,
        ccrSetpointHigh: 1.2,
        ccrDiluentModPpO2: 1.45,
      );
      final container = _container(_FakeRepository(), settings: settings);
      var inputs = container.read(modCalculatorInputsProvider);
      expect(inputs.setpointBar, 1.2);
      // The diluent MOD follows the CCR profile, no longer the OC deco value.
      expect(inputs.flushPpO2, 1.45);

      ModLimitOverrides overrides() =>
          container.read(modCalculatorNotifierProvider).overridesFor('diver-a');
      final notifier = container.read(modCalculatorNotifierProvider.notifier)
        ..setSetpoint(1.0);
      inputs = container.read(modCalculatorInputsProvider);
      expect(inputs.setpointBar, 1.0);
      expect(overrides().setpointBar, 1.0);

      notifier.setSetpoint(1.2);
      expect(overrides().setpointBar, isNull);
    });

    test('a profile value outside the calculator range is held to it', () {
      const settings = AppSettings(
        ccrSetpointHigh: 0.3,
        ccrDiluentModPpO2: 0.3,
      );
      final container = _container(_FakeRepository(), settings: settings);
      final inputs = container.read(modCalculatorInputsProvider);
      expect(inputs.setpointBar, modSetpointMinBar);
      expect(inputs.flushPpO2, modFlushPpO2Min);
    });

    test('a low Dil MOD from the profile is never raised (safe side)', () {
      // 0.9 is a valid profile value; raising it to 1.0 would show a deeper
      // diluent MOD than the diver allows.
      const settings = AppSettings(ccrDiluentModPpO2: 0.9);
      final container = _container(_FakeRepository(), settings: settings);
      expect(container.read(modCalculatorInputsProvider).flushPpO2, 0.9);
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
