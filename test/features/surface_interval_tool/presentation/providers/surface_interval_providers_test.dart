import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/surface_interval_tool/presentation/providers/surface_interval_providers.dart';

/// Minimal stand-in for [SettingsNotifier] so the deco providers can read
/// gradient factors without touching the database.
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _createContainer() {
  final container = ProviderContainer(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('second dive gas mix state', () {
    test('defaults to air', () {
      final container = _createContainer();

      expect(container.read(siSecondDiveO2Provider), 21.0);
      expect(container.read(siSecondDiveHeProvider), 0.0);
    });

    test(
      'derives nitrogen and helium fractions from O2 and He percentages',
      () {
        final container = _createContainer();

        container.read(siSecondDiveO2Provider.notifier).state = 32.0;
        container.read(siSecondDiveHeProvider.notifier).state = 0.0;

        expect(container.read(siSecondDiveFN2Provider), closeTo(0.68, 1e-9));
        expect(container.read(siSecondDiveFHeProvider), closeTo(0.0, 1e-9));

        container.read(siSecondDiveO2Provider.notifier).state = 21.0;
        container.read(siSecondDiveHeProvider.notifier).state = 35.0;

        expect(container.read(siSecondDiveFN2Provider), closeTo(0.44, 1e-9));
        expect(container.read(siSecondDiveFHeProvider), closeTo(0.35, 1e-9));
      },
    );

    test('air defaults match the first dive gas exactly', () {
      final container = _createContainer();

      expect(
        container.read(siSecondDiveFN2Provider),
        container.read(siFirstDiveFN2Provider),
      );
      expect(
        container.read(siSecondDiveFHeProvider),
        container.read(siFirstDiveFHeProvider),
      );

      // The 21% slider position yields 0.79, marginally leaner than the
      // airN2Fraction constant (0.7902, which absorbs trace gases). Both dives
      // share this convention, so the tolerance here matches slider resolution.
      expect(
        container.read(siSecondDiveFN2Provider),
        closeTo(airN2Fraction, 0.001),
      );
    });
  });

  group('siSecondDiveNdlProvider honours the second dive gas', () {
    test('nitrox yields a longer NDL than air at the same depth', () {
      final container = _createContainer();

      container.read(siFirstDiveDepthProvider.notifier).state = 30.0;
      container.read(siFirstDiveTimeProvider.notifier).state = 25;
      container.read(siSurfaceIntervalProvider.notifier).state = 60;
      container.read(siSecondDiveDepthProvider.notifier).state = 18.0;

      final airNdl = container.read(siSecondDiveNdlProvider);

      container.read(siSecondDiveO2Provider.notifier).state = 32.0;
      final nitroxNdl = container.read(siSecondDiveNdlProvider);

      expect(airNdl, greaterThan(0));
      expect(
        nitroxNdl,
        greaterThan(airNdl),
        reason: 'EAN32 loads less nitrogen than air, so NDL must be longer',
      );
    });

    test('helium in the mix changes the NDL away from the air result', () {
      final container = _createContainer();

      container.read(siFirstDiveDepthProvider.notifier).state = 30.0;
      container.read(siFirstDiveTimeProvider.notifier).state = 25;
      container.read(siSurfaceIntervalProvider.notifier).state = 60;
      container.read(siSecondDiveDepthProvider.notifier).state = 30.0;

      final airNdl = container.read(siSecondDiveNdlProvider);

      container.read(siSecondDiveO2Provider.notifier).state = 21.0;
      container.read(siSecondDiveHeProvider.notifier).state = 35.0;
      final trimixNdl = container.read(siSecondDiveNdlProvider);

      expect(trimixNdl, isNot(equals(airNdl)));
    });
  });

  group('siMinimumIntervalProvider honours the second dive gas', () {
    test('nitrox requires a shorter surface interval than air', () {
      final container = _createContainer();

      // A second dive that is achievable on air, so both results sit inside
      // the provider's 0-360 minute binary search range.
      container.read(siFirstDiveDepthProvider.notifier).state = 30.0;
      container.read(siFirstDiveTimeProvider.notifier).state = 25;
      container.read(siSecondDiveDepthProvider.notifier).state = 18.0;
      container.read(siSecondDiveTimeProvider.notifier).state = 30;

      final airInterval = container.read(siMinimumIntervalProvider);

      container.read(siSecondDiveO2Provider.notifier).state = 32.0;
      final nitroxInterval = container.read(siMinimumIntervalProvider);

      expect(
        airInterval.outcome,
        SiIntervalOutcome.withinHorizon,
        reason: 'scenario must be achievable',
      );
      expect(nitroxInterval.outcome, SiIntervalOutcome.withinHorizon);
      expect(airInterval.minutes, greaterThan(0));
      expect(
        nitroxInterval.minutes,
        lessThan(airInterval.minutes!),
        reason: 'A leaner nitrogen mix should shorten the required off-gassing',
      );
    });
  });

  group('siSecondDiveIsSafeProvider honours the second dive gas', () {
    test('a dive that busts NDL on air can fit within NDL on nitrox', () {
      final container = _createContainer();

      container.read(siFirstDiveDepthProvider.notifier).state = 30.0;
      container.read(siFirstDiveTimeProvider.notifier).state = 25;
      container.read(siSurfaceIntervalProvider.notifier).state = 60;
      container.read(siSecondDiveDepthProvider.notifier).state = 30.0;

      final airNdlMinutes = container.read(siSecondDiveNdlProvider) ~/ 60;

      // Plan one minute beyond what air allows.
      container.read(siSecondDiveTimeProvider.notifier).state =
          airNdlMinutes + 1;
      expect(container.read(siSecondDiveIsSafeProvider), isFalse);

      container.read(siSecondDiveO2Provider.notifier).state = 32.0;
      expect(container.read(siSecondDiveIsSafeProvider), isTrue);
    });
  });
}
