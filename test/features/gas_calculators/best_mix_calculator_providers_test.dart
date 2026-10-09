import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/gas_calculators/domain/best_mix.dart';
import 'package:submersion/features/gas_calculators/domain/best_mix_calculator_preferences.dart';
import 'package:submersion/features/gas_calculators/domain/gas_density_calculator.dart';
import 'package:submersion/features/gas_calculators/domain/mod_limit_overrides.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/best_mix_calculator_providers.dart';
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
    return key == bestMixCalculatorPrefsKey ? stored : null;
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
  group('BestMixCalculatorNotifier', () {
    test('restores the stored preferences', () async {
      final stored = BestMixCalculatorPreferences.defaults
          .copyWith(mode: BestMixMode.ocTec)
          .withOverrides('diver-a', const ModLimitOverrides(workingPpO2: 1.3));
      final repo = _FakeRepository(jsonEncode(stored.toJson()));
      final container = _container(repo);
      container.read(bestMixCalculatorNotifierProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(bestMixCalculatorNotifierProvider), stored);
    });

    test('keeps the defaults when nothing or garbage is stored', () async {
      for (final raw in [null, 'not json', '[1, 2]']) {
        final container = _container(_FakeRepository(raw));
        container.read(bestMixCalculatorNotifierProvider);
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(bestMixCalculatorNotifierProvider),
          BestMixCalculatorPreferences.defaults,
        );
      }
    });

    test('a late load never overwrites an edit made meanwhile', () async {
      final repo = _FakeRepository(
        jsonEncode(
          BestMixCalculatorPreferences.defaults
              .copyWith(mode: BestMixMode.ccrTec)
              .toJson(),
        ),
      )..readGate = Completer<void>();
      final container = _container(repo);
      container
          .read(bestMixCalculatorNotifierProvider.notifier)
          .setMode(BestMixMode.ocTec);
      repo.readGate!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(bestMixCalculatorNotifierProvider).mode,
        BestMixMode.ocTec,
      );
    });

    test('saves once after a burst of changes settles', () {
      fakeAsync((async) {
        final repo = _FakeRepository();
        final container = _container(repo);
        final notifier = container.read(
          bestMixCalculatorNotifierProvider.notifier,
        );
        for (final depth in [40.0, 45.0, 50.0, 55.0]) {
          notifier.setDepth(depth);
          async.elapse(const Duration(milliseconds: 100));
        }
        expect(repo.writes, isEmpty);
        async.elapse(BestMixCalculatorNotifier.saveDelay);
        expect(repo.writes, hasLength(1));
        final saved = BestMixCalculatorPreferences.fromJson(
          jsonDecode(repo.writes.single) as Map<String, dynamic>,
        );
        expect(saved.rec.depthMeters, 55);
      });
    });

    test('each mode keeps its own depth and density switch', () {
      final container = _container(_FakeRepository());
      final notifier =
          container.read(bestMixCalculatorNotifierProvider.notifier)
            ..setDepth(30)
            ..setMode(BestMixMode.ocTec)
            ..setDepth(60)
            ..setDensityAware(true);
      expect(
        container.read(bestMixCalculatorNotifierProvider).rec.depthMeters,
        30,
      );
      notifier.setMode(BestMixMode.rec);
      final prefs = container.read(bestMixCalculatorNotifierProvider);
      expect(prefs.inputsFor(prefs.mode).depthMeters, 30);
      expect(prefs.ocTec.depthMeters, 60);
      expect(prefs.ocTec.densityAware, isTrue);
      expect(prefs.rec.densityAware, isFalse);
    });

    test('setRecPpO2 updates the current mode slot, read only in Rec', () {
      final container = _container(_FakeRepository());
      container
          .read(bestMixCalculatorNotifierProvider.notifier)
          .setRecPpO2(1.6);
      final prefs = container.read(bestMixCalculatorNotifierProvider);
      expect(prefs.rec.recPpO2, 1.6);
      // OC-Tec's slot is untouched: changing it required switching modes
      // first, which the Rec-only UI control never does.
      expect(
        prefs.ocTec.recPpO2,
        BestMixCalculatorPreferences.defaults.ocTec.recPpO2,
      );
    });

    test('setCcrSource, setWaterType and setTemperature are top-level', () {
      final container = _container(_FakeRepository());
      container.read(bestMixCalculatorNotifierProvider.notifier)
        ..setCcrSource(CcrGasSource.bailout)
        ..setWaterType(WaterType.fresh)
        ..setTemperature(GasDensityTemperature.twentyC);
      final prefs = container.read(bestMixCalculatorNotifierProvider);
      expect(prefs.ccrSource, CcrGasSource.bailout);
      expect(prefs.waterType, WaterType.fresh);
      expect(prefs.temperature, GasDensityTemperature.twentyC);
    });

    test('an override equal to the profile value follows the profile', () {
      final container = _container(_FakeRepository());
      ModLimitOverrides overrides() => container
          .read(bestMixCalculatorNotifierProvider)
          .overridesFor('diver-a');
      final notifier = container.read(
        bestMixCalculatorNotifierProvider.notifier,
      )..setWorkingPpO2(1.3);
      expect(overrides().workingPpO2, 1.3);
      notifier.resetWorkingPpO2();
      expect(overrides().workingPpO2, isNull);
      notifier
        ..setFlushPpO2(1.5)
        ..resetFlushPpO2();
      expect(overrides().flushPpO2, isNull);

      notifier
        ..setEndLimit(24)
        ..resetEndLimit();
      expect(overrides().endLimitMeters, isNull);

      notifier
        ..setO2Narcotic(false)
        ..resetO2Narcotic();
      expect(overrides().o2Narcotic, isNull);
    });

    test(
      'overrides belong to the active diver, independent of the MOD calculator',
      () async {
        final container = _container(_FakeRepository());
        container
            .read(bestMixCalculatorNotifierProvider.notifier)
            .setWorkingPpO2(1.2);
        expect(
          container.read(bestMixCalculatorLimitsProvider).workingPpO2,
          1.2,
        );

        await container
            .read(currentDiverIdProvider.notifier)
            .setCurrentDiver('diver-b');
        final limits = container.read(bestMixCalculatorLimitsProvider);
        expect(limits.workingPpO2, 1.4, reason: 'diver-b follows the profile');
        expect(limits.workingOverridden, isFalse);
      },
    );

    test(
      'a change synced from another device reaches the open calculator',
      () async {
        final repo = _FakeRepository();
        final container = _container(repo);
        container.read(bestMixCalculatorNotifierProvider);
        await Future<void>.delayed(Duration.zero);

        repo.stored = jsonEncode(
          BestMixCalculatorPreferences.defaults
              .copyWith(mode: BestMixMode.ccrTec)
              .toJson(),
        );
        repo.ticks.add(null);
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(bestMixCalculatorNotifierProvider).mode,
          BestMixMode.ccrTec,
        );
      },
    );

    test('a sync tick never overwrites an edit not yet saved', () {
      fakeAsync((async) {
        final repo = _FakeRepository(
          jsonEncode(
            BestMixCalculatorPreferences.defaults
                .copyWith(mode: BestMixMode.ccrTec)
                .toJson(),
          ),
        );
        final container = _container(repo);
        container.read(bestMixCalculatorNotifierProvider);
        async.flushMicrotasks();
        container
            .read(bestMixCalculatorNotifierProvider.notifier)
            .setMode(BestMixMode.ocTec);
        repo.ticks.add(null);
        async.flushMicrotasks();
        expect(
          container.read(bestMixCalculatorNotifierProvider).mode,
          BestMixMode.ocTec,
        );
        async.elapse(BestMixCalculatorNotifier.saveDelay);
        expect(repo.writes, hasLength(1));
      });
    });

    test('reset returns to defaults', () {
      final container = _container(_FakeRepository());
      container.read(bestMixCalculatorNotifierProvider.notifier)
        ..setMode(BestMixMode.ccrTec)
        ..setWorkingPpO2(1.2)
        ..reset();
      expect(
        container.read(bestMixCalculatorNotifierProvider),
        BestMixCalculatorPreferences.defaults,
      );
    });

    test('a pending save still goes out when the notifier is disposed', () {
      fakeAsync((async) {
        final repo = _FakeRepository();
        final container = ProviderContainer(
          overrides: [
            appSettingsRepositoryProvider.overrideWithValue(repo),
            settingsProvider.overrideWith(
              (ref) => _FixedSettings(const AppSettings()),
            ),
            currentDiverIdProvider.overrideWith(
              (ref) => MockCurrentDiverIdNotifier()..state = 'diver-a',
            ),
          ],
        );
        container.read(bestMixCalculatorNotifierProvider.notifier).setDepth(42);
        container.dispose();
        async.flushMicrotasks();
        expect(repo.writes, hasLength(1));
      });
    });
  });

  group('bestMixCalculatorInputsProvider', () {
    test('Rec uses the stored chip, Tec uses the resolved working ppO2', () {
      const settings = AppSettings(ppO2MaxWorking: 1.3, endLimit: 35);
      final container = _container(_FakeRepository(), settings: settings);
      final notifier = container.read(
        bestMixCalculatorNotifierProvider.notifier,
      )..setRecPpO2(1.6);
      expect(container.read(bestMixCalculatorInputsProvider).ppO2Limit, 1.6);

      notifier.setMode(BestMixMode.ocTec);
      expect(container.read(bestMixCalculatorInputsProvider).ppO2Limit, 1.3);
      expect(
        container.read(bestMixCalculatorInputsProvider).endLimitMeters,
        35,
      );
    });

    test('CCR Tec always carries the resolved flush ppO2', () {
      const settings = AppSettings(ccrDiluentModPpO2: 1.45);
      final container = _container(_FakeRepository(), settings: settings);
      container
          .read(bestMixCalculatorNotifierProvider.notifier)
          .setMode(BestMixMode.ccrTec);
      expect(container.read(bestMixCalculatorInputsProvider).flushPpO2, 1.45);
    });

    test(
      'CCR Tec Bailout uses the deco (maximum) ppO2, not the working one',
      () {
        const settings = AppSettings(ppO2MaxWorking: 1.3, ppO2MaxDeco: 1.55);
        final container = _container(_FakeRepository(), settings: settings);
        container.read(bestMixCalculatorNotifierProvider.notifier)
          ..setMode(BestMixMode.ccrTec)
          ..setCcrSource(CcrGasSource.bailout);
        expect(container.read(bestMixCalculatorInputsProvider).ppO2Limit, 1.55);
      },
    );

    test(
      'setDecoPpO2/setWorkingPpO2 never invert, shared across OC-Tec and CCR Bailout',
      () {
        final container = _container(_FakeRepository());
        final notifier = container.read(
          bestMixCalculatorNotifierProvider.notifier,
        );
        ModResolvedLimits limits() =>
            container.read(bestMixCalculatorLimitsProvider);

        notifier
          ..setMode(BestMixMode.ccrTec)
          ..setCcrSource(CcrGasSource.bailout)
          ..setDecoPpO2(1.2); // below the default working ppO2 (1.4)
        expect(limits().decoPpO2, 1.2);
        expect(
          limits().workingPpO2,
          1.2,
          reason: 'working pulled down with it',
        );

        notifier
          ..setMode(BestMixMode.ocTec)
          ..setWorkingPpO2(1.6); // above the deco override just set
        expect(limits().workingPpO2, 1.6);
        expect(limits().decoPpO2, 1.6, reason: 'deco pulled up with it');
      },
    );

    test('the water type defaults to the planner setting', () {
      final fresh = _container(
        _FakeRepository(),
        settings: const AppSettings(
          defaultPlannerWaterType: PlannerWaterType.fresh,
        ),
      );
      expect(
        fresh.read(bestMixCalculatorInputsProvider).waterType,
        WaterType.fresh,
      );

      fresh
          .read(bestMixCalculatorNotifierProvider.notifier)
          .setWaterType(WaterType.salt);
      expect(
        fresh.read(bestMixCalculatorInputsProvider).waterType,
        WaterType.salt,
      );
    });

    test(
      'densityAware and temperature flow through from the current mode slot',
      () {
        final container = _container(_FakeRepository());
        container.read(bestMixCalculatorNotifierProvider.notifier)
          ..setMode(BestMixMode.ocTec)
          ..setDensityAware(true)
          ..setTemperature(GasDensityTemperature.twentyC);
        final inputs = container.read(bestMixCalculatorInputsProvider);
        expect(inputs.densityAware, isTrue);
        expect(inputs.temperature, GasDensityTemperature.twentyC);
      },
    );

    test('Rec reads END limit and O2-narcotic live, ignoring any override', () {
      const settings = AppSettings(endLimit: 32, o2Narcotic: false);
      final container = _container(_FakeRepository(), settings: settings);
      // An override set while in a Tec mode must never leak into Rec, which
      // has no control for it and always follows the live profile setting.
      container.read(bestMixCalculatorNotifierProvider.notifier)
        ..setMode(BestMixMode.ocTec)
        ..setEndLimit(24)
        ..setO2Narcotic(true)
        ..setMode(BestMixMode.rec);
      final inputs = container.read(bestMixCalculatorInputsProvider);
      expect(inputs.endLimitMeters, 32);
      expect(inputs.o2Narcotic, isFalse);
    });

    test(
      'OC-Tec and CCR-Tec resolve the overridden END limit and O2-narcotic',
      () {
        const settings = AppSettings(endLimit: 30, o2Narcotic: true);
        final container = _container(_FakeRepository(), settings: settings);
        container.read(bestMixCalculatorNotifierProvider.notifier)
          ..setMode(BestMixMode.ocTec)
          ..setEndLimit(24)
          ..setO2Narcotic(false);
        var inputs = container.read(bestMixCalculatorInputsProvider);
        expect(inputs.endLimitMeters, 24);
        expect(inputs.o2Narcotic, isFalse);

        // The same per-diver override follows into CCR-Tec: it is a profile
        // override, not a per-mode setting.
        container
            .read(bestMixCalculatorNotifierProvider.notifier)
            .setMode(BestMixMode.ccrTec);
        inputs = container.read(bestMixCalculatorInputsProvider);
        expect(inputs.endLimitMeters, 24);
        expect(inputs.o2Narcotic, isFalse);
      },
    );
  });
}
