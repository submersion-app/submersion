import 'package:flutter_test/flutter_test.dart';

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

/// Sets up a two-dive plan and returns the computed minimum interval.
SiMinimumInterval _planFor(
  ProviderContainer container, {
  required double firstDepth,
  required int firstTime,
  required double secondDepth,
  required int secondTime,
}) {
  container.read(siFirstDiveDepthProvider.notifier).state = firstDepth;
  container.read(siFirstDiveTimeProvider.notifier).state = firstTime;
  container.read(siSecondDiveDepthProvider.notifier).state = secondDepth;
  container.read(siSecondDiveTimeProvider.notifier).state = secondTime;
  return container.read(siMinimumIntervalProvider);
}

void main() {
  group('siMinimumIntervalProvider rejects impossible second dives', () {
    test('a second dive longer than the clean-tissue NDL is impossible', () {
      final container = _createContainer();

      // The reported case: two 45 minute dives at 18 m on air. Off-gassing at
      // the surface can only ever restore tissues to their clean state, and the
      // clean-tissue no-stop time at 18 m on air is around 43 minutes. No
      // surface interval, however long, buys a 45 minute second dive.
      final result = _planFor(
        container,
        firstDepth: 18.0,
        firstTime: 45,
        secondDepth: 18.0,
        secondTime: 45,
      );

      expect(result.outcome, SiIntervalOutcome.impossible);
      expect(result.minutes, isNull);
      expect(
        result.cleanTissueNoStopSeconds,
        lessThan(45 * 60),
        reason: 'the no-stop ceiling is what puts the dive out of reach',
      );
    });

    test('never reports the search bound as if it were an answer', () {
      final container = _createContainer();

      // Deep and long enough that the plan is wildly out of reach. The old
      // binary search returned its own upper bound here, which the result card
      // rendered as a plausible looking "6h 0m".
      final result = _planFor(
        container,
        firstDepth: 40.0,
        firstTime: 20,
        secondDepth: 40.0,
        secondTime: 60,
      );

      expect(result.outcome, SiIntervalOutcome.impossible);
      expect(result.hasInterval, isFalse);
    });

    test('the no-stop ceiling ignores the first dive entirely', () {
      final container = _createContainer();

      // The ceiling is a property of the second dive's depth and mix: surface
      // time works toward it no matter how loaded the diver starts out.
      final afterEasyDive = _planFor(
        container,
        firstDepth: 9.0,
        firstTime: 10,
        secondDepth: 18.0,
        secondTime: 45,
      );
      final afterHardDive = _planFor(
        container,
        firstDepth: 40.0,
        firstTime: 60,
        secondDepth: 18.0,
        secondTime: 45,
      );

      expect(
        afterHardDive.cleanTissueNoStopSeconds,
        afterEasyDive.cleanTissueNoStopSeconds,
      );
    });

    test('shortening the second dive turns it into a modest wait', () {
      final container = _createContainer();

      final tooLong = _planFor(
        container,
        firstDepth: 18.0,
        firstTime: 45,
        secondDepth: 18.0,
        secondTime: 45,
      );
      final achievable = _planFor(
        container,
        firstDepth: 18.0,
        firstTime: 45,
        secondDepth: 18.0,
        secondTime: 40,
      );

      // The cliff the diver saw: five fewer minutes underwater swings the
      // answer from "six hours" to about an hour. Only one of these two is a
      // real number, and it is the shorter dive.
      expect(tooLong.outcome, SiIntervalOutcome.impossible);
      expect(achievable.outcome, SiIntervalOutcome.withinHorizon);
      expect(achievable.minutes, lessThan(120));
    });
  });

  group('siMinimumIntervalProvider separates a long wait from an impossible '
      'one', () {
    test('a dive that needs more than the horizon is not called impossible', () {
      final container = _createContainer();

      // Compartment 16 has a 635 minute nitrogen half-time, so after a heavily
      // loaded first dive the diver is still unloading well past six hours.
      // Here the clean-tissue NDL at 12 m on air is about 123 minutes, so a 60
      // minute second dive is entirely possible -- it just needs a longer wait
      // than the planner searches. Reporting it as impossible would tell the
      // diver to change a dive that is fine.
      final result = _planFor(
        container,
        firstDepth: 55.0,
        firstTime: 120,
        secondDepth: 12.0,
        secondTime: 100,
      );

      expect(result.outcome, SiIntervalOutcome.beyondHorizon);
      expect(result.minutes, isNull);
      expect(
        result.cleanTissueNoStopSeconds,
        greaterThanOrEqualTo(60 * 60),
        reason: 'the dive fits on clean tissues, so it is not impossible',
      );
    });

    test('the same plan with a longer second dive is impossible', () {
      final container = _createContainer();

      // Past the clean-tissue ceiling at 12 m, no amount of waiting helps.
      final result = _planFor(
        container,
        firstDepth: 60.0,
        firstTime: 120,
        secondDepth: 12.0,
        secondTime: 124,
      );

      expect(result.outcome, SiIntervalOutcome.impossible);
    });
  });

  group('siMinimumIntervalProvider reports reachable second dives', () {
    test('reports zero when the second dive already fits with no wait', () {
      final container = _createContainer();

      final result = _planFor(
        container,
        firstDepth: 18.0,
        firstTime: 20,
        secondDepth: 9.0,
        secondTime: 10,
      );

      expect(result.outcome, SiIntervalOutcome.withinHorizon);
      expect(
        result.minutes,
        0,
        reason: 'a diver who needs no wait must not be told to wait a minute',
      );
    });

    test('the reported interval really does fit the planned dive', () {
      final container = _createContainer();

      for (final secondTime in [20, 30, 35, 40]) {
        final result = _planFor(
          container,
          firstDepth: 18.0,
          firstTime: 45,
          secondDepth: 18.0,
          secondTime: secondTime,
        );

        expect(
          result.outcome,
          SiIntervalOutcome.withinHorizon,
          reason: '$secondTime min is doable',
        );
        expect(
          result.cleanTissueNoStopSeconds,
          greaterThanOrEqualTo(secondTime * 60),
          reason: 'an achievable plan must sit under the no-stop ceiling',
        );

        // Wind the tool to the interval it just recommended and confirm the
        // second dive actually fits inside the NDL there.
        container.read(siSurfaceIntervalProvider.notifier).state =
            result.minutes!;
        expect(
          container.read(siSecondDiveNdlProvider),
          greaterThanOrEqualTo(secondTime * 60),
          reason: 'the recommended interval must satisfy the requirement',
        );
        expect(container.read(siSecondDiveIsSafeProvider), isTrue);
      }
    });

    test('one minute less than the recommendation is not enough', () {
      final container = _createContainer();

      final result = _planFor(
        container,
        firstDepth: 18.0,
        firstTime: 45,
        secondDepth: 18.0,
        secondTime: 40,
      );

      expect(result.minutes, greaterThan(0));

      container.read(siSurfaceIntervalProvider.notifier).state =
          result.minutes! - 1;
      expect(
        container.read(siSecondDiveIsSafeProvider),
        isFalse,
        reason: 'the answer must be the minimum, not merely a sufficient wait',
      );
    });

    test('nitrox requires a shorter surface interval than air', () {
      final container = _createContainer();

      final air = _planFor(
        container,
        firstDepth: 30.0,
        firstTime: 25,
        secondDepth: 18.0,
        secondTime: 30,
      );

      container.read(siSecondDiveO2Provider.notifier).state = 32.0;
      final nitrox = container.read(siMinimumIntervalProvider);

      expect(air.outcome, SiIntervalOutcome.withinHorizon);
      expect(nitrox.outcome, SiIntervalOutcome.withinHorizon);
      expect(air.minutes, greaterThan(0));
      expect(
        nitrox.minutes,
        lessThan(air.minutes!),
        reason: 'A leaner nitrogen mix should shorten the required off-gassing',
      );
    });
  });
}
