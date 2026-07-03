import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class _StubSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettingsNotifier([AppSettings? settings])
    : super(settings ?? const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ProfileLegendState', () {
    group('sectionExpanded', () {
      test('defaults to expected initial values', () {
        const state = ProfileLegendState();
        expect(state.sectionExpanded['overlays'], true);
        expect(state.sectionExpanded['decompression'], true);
        expect(state.sectionExpanded['markers'], false);
        expect(state.sectionExpanded['gasAnalysis'], false);
        expect(state.sectionExpanded['other'], false);
        expect(state.sectionExpanded['tankPressures'], true);
      });

      test('copyWith preserves sectionExpanded', () {
        const state = ProfileLegendState();
        final updated = state.copyWith(
          sectionExpanded: {...state.sectionExpanded, 'markers': true},
        );
        expect(updated.sectionExpanded['markers'], true);
        expect(updated.sectionExpanded['overlays'], true);
      });

      test('equality includes sectionExpanded', () {
        const state1 = ProfileLegendState();
        final state2 = state1.copyWith(
          sectionExpanded: {...state1.sectionExpanded, 'markers': true},
        );
        expect(state1, isNot(equals(state2)));
      });
    });
  });

  group('ProfileLegend notifier methods (via state)', () {
    group('explicit source set methods', () {
      test('setCeilingSource sets to computer', () {
        const state = ProfileLegendState();
        expect(state.ceilingSource, MetricDataSource.calculated);
        final updated = state.copyWith(
          ceilingSource: MetricDataSource.computer,
        );
        expect(updated.ceilingSource, MetricDataSource.computer);
      });

      test('setNdlSource sets to computer', () {
        const state = ProfileLegendState();
        expect(state.ndlSource, MetricDataSource.calculated);
        final updated = state.copyWith(ndlSource: MetricDataSource.computer);
        expect(updated.ndlSource, MetricDataSource.computer);
      });
    });

    group('activeSecondaryCount', () {
      test('includes showCeiling in count', () {
        const isolatedState = ProfileLegendState(
          showCeiling: true,
          showAscentRateColors: false,
          showEvents: false,
          showMaxDepthMarker: false,
          showPressureMarkers: false,
          showGasSwitchMarkers: false,
        );
        expect(isolatedState.activeSecondaryCount, 1);
      });

      test('does NOT include showEvents in count', () {
        const state = ProfileLegendState(
          showEvents: true,
          showAscentRateColors: false,
          showMaxDepthMarker: false,
          showPressureMarkers: false,
          showGasSwitchMarkers: false,
          showCeiling: false,
        );
        expect(state.activeSecondaryCount, 0);
      });
    });

    group('toggleSection', () {
      test('toggles a collapsed section to expanded', () {
        const state = ProfileLegendState();
        expect(state.sectionExpanded['markers'], false);
        final updated = state.copyWith(
          sectionExpanded: {...state.sectionExpanded, 'markers': true},
        );
        expect(updated.sectionExpanded['markers'], true);
      });

      test('toggles an expanded section to collapsed', () {
        const state = ProfileLegendState();
        expect(state.sectionExpanded['overlays'], true);
        final updated = state.copyWith(
          sectionExpanded: {...state.sectionExpanded, 'overlays': false},
        );
        expect(updated.sectionExpanded['overlays'], false);
      });
    });

    group('showGas', () {
      test('defaults to true', () {
        const state = ProfileLegendState();
        expect(state.showGas, isTrue);
      });

      test('copyWith sets showGas to false', () {
        const state = ProfileLegendState();
        final updated = state.copyWith(showGas: false);
        expect(updated.showGas, isFalse);
      });

      test('copyWith without showGas preserves current value', () {
        const state = ProfileLegendState(showGas: false);
        final updated = state.copyWith(showMaxDepthMarker: true);
        expect(updated.showGas, isFalse);
      });

      test('equality distinguishes showGas true vs false', () {
        const stateOn = ProfileLegendState(showGas: true);
        const stateOff = ProfileLegendState(showGas: false);
        expect(stateOn, isNot(equals(stateOff)));
      });

      test('states with same showGas value are equal (other fields equal)', () {
        const a = ProfileLegendState(showGas: false);
        const b = ProfileLegendState(showGas: false);
        expect(a, equals(b));
      });
    });
  });

  group('ProfileLegend.toggleGas', () {
    ProviderContainer makeContainer() => ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _StubSettingsNotifier(
            const AppSettings(defaultShowGasTimeline: true),
          ),
        ),
      ],
    );

    test('toggles showGas from true to false', () {
      final container = makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(profileLegendProvider.notifier);
      expect(container.read(profileLegendProvider).showGas, isTrue);
      notifier.toggleGas();
      expect(container.read(profileLegendProvider).showGas, isFalse);
    });

    test('toggles showGas from false back to true', () {
      final container = makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(profileLegendProvider.notifier);
      notifier.toggleGas();
      notifier.toggleGas();
      expect(container.read(profileLegendProvider).showGas, isTrue);
    });
  });

  group('showAscentRateLine', () {
    test(
      'defaults to false (seeds from defaultShowAscentRateLine setting)',
      () {
        const state = ProfileLegendState();
        expect(state.showAscentRateLine, isFalse);
      },
    );

    test('copyWith sets showAscentRateLine to true', () {
      const state = ProfileLegendState();
      final updated = state.copyWith(showAscentRateLine: true);
      expect(updated.showAscentRateLine, isTrue);
    });

    test('copyWith without showAscentRateLine preserves current value', () {
      const state = ProfileLegendState(showAscentRateLine: true);
      final updated = state.copyWith(showSac: true);
      expect(updated.showAscentRateLine, isTrue);
    });

    test('equality distinguishes showAscentRateLine true vs false', () {
      const on = ProfileLegendState(showAscentRateLine: true);
      const off = ProfileLegendState(showAscentRateLine: false);
      expect(on, isNot(equals(off)));
    });

    test('hashCode includes showAscentRateLine', () {
      // Empty maps keep the hash deterministic: the state's hashCode spreads
      // Map.entries, whose MapEntry values hash by identity.
      const on = ProfileLegendState(
        showAscentRateLine: true,
        sectionExpanded: {},
        showTankPressure: {},
      );
      const off = ProfileLegendState(
        showAscentRateLine: false,
        sectionExpanded: {},
        showTankPressure: {},
      );
      expect(on.hashCode, isNot(off.hashCode));
    });

    test('activeSecondaryCount includes showAscentRateLine', () {
      const state = ProfileLegendState(
        showAscentRateLine: true,
        showCeiling: false,
        showAscentRateColors: false,
        showMaxDepthMarker: false,
        showPressureMarkers: false,
        showGasSwitchMarkers: false,
      );
      expect(state.activeSecondaryCount, 1);
    });
  });

  group('ProfileLegend.toggleAscentRateLine', () {
    ProviderContainer makeContainer() => ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => _StubSettingsNotifier()),
      ],
    );

    test('toggles showAscentRateLine from false to true', () {
      final container = makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(profileLegendProvider.notifier);
      expect(container.read(profileLegendProvider).showAscentRateLine, isFalse);
      notifier.toggleAscentRateLine();
      expect(container.read(profileLegendProvider).showAscentRateLine, isTrue);
    });

    test('toggles showAscentRateLine from true back to false', () {
      final container = makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(profileLegendProvider.notifier);
      notifier.toggleAscentRateLine();
      notifier.toggleAscentRateLine();
      expect(container.read(profileLegendProvider).showAscentRateLine, isFalse);
    });
  });

  group('ProfileLegend.build gas timeline hydration', () {
    test('showGas starts true when defaultShowGasTimeline is true', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _StubSettingsNotifier(
              const AppSettings(defaultShowGasTimeline: true),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(profileLegendProvider).showGas, isTrue);
    });

    test('showGas starts false when defaultShowGasTimeline is false', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _StubSettingsNotifier(
              const AppSettings(defaultShowGasTimeline: false),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(profileLegendProvider).showGas, isFalse);
    });
  });

  group('ProfileLegend.build ascent rate hydration', () {
    test('both ascent-rate toggles start off with default settings', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => _StubSettingsNotifier()),
        ],
      );
      addTearDown(container.dispose);
      final state = container.read(profileLegendProvider);
      expect(state.showAscentRateColors, isFalse);
      expect(state.showAscentRateLine, isFalse);
    });

    test('showAscentRateColors starts true when the setting is on', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _StubSettingsNotifier(
              const AppSettings(showAscentRateColors: true),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(
        container.read(profileLegendProvider).showAscentRateColors,
        isTrue,
      );
    });

    test('showAscentRateLine seeds from defaultShowAscentRateLine', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _StubSettingsNotifier(
              const AppSettings(defaultShowAscentRateLine: true),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(profileLegendProvider).showAscentRateLine, isTrue);
    });
  });

  group('ProfileLegend.showPhotoMarkers', () {
    test('showPhotoMarkers seeds from defaultShowPhotoMarkers', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _StubSettingsNotifier(
              const AppSettings(defaultShowPhotoMarkers: false),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(profileLegendProvider).showPhotoMarkers, isFalse);
    });

    test('togglePhotoMarkers flips the state', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _StubSettingsNotifier(const AppSettings()),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(profileLegendProvider).showPhotoMarkers, isTrue);
      container.read(profileLegendProvider.notifier).togglePhotoMarkers();
      expect(container.read(profileLegendProvider).showPhotoMarkers, isFalse);
    });
  });
}
