import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    show PlanMode;
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_log_links.dart';
import 'package:submersion/features/planner/presentation/providers/plan_log_update.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_store.dart';
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

/// "Create / Update planned dives" (issue #3565, phase 2b).
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

  Future<Dive?> entry(String? id) =>
      c.read(diveRepositoryProvider).getDiveById(id!);

  String? linkOf(int index) =>
      c.read(planSeriesNotifierProvider).dives[index].state.linkedDiveId;

  test(
    'a series gets a planned entry per dive, each at its own time',
    () async {
      twoDives();

      final result = await updatePlannedDives(c);

      expect(result.created, 2);
      expect(result.updated, 0);
      final results = c.read(planSeriesResultsProvider);
      final a = await entry(linkOf(0));
      expect(a?.isPlanned, isTrue);
      expect(a?.name, 'Wreck');
      expect(a?.dateTime, nine);
      expect(a?.diveNumber, isNull);
      expect(a?.profile, isNotEmpty);
      final b = await entry(linkOf(1));
      expect(b?.name, isNull);
      expect(b?.dateTime, results[1].state.startDateTime);
      expect(b?.dateTime, isNot(nine));
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

    final saved = c.read(planSeriesNotifierProvider);
    expect(saved.id, isNotNull);
    expect(saved.isDirty, isFalse);
    final stored = await c
        .read(divePlanRepositoryProvider)
        .getPlan(saved.dives[1].state.id);
    expect(stored?.linkedDiveId, saved.dives[1].state.linkedDiveId);
  });

  test('running it again rewrites the same entries', () async {
    twoDives();
    await updatePlannedDives(c);
    final before = linkOf(1)!;

    final editor = c.read(divePlanNotifierProvider.notifier);
    final bottom = c.read(divePlanNotifierProvider).segments.last;
    editor.updateSegment(bottom.id, bottom.copyWith(durationSeconds: 40 * 60));
    editor.updateGradientFactors(33, 77);
    final result = await updatePlannedDives(c);

    expect(result.created, 0);
    expect(result.updated, 2);
    expect(linkOf(1), before);
    final dive = await entry(before);
    expect(dive?.gradientFactorLow, 33);
    expect(dive?.runtime, greaterThan(const Duration(minutes: 40)));
    final profile = await c.read(diveRepositoryProvider).getDiveProfile(before);
    expect(profile.last.timestamp, greaterThan(40 * 60));
  });

  test('a name cleared on a dive is cleared on its entry', () async {
    twoDives();
    await updatePlannedDives(c);
    series().select(0);
    series().renameSelected('');

    await updatePlannedDives(c);

    expect((await entry(linkOf(0)))?.name, isNull);
  });

  test('a dive already dived is left alone, and keeps its link', () async {
    twoDives();
    await updatePlannedDives(c);
    final first = linkOf(0)!;
    final repository = c.read(diveRepositoryProvider);
    await repository.convertPlanToActualDive(first);
    final dived = await repository.getDiveById(first);

    final result = await updatePlannedDives(c);

    expect(result.updated, 1);
    expect(result.skipped, 1);
    expect(linkOf(0), first);
    final after = await repository.getDiveById(first);
    expect(after?.isPlanned, isFalse);
    expect(after?.diveNumber, dived?.diveNumber);
    expect(after?.dateTime, dived?.dateTime);
  });

  group('a single plan linked to a dived dive', () {
    /// The plan saved and linked by hand to a logged dive, as the link sheet
    /// does from the dive log, without telling the editor.
    Future<(String, String)> linkedByHand() async {
      await c.read(divePlanNotifierProvider.notifier).save();
      final planId = c.read(divePlanNotifierProvider).id;
      final logged = await c
          .read(paginatedDiveListProvider.notifier)
          .addDive(Dive(id: 'logged', dateTime: nine));
      await c
          .read(divePlanRepositoryProvider)
          .linkPlanToDive(planId, logged.id);
      return (planId, logged.id);
    }

    test('asks before its link moves, and writes nothing', () async {
      final (planId, loggedId) = await linkedByHand();

      final result = await updatePlannedDives(c);

      expect(result.needsLinkMove, isTrue);
      expect(result.created + result.updated, 0);
      final stored = await c.read(divePlanRepositoryProvider).getPlan(planId);
      expect(stored?.linkedDiveId, loggedId);
      expect(await c.read(diveRepositoryProvider).getAllDives(), hasLength(1));
    });

    test('once agreed, a new entry takes the link', () async {
      final (planId, loggedId) = await linkedByHand();

      final result = await updatePlannedDives(c, moveDivedLink: true);

      expect(result.created, 1);
      final stored = await c.read(divePlanRepositoryProvider).getPlan(planId);
      expect(stored?.linkedDiveId, result.selectedDiveId);
      expect(stored?.linkedDiveId, isNot(loggedId));
      expect(
        c.read(divePlanNotifierProvider).linkedDiveId,
        stored?.linkedDiveId,
      );
      final logged = await entry(loggedId);
      expect(logged?.isPlanned, isFalse);
    });
  });

  test('a series whose dives have all been dived writes nothing', () async {
    twoDives();
    await updatePlannedDives(c);
    final repository = c.read(diveRepositoryProvider);
    await repository.convertPlanToActualDive(linkOf(0)!);
    await repository.convertPlanToActualDive(linkOf(1)!);

    final result = await updatePlannedDives(c);

    expect(result.needsLinkMove, isFalse);
    expect(result.created + result.updated, 0);
    expect(result.skipped, 2);
    expect(await repository.getAllDives(), hasLength(2));
  });

  test('a dive of a series linked by hand to a logged dive is kept', () async {
    twoDives();
    await saveCurrentSeries(c);
    final planId = c.read(planSeriesNotifierProvider).dives[0].state.id;
    final logged = await c
        .read(paginatedDiveListProvider.notifier)
        .addDive(Dive(id: 'logged', dateTime: nine));
    await c.read(divePlanRepositoryProvider).linkPlanToDive(planId, logged.id);

    final result = await updatePlannedDives(c);

    expect(result.created, 1);
    expect(result.skipped, 1);
    final stored = await c.read(divePlanRepositoryProvider).getPlan(planId);
    expect(stored?.linkedDiveId, logged.id);
  });

  test('a single plan keeps its own name on its entry', () async {
    c.read(divePlanNotifierProvider.notifier).updateName('Solo');

    final result = await updatePlannedDives(c);

    expect(result.created, 1);
    expect((await entry(result.selectedDiveId))?.name, 'Solo');
    expect(
      c.read(divePlanNotifierProvider).linkedDiveId,
      result.selectedDiveId,
    );
  });

  test('a single plan updated again keeps the same entry', () async {
    final first = (await updatePlannedDives(c)).selectedDiveId;

    final result = await updatePlannedDives(c);

    expect(result.created, 0);
    expect(result.updated, 1);
    expect(result.selectedDiveId, first);
    expect(await c.read(diveRepositoryProvider).getAllDives(), hasLength(1));
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
        expect(switches.single.gasSwitch.computerId, isNull);
        final dive = await entry(id);
        final tank = dive!.tanks.firstWhere(
          (t) => t.id == switches.single.gasSwitch.tankId,
        );
        expect(tank.gasMix, ean50);
      },
    );

    test(
      'a switch on the fly is written at the time the schedule has it',
      () async {
        // EAN50 is breathable from 21 m, so the ascent switches on the way up,
        // above any stop.
        final id = await decoDiveInTheLog();

        final switches = await c
            .read(diveRepositoryProvider)
            .getGasSwitchesForDive(id);
        final schedule = c.read(planOutcomeProvider).schedule;
        final line = schedule.indexWhere(
          (row) => row.gasSwitch && row.gasFO2 == 0.5,
        );

        expect(
          switches.single.gasSwitch.timestamp,
          schedule[line].runtimeSeconds - schedule[line].durationSeconds,
        );
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

    test('the profile is sampled every 10 seconds', () async {
      final id = await decoDiveInTheLog();

      final profile = await c.read(diveRepositoryProvider).getDiveProfile(id);

      final gaps = [
        for (var i = 1; i < profile.length; i++)
          profile[i].timestamp - profile[i - 1].timestamp,
      ];
      expect(profile.length, greaterThan(90));
      expect(gaps, everyElement(lessThanOrEqualTo(10)));
    });

    test("the log's analysis agrees with the plan on the ceiling", () async {
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

  test('a rebreather plan goes in the log as one, on its diluent', () async {
    final editor = c.read(divePlanNotifierProvider.notifier);
    editor.updateMode(PlanMode.ccr);
    final plan = c.read(divePlanNotifierProvider);
    final diluent = plan.tanks.firstWhere((t) => t.role == TankRole.diluent);

    final result = await updatePlannedDives(c);

    expect(result.valid, isTrue);
    final dive = await entry(result.selectedDiveId);
    expect(dive?.diveMode, DiveMode.ccr);
    expect(dive?.diluentGas, diluent.gasMix);
    expect(dive?.setpointLow, plan.setpointLow);
    expect(dive?.setpointHigh, plan.setpointHigh);
    expect(dive?.tanks.where((t) => t.role == TankRole.diluent), hasLength(1));
    expect(
      await c
          .read(diveRepositoryProvider)
          .getGasSwitchesForDive(result.selectedDiveId!),
      isEmpty,
    );
  });

  test(
    'a rebreather plan turned back to open circuit is updated as one',
    () async {
      final editor = c.read(divePlanNotifierProvider.notifier);
      editor.updateMode(PlanMode.ccr);
      final id = (await updatePlannedDives(c)).selectedDiveId;
      editor.updateMode(PlanMode.oc);

      await updatePlannedDives(c);

      final dive = await entry(id);
      expect(dive?.diveMode, DiveMode.oc);
      expect(dive?.diluentGas, isNull);
      expect(dive?.setpointLow, isNull);
    },
  );

  group('a dive removed from the series', () {
    test('is offered while its entry is still planned', () async {
      twoDives();
      await updatePlannedDives(c);
      final removed = linkOf(1);
      series().removeDive(1);

      final result = await updatePlannedDives(c);

      expect(result.orphans.map((d) => d.id), [removed]);
    });

    test('is offered after the series was saved without it', () async {
      twoDives();
      await updatePlannedDives(c);
      final removed = linkOf(1);
      series().addDive();
      series().fillAllTanks();
      series().removeDive(1);
      await saveCurrentSeries(c);

      final result = await updatePlannedDives(c);

      expect(result.orphans.map((d) => d.id), [removed]);
    });

    test('is not offered once it has been dived', () async {
      twoDives();
      await updatePlannedDives(c);
      final removed = linkOf(1)!;
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

    test('is forgotten when another plan is opened', () async {
      twoDives();
      await updatePlannedDives(c);
      series().removeDive(1);
      c.read(divePlanNotifierProvider.notifier).newPlan();

      expect(series().removedLinkedDiveIds, isEmpty);
    });
  });

  group('the link back from the log', () {
    test('finds the plan, and goes when the plan does', () async {
      twoDives();
      await updatePlannedDives(c);
      final dive = c.read(planSeriesNotifierProvider).dives[1].state;
      final link = planForLoggedDiveProvider(dive.linkedDiveId!);

      expect(await c.read(link.future), dive.id);

      await c.read(divePlanRepositoryProvider).deletePlan(dive.id);
      c.invalidate(link);
      expect(await c.read(link.future), isNull);
    });

    test('is nothing for a dive with no plan', () async {
      expect(await c.read(planForLoggedDiveProvider('none').future), isNull);
    });
  });
}
