import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/surface_interval_tool/presentation/providers/surface_interval_providers.dart';

/// Settings stand-in that lets a test pick the working ppO2 ceiling.
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(double ppO2MaxWorking)
    : super(AppSettings(ppO2MaxWorking: ppO2MaxWorking));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _createContainer({double ppO2MaxWorking = 1.4}) {
  final container = ProviderContainer(
    overrides: [
      settingsProvider.overrideWith(
        (ref) => _TestSettingsNotifier(ppO2MaxWorking),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('gas safety for the second dive', () {
    test('air at recreational depth is within limits', () {
      final container = _createContainer();

      container.read(siSecondDiveDepthProvider.notifier).state = 30.0;
      container.read(siSecondDiveO2Provider.notifier).state = 21.0;

      final safety = container.read(siSecondDiveGasSafetyProvider);

      // 4 bar ambient x 0.21 = 0.84 bar
      expect(safety.ppO2, closeTo(0.84, 1e-9));
      expect(safety.exceedsMod, isFalse);
    });

    test('reports ppO2 and MOD for a mix that busts the limit', () {
      final container = _createContainer();

      container.read(siSecondDiveDepthProvider.notifier).state = 30.0;
      container.read(siSecondDiveO2Provider.notifier).state = 40.0;

      final safety = container.read(siSecondDiveGasSafetyProvider);

      // 4 bar ambient x 0.40 = 1.60 bar, over the 1.4 working limit.
      expect(safety.ppO2, closeTo(1.6, 1e-9));
      expect(safety.exceedsMod, isTrue);
      // MOD = ((1.4 / 0.40) - 1) * 10 = 25 m
      expect(safety.modMeters, closeTo(25.0, 1e-9));
    });

    test('sits exactly on the limit without tripping the warning', () {
      final container = _createContainer();

      // EAN35 at 30 m gives exactly 1.40 bar.
      container.read(siSecondDiveDepthProvider.notifier).state = 30.0;
      container.read(siSecondDiveO2Provider.notifier).state = 35.0;

      final safety = container.read(siSecondDiveGasSafetyProvider);

      expect(safety.ppO2, closeTo(1.4, 1e-9));
      expect(
        safety.exceedsMod,
        isFalse,
        reason: 'the limit itself is allowed, only above it is a violation',
      );
    });

    test('honours a diver who raised the working ppO2 ceiling', () {
      final container = _createContainer(ppO2MaxWorking: 1.6);

      container.read(siSecondDiveDepthProvider.notifier).state = 30.0;
      container.read(siSecondDiveO2Provider.notifier).state = 40.0;

      final safety = container.read(siSecondDiveGasSafetyProvider);

      expect(safety.ppO2, closeTo(1.6, 1e-9));
      expect(safety.exceedsMod, isFalse);
      // MOD = ((1.6 / 0.40) - 1) * 10 = 30 m
      expect(safety.modMeters, closeTo(30.0, 1e-9));
    });

    test('helium lowers ppO2 so trimix stays breathable deep', () {
      final container = _createContainer();

      container.read(siSecondDiveDepthProvider.notifier).state = 60.0;
      container.read(siSecondDiveO2Provider.notifier).state = 21.0;
      container.read(siSecondDiveHeProvider.notifier).state = 35.0;

      final safety = container.read(siSecondDiveGasSafetyProvider);

      // 7 bar ambient x 0.21 = 1.47 bar, still over 1.4 on a 21% mix.
      expect(safety.exceedsMod, isTrue);

      container.read(siSecondDiveO2Provider.notifier).state = 18.0;
      expect(container.read(siSecondDiveGasSafetyProvider).exceedsMod, isFalse);
    });
  });

  group('gas safety for the first dive', () {
    test('is evaluated against the first dive depth and gas', () {
      final container = _createContainer();

      container.read(siFirstDiveDepthProvider.notifier).state = 40.0;
      container.read(siFirstDiveO2Provider.notifier).state = 32.0;

      final safety = container.read(siFirstDiveGasSafetyProvider);

      // 5 bar ambient x 0.32 = 1.60 bar
      expect(safety.ppO2, closeTo(1.6, 1e-9));
      expect(safety.exceedsMod, isTrue);
    });

    test('does not leak into the second dive result', () {
      final container = _createContainer();

      container.read(siFirstDiveDepthProvider.notifier).state = 40.0;
      container.read(siFirstDiveO2Provider.notifier).state = 32.0;
      container.read(siSecondDiveDepthProvider.notifier).state = 18.0;
      container.read(siSecondDiveO2Provider.notifier).state = 32.0;

      expect(container.read(siFirstDiveGasSafetyProvider).exceedsMod, isTrue);
      expect(container.read(siSecondDiveGasSafetyProvider).exceedsMod, isFalse);
    });
  });

  group('siGasMixesAreSafeProvider', () {
    test('is true when both dives are within limits', () {
      final container = _createContainer();

      expect(container.read(siGasMixesAreSafeProvider), isTrue);
    });

    test('is false when only the first dive busts MOD', () {
      final container = _createContainer();

      container.read(siFirstDiveDepthProvider.notifier).state = 40.0;
      container.read(siFirstDiveO2Provider.notifier).state = 32.0;

      expect(container.read(siGasMixesAreSafeProvider), isFalse);
    });

    test('is false when only the second dive busts MOD', () {
      final container = _createContainer();

      container.read(siSecondDiveDepthProvider.notifier).state = 30.0;
      container.read(siSecondDiveO2Provider.notifier).state = 40.0;

      expect(container.read(siGasMixesAreSafeProvider), isFalse);
    });
  });

  group('siSecondDiveIsSafeProvider is not demoted by gas', () {
    test('stays a pure no-deco verdict', () {
      final container = _createContainer();

      container.read(siFirstDiveDepthProvider.notifier).state = 18.0;
      container.read(siFirstDiveTimeProvider.notifier).state = 20;
      container.read(siSurfaceIntervalProvider.notifier).state = 180;
      container.read(siSecondDiveDepthProvider.notifier).state = 30.0;
      container.read(siSecondDiveTimeProvider.notifier).state = 10;
      container.read(siSecondDiveO2Provider.notifier).state = 40.0;

      expect(
        container.read(siSecondDiveIsSafeProvider),
        isTrue,
        reason: 'NDL verdict must stay separable from the gas verdict',
      );
      expect(container.read(siGasMixesAreSafeProvider), isFalse);
    });
  });
}
