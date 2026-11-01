import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_log_update.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';
import 'series_fixtures.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// "Update planned dives" (issue #3565).
void main() {
  late ProviderContainer c;
  final nine = DateTime.utc(2026, 10, 27, 9);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setUpTestDatabase();
    final prefs = await SharedPreferences.getInstance();
    c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
      ],
    );
    addTearDown(c.dispose);
    c
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 18, bottomTimeMinutes: 20);
    c.read(planSeriesNotifierProvider);
  });

  tearDown(tearDownTestDatabase);

  PlanSeriesNotifier series() => c.read(planSeriesNotifierProvider.notifier);

  /// Dives A (named Wreck) and B, starting at nine.
  void twoDives() {
    series().setSelectedStart(nine);
    series().renameSelected('Wreck');
    series().addDive();
    series().renameSelected('');
    series().fillAllTanks();
  }

  Future<void> entry(String? id, void Function(dynamic dive) check) async {
    final dive = await c.read(diveRepositoryProvider).getDiveById(id!);
    check(dive);
  }

  test(
    'a series gets a planned entry per dive, each at its own time',
    () async {
      twoDives();

      final result = await updatePlannedDives(c);

      expect(result.created, 2);
      expect(result.updated, 0);
      final dives = c.read(planSeriesNotifierProvider).dives;
      final results = c.read(planSeriesResultsProvider);
      await entry(dives[0].state.linkedDiveId, (dive) {
        expect(dive.isPlanned, isTrue);
        expect(dive.name, 'Wreck');
        expect(dive.dateTime, nine);
        expect(dive.diveNumber, isNull);
        expect(dive.profile, isNotEmpty);
      });
      await entry(dives[1].state.linkedDiveId, (dive) {
        expect(dive.name, isNull);
        expect(dive.dateTime, results[1].state.startDateTime);
        expect(dive.dateTime, isNot(nine));
      });
    },
  );

  test('the menu offers to create them, then to update them', () async {
    twoDives();
    expect(c.read(plannedDivesExistProvider), isFalse);

    await updatePlannedDives(c);

    expect(c.read(plannedDivesExistProvider), isTrue);
  });

  test('it saves the series with its links', () async {
    twoDives();
    await updatePlannedDives(c);

    final series = c.read(planSeriesNotifierProvider);
    expect(series.id, isNotNull);
    expect(series.isDirty, isFalse);
    final stored = await c
        .read(divePlanRepositoryProvider)
        .getPlan(series.dives[1].state.id);
    expect(stored?.linkedDiveId, series.dives[1].state.linkedDiveId);
  });

  test('running it again updates the same entries', () async {
    twoDives();
    await updatePlannedDives(c);
    final dives = c.read(planSeriesNotifierProvider).dives;
    final before = dives[1].state.linkedDiveId!;

    final editor = c.read(divePlanNotifierProvider.notifier);
    final bottom = c.read(divePlanNotifierProvider).segments.last;
    editor.updateSegment(bottom.id, bottom.copyWith(durationSeconds: 40 * 60));
    editor.updateGradientFactors(33, 77);
    final result = await updatePlannedDives(c);

    expect(result.created, 0);
    expect(result.updated, 2);
    final after = c
        .read(planSeriesNotifierProvider)
        .dives[1]
        .state
        .linkedDiveId;
    expect(after, before);
    await entry(after, (dive) {
      expect(dive.gradientFactorLow, 33);
      expect(dive.runtime, greaterThan(const Duration(minutes: 40)));
    });
    final profile = await c.read(diveRepositoryProvider).getDiveProfile(before);
    expect(profile.last.timestamp, greaterThan(40 * 60));
  });

  test('a dive already dived is left alone', () async {
    twoDives();
    await updatePlannedDives(c);
    final first = c
        .read(planSeriesNotifierProvider)
        .dives[0]
        .state
        .linkedDiveId!;
    final repository = c.read(diveRepositoryProvider);
    await repository.convertPlanToActualDive(first);
    final dived = await repository.getDiveById(first);

    final result = await updatePlannedDives(c);

    expect(result.updated, 1);
    final after = await repository.getDiveById(first);
    expect(after?.isPlanned, isFalse);
    expect(after?.diveNumber, dived?.diveNumber);
    expect(after?.dateTime, dived?.dateTime);
  });

  test('a single plan keeps its own name on its entry', () async {
    c.read(divePlanNotifierProvider.notifier).updateName('Solo');

    final result = await updatePlannedDives(c);

    expect(result.created, 1);
    await entry(result.selectedDiveId, (dive) => expect(dive.name, 'Solo'));
  });

  test(
    'a dive of a series that cannot be logged is named, and stops it',
    () async {
      series().addDive();

      final result = await updatePlannedDives(c);

      expect(result.valid, isFalse);
      expect(result.blockedBy, 'B');
      expect(await c.read(diveRepositoryProvider).getAllDives(), isEmpty);
    },
  );

  test('a plan that cannot be logged writes nothing', () async {
    c.read(divePlanNotifierProvider.notifier).newPlan();

    final result = await updatePlannedDives(c);

    expect(result.valid, isFalse);
    expect(await c.read(diveRepositoryProvider).getAllDives(), isEmpty);
  });

  group('with a deco gas', () {
    /// A deco dive on EAN32 with a stage of EAN50, in the log.
    Future<String> decoDiveInTheLog() async {
      c
          .read(divePlanNotifierProvider.notifier)
          .loadPlan(
            seriesDiveState(
              depth: 30,
              bottomMinutes: 30,
              backPressure: 300,
            ).copyWith(startDateTime: nine),
          );
      final result = await updatePlannedDives(c);
      expect(result.valid, isTrue);
      return result.selectedDiveId!;
    }

    test(
      'the entry gets the gas switch, on the tank holding that gas',
      () async {
        final id = await decoDiveInTheLog();

        final switches = await c
            .read(diveRepositoryProvider)
            .getGasSwitchesForDive(id);

        expect(switches, hasLength(1));
        expect(switches.single.gasSwitch.depth, greaterThan(0));
        final dive = await c.read(diveRepositoryProvider).getDiveById(id);
        final tank = dive!.tanks.firstWhere(
          (t) => t.id == switches.single.gasSwitch.tankId,
        );
        expect(tank.gasMix, ean50);
      },
    );

    test('updating replaces the switches rather than adding more', () async {
      final id = await decoDiveInTheLog();

      c.read(divePlanNotifierProvider.notifier).updateGradientFactors(35, 75);
      await updatePlannedDives(c);

      final switches = await c
          .read(diveRepositoryProvider)
          .getGasSwitchesForDive(id);
      expect(switches, hasLength(1));
    });

    test('the profile is sampled every 30 seconds', () async {
      final id = await decoDiveInTheLog();

      final profile = await c.read(diveRepositoryProvider).getDiveProfile(id);

      final gaps = [
        for (var i = 1; i < profile.length; i++)
          profile[i].timestamp - profile[i - 1].timestamp,
      ];
      expect(profile.length, greaterThan(30));
      expect(gaps, everyElement(lessThanOrEqualTo(30)));
    });

    test('the log\'s analysis agrees with the plan on the ceiling', () async {
      final id = await decoDiveInTheLog();
      final plan = c.read(planOutcomeProvider);
      final planned = plan.ceilingTrace
          .map((p) => p.$2)
          .reduce((a, b) => a > b ? a : b);

      final analysis = await c.read(profileAnalysisProvider(id).future);
      final logged = analysis!.ceilingCurve.reduce((a, b) => a > b ? a : b);

      expect(logged, closeTo(planned, 1.5));
    });
  });

  group('a dive removed from the series', () {
    test('is offered once its entry is still planned', () async {
      twoDives();
      await updatePlannedDives(c);
      final removed = c
          .read(planSeriesNotifierProvider)
          .dives[1]
          .state
          .linkedDiveId;
      series().removeDive(1);

      final result = await updatePlannedDives(c);

      expect(result.orphans.map((d) => d.id), [removed]);
    });

    test('is not offered once it has been dived', () async {
      twoDives();
      await updatePlannedDives(c);
      final removed = c
          .read(planSeriesNotifierProvider)
          .dives[1]
          .state
          .linkedDiveId!;
      await c.read(diveRepositoryProvider).convertPlanToActualDive(removed);
      series().removeDive(1);

      expect((await updatePlannedDives(c)).orphans, isEmpty);
    });

    test('is not offered again', () async {
      twoDives();
      await updatePlannedDives(c);
      series().removeDive(1);
      await updatePlannedDives(c);
      series().clearRemovedLinkedDives();

      expect((await updatePlannedDives(c)).orphans, isEmpty);
    });
  });

  group('the link back from the log', () {
    test('finds the plan, and goes when the plan does', () async {
      twoDives();
      await updatePlannedDives(c);
      final dive = c.read(planSeriesNotifierProvider).dives[1].state;
      final link = planLinkedToDiveProvider(dive.linkedDiveId!);

      expect(await c.read(link.future), dive.id);

      await c.read(divePlanRepositoryProvider).deletePlan(dive.id);
      c.invalidate(link);
      expect(await c.read(link.future), isNull);
    });

    test('is nothing for a dive with no plan', () async {
      expect(await c.read(planLinkedToDiveProvider('none').future), isNull);
    });
  });
}
