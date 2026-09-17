import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/blending/billed_fill.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_gas_role.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';
import 'package:submersion/features/gas_calculators/domain/blending/equation_of_state.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../support/fake_app_settings_repository.dart';

/// The blender seeds its cylinder volume and currency from the diver's
/// settings, and settingsProvider reaches for SharedPreferences. Overriding it
/// keeps this a pure provider test.
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late ProviderContainer container;

  setUp(
    () => container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _TestSettingsNotifier(const AppSettings()),
        ),
      ],
    ),
  );
  tearDown(() => container.dispose());

  test('defaults reproduce the EAN32 fill procedure', () {
    final outcome = container.read(blenderResultProvider);
    expect(outcome.error, isNull);
    expect(outcome.result!.steps, hasLength(3));
    expect(outcome.result!.settledPressureBar, 200);
  });

  test('the fill temperature reaches the solver', () {
    container.read(blenderTargetMixProvider.notifier).state = const GasMix(
      o2: 18,
      he: 45,
    );
    final warm = container.read(blenderResultProvider).result!;

    container.read(blenderFillTempProvider.notifier).state = 5;
    final cold = container.read(blenderResultProvider).result!;

    expect(cold.steps.last.pressureBar, lessThan(warm.steps.last.pressureBar));
    expect(cold.settledPressureBar, 200);
  });

  test('the gas model reaches the solver', () {
    final z = container
        .read(blenderResultProvider)
        .result!
        .steps[1]
        .pressureBar;
    container.read(blenderGasModelProvider.notifier).state =
        BlendGasModel.ideal;
    final ideal = container
        .read(blenderResultProvider)
        .result!
        .steps[1]
        .pressureBar;
    expect(ideal, isNot(closeTo(z, 0.1)));
  });

  test('billing follows the current cylinder and prices', () {
    container.read(blenderCylinderLitersProvider.notifier).state = 12;
    // Prices are indexed by role (o2, he, topup). The default EAN32 target
    // skips the helium role, so its two steps draw on the o2 and topup
    // roles -- fill-order positions 0 and 2 in the default order -- and
    // pricing the helium role does nothing for this blend.
    container.read(blenderGasPricesProvider.notifier).state = const [
      2.0,
      50.0,
      0.1,
    ];
    final billing = container.read(blenderBillingProvider);
    expect(billing.lines, hasLength(2));
    expect(billing.lines[0].gasIndex, 0);
    expect(billing.lines[1].gasIndex, 2);
    expect(billing.lines[1].unitPricePer100, 0.1);
    expect(billing.total, isNotNull);
  });

  test('templates start from the seeded list', () {
    expect(
      container.read(blenderTemplatesProvider),
      BlenderPreferences.seedTemplates,
    );
  });

  test('reset restores the defaults and bumps the epoch', () {
    container.read(blenderTargetPressureProvider.notifier).state = 300;
    container.read(blenderFillTempProvider.notifier).state = 5;
    final epoch = container.read(blenderResetEpochProvider);

    resetGasBlenderIn(container);

    expect(container.read(blenderTargetPressureProvider), 200);
    expect(container.read(blenderFillTempProvider), kReferenceTempC);
    expect(container.read(blenderResetEpochProvider), epoch + 1);
  });

  group('blenderPreferencesLoaderProvider', () {
    ProviderContainer containerWithRepo(FakeAppSettingsRepository repo) =>
        ProviderContainer(
          overrides: [
            settingsProvider.overrideWith(
              (ref) => _TestSettingsNotifier(const AppSettings()),
            ),
            appSettingsRepositoryProvider.overrideWithValue(repo),
          ],
        );

    test('a stored blob seeds the cylinder and mixes', () async {
      // Issue #1335: these fields joined the persisted blob so the blender
      // remembers the last fill across restarts, not just its templates and
      // billing defaults.
      final repo = FakeAppSettingsRepository()
        ..blenderPreferences =
            BlenderPreferences.defaults(cylinderWaterLiters: 12).copyWith(
              startPressureBar: 40,
              startMix: const GasMix(o2: 14.5, he: 57.2),
              targetPressureBar: 220,
              targetMix: const GasMix(o2: 15, he: 55),
              topupO2Percent: 20.9,
              fillOrder: const [
                BlenderGasRole.he,
                BlenderGasRole.topup,
                BlenderGasRole.o2,
              ],
            );
      final loaderContainer = containerWithRepo(repo);
      addTearDown(loaderContainer.dispose);
      final epochBefore = loaderContainer.read(blenderResetEpochProvider);

      await loaderContainer.read(blenderPreferencesLoaderProvider.future);

      expect(loaderContainer.read(blenderStartPressureProvider), 40);
      expect(
        loaderContainer.read(blenderStartMixProvider),
        const GasMix(o2: 14.5, he: 57.2),
      );
      expect(loaderContainer.read(blenderTargetPressureProvider), 220);
      expect(
        loaderContainer.read(blenderTargetMixProvider),
        const GasMix(o2: 15, he: 55),
      );
      expect(loaderContainer.read(blenderTopupO2PercentProvider), 20.9);
      expect(loaderContainer.read(blenderFillOrderProvider), [
        BlenderGasRole.he,
        BlenderGasRole.topup,
        BlenderGasRole.o2,
      ]);
      // Bumped so the text-editing controllers, which hold their own text
      // rather than reading a provider, re-seed from the freshly loaded
      // values instead of showing stale defaults.
      expect(loaderContainer.read(blenderResetEpochProvider), epochBefore + 1);
    });

    test('no stored blob leaves the hard-coded defaults in place', () async {
      final loaderContainer = containerWithRepo(FakeAppSettingsRepository());
      addTearDown(loaderContainer.dispose);

      await loaderContainer.read(blenderPreferencesLoaderProvider.future);

      expect(loaderContainer.read(blenderStartPressureProvider), 0.0);
      expect(
        loaderContainer.read(blenderStartMixProvider),
        const GasMix(o2: 21),
      );
      expect(loaderContainer.read(blenderTargetPressureProvider), 200.0);
    });

    test(
      'a stored billed date is restored when the running invoice has fills',
      () async {
        // A diver mid-session (e.g. app relaunched between fills) must not
        // lose the date they already picked for the bill in progress.
        final storedDate = DateTime(2026, 1, 3);
        final repo = FakeAppSettingsRepository()
          ..blenderPreferences =
              BlenderPreferences.defaults(cylinderWaterLiters: 12).copyWith(
                billedDate: storedDate,
                billedFills: const [
                  BilledFill(id: '1', label: 'Tx 21/35', lines: [], total: 12),
                ],
              );
        final loaderContainer = containerWithRepo(repo);
        addTearDown(loaderContainer.dispose);

        await loaderContainer.read(blenderPreferencesLoaderProvider.future);

        expect(loaderContainer.read(blenderBilledDateProvider), storedDate);
      },
    );

    test('a stored billed date is NOT restored when the running invoice is '
        'empty, so the header shows today rather than a stale date', () async {
      // Issue #1876: paying archives the fills and resets the date to
      // "now", but that "now" gets persisted too. Restoring it
      // unconditionally on the next launch left a stale date on screen
      // once real time had moved on, even though nothing was billed yet.
      final staleDate = DateTime(2020, 1, 1);
      final repo = FakeAppSettingsRepository()
        ..blenderPreferences = BlenderPreferences.defaults(
          cylinderWaterLiters: 12,
        ).copyWith(billedDate: staleDate, billedFills: const []);
      final loaderContainer = containerWithRepo(repo);
      addTearDown(loaderContainer.dispose);

      final before = DateTime.now();
      await loaderContainer.read(blenderPreferencesLoaderProvider.future);
      // blenderBilledDateProvider is lazy: its DateTime.now() default is
      // only computed on first read, so "after" has to be captured once
      // that read has happened, not before it -- otherwise it is always
      // earlier than the value it is meant to bound.
      final restored = loaderContainer.read(blenderBilledDateProvider);
      final after = DateTime.now();
      expect(restored, isNot(staleDate));
      expect(
        restored.isAfter(before.subtract(const Duration(seconds: 5))) &&
            !restored.isAfter(after),
        isTrue,
      );
    });
  });
}
