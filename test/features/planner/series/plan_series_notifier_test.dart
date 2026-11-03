import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> makeContainer() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 25);
    return container;
  }

  DivePlanState editor(ProviderContainer c) => c.read(divePlanNotifierProvider);
  PlanSeriesNotifier series(ProviderContainer c) =>
      c.read(planSeriesNotifierProvider.notifier);

  test('a plan starts as a one-dive series of the plan being edited', () async {
    final c = await makeContainer();
    final s = c.read(planSeriesNotifierProvider);
    expect(s.dives, hasLength(1));
    expect(s.isSeries, isFalse);
    expect(s.selected.state, editor(c));
  });

  test('editing the plan updates its dive in the series', () async {
    final c = await makeContainer();
    c.read(planSeriesNotifierProvider);
    c.read(divePlanNotifierProvider.notifier).updateGradientFactors(30, 70);
    expect(c.read(planSeriesNotifierProvider).selected.state.gfLow, 30);
  });

  group('adding a dive', () {
    test('selects it in the editor, seeded from the dive before', () async {
      final c = await makeContainer();
      final first = editor(c);
      series(c).addDive();

      final s = c.read(planSeriesNotifierProvider);
      final results = c.read(planSeriesResultsProvider);
      final added = editor(c);
      expect(s.dives, hasLength(2));
      expect(s.selectedIndex, 1);
      expect(added.id, isNot(first.id));
      expect(added.surfaceInterval, const Duration(hours: 1));
      expect(added.initialTissueState, isNotNull);
      expect(added.initialCns, results[0].outcome.cnsEnd);
      final backUsage = results[0].outcome.tankUsages.first;
      expect(
        added.tanks.first.startPressure,
        closeTo(backUsage.remainingPressure!, 1e-9),
      );
    });

    test('the live outcome agrees with the series result', () async {
      final c = await makeContainer();
      series(c).addDive();
      final live = c.read(planOutcomeProvider);
      final result = c.read(planSeriesResultsProvider)[1].outcome;
      expect(live.cnsEnd, closeTo(result.cnsEnd, 1e-9));
      expect(live.runtimeSeconds, result.runtimeSeconds);
    });

    test('is offered for an ordinary plan', () async {
      final c = await makeContainer();
      expect(c.read(canAddSeriesDiveProvider), isTrue);
    });

    test('is not offered for a DPV mission plan', () async {
      final c = await makeContainer();
      c.read(planSeriesNotifierProvider);
      c
          .read(divePlanNotifierProvider.notifier)
          .enableMission(const DpvMission());

      expect(c.read(canAddSeriesDiveProvider), isFalse);
      series(c).addDive();
      expect(c.read(planSeriesNotifierProvider).dives, hasLength(1));
    });
  });

  group('moving between dives', () {
    test('keeps each dive\'s edits', () async {
      final c = await makeContainer();
      final notifier = series(c);
      notifier.addDive();
      c.read(divePlanNotifierProvider.notifier).updateGradientFactors(30, 70);

      notifier.previous();
      expect(editor(c).gfLow, isNot(30));
      notifier.next();
      expect(editor(c).gfLow, 30);
    });

    test('a deeper first dive loads more into the next one', () async {
      final c = await makeContainer();
      final notifier = series(c);
      notifier.addDive();
      final before = editor(c).initialCns!;

      notifier.select(0);
      final plan = c.read(divePlanNotifierProvider.notifier);
      final bottom = editor(c).segments.last;
      plan.updateSegment(
        bottom.id,
        bottom.copyWith(durationSeconds: bottom.durationSeconds * 2),
      );
      notifier.select(1);

      expect(editor(c).initialCns, greaterThan(before));
    });

    test('previous and next stop at the ends', () async {
      final c = await makeContainer();
      final notifier = series(c);
      notifier.addDive();
      notifier.next();
      expect(c.read(planSeriesNotifierProvider).selectedIndex, 1);
      notifier.previous();
      notifier.previous();
      expect(c.read(planSeriesNotifierProvider).selectedIndex, 0);
    });
  });

  group('removing a dive', () {
    test('removing the selected dive loads the one before it', () async {
      final c = await makeContainer();
      final first = editor(c).id;
      final notifier = series(c);
      notifier.addDive();
      notifier.removeDive(1);

      expect(c.read(planSeriesNotifierProvider).isSeries, isFalse);
      expect(editor(c).id, first);
    });
  });

  group('tanks', () {
    test('typing a start pressure pins the tank', () async {
      final c = await makeContainer();
      series(c).addDive();
      final tank = editor(c).tanks.first;
      c
          .read(divePlanNotifierProvider.notifier)
          .updateTank(tank.id, tank.copyWith(startPressure: 150));

      expect(c.read(planSeriesNotifierProvider).selected.pinnedTankIds, {
        tank.id,
      });
      series(c).previous();
      series(c).next();
      expect(editor(c).tanks.first.startPressure, 150);
    });

    test('Fill fills the tank to its first-dive pressure', () async {
      final c = await makeContainer();
      final full = editor(c).tanks.first.startPressure;
      series(c).addDive();
      final tank = editor(c).tanks.first;
      expect(tank.startPressure, lessThan(full!));

      series(c).fillTank(tank.id);
      expect(editor(c).tanks.first.startPressure, full);
    });

    test('Fill all tanks fills every tank', () async {
      final c = await makeContainer();
      final full = editor(c).tanks.map((t) => t.startPressure).toList();
      series(c).addDive();
      series(c).fillAllTanks();
      expect(editor(c).tanks.map((t) => t.startPressure), full);
    });
  });

  test('a 24 hour surface interval drops the carried OTU', () async {
    final c = await makeContainer();
    series(c).addDive();
    expect(editor(c).initialOtu, greaterThan(0));

    c
        .read(divePlanNotifierProvider.notifier)
        .setSurfaceInterval(const Duration(hours: 24));
    expect(editor(c).initialOtu, 0);
  });

  test('starting a new plan starts a new series', () async {
    final c = await makeContainer();
    series(c).addDive();
    c.read(divePlanNotifierProvider.notifier).newPlan();

    final s = c.read(planSeriesNotifierProvider);
    expect(s.isSeries, isFalse);
    expect(s.selected.state, editor(c));
  });

  group('opening a plan starts a new series', () {
    test('even one with the first dive\'s own id', () async {
      final c = await makeContainer();
      final notifier = series(c);
      notifier.addDive();
      notifier.previous();
      final first = editor(c);

      // Opening the same saved plan again, as from Saved plans: the plan
      // read back is a fresh copy under the same id.
      c.read(divePlanNotifierProvider.notifier).loadPlan(first.copyWith());

      final s = c.read(planSeriesNotifierProvider);
      expect(s.isSeries, isFalse);
      expect(s.selected.state, editor(c));
      expect(c.read(planConvertAllowedProvider), isTrue);
    });

    test('from a later dive', () async {
      final c = await makeContainer();
      final first = editor(c);
      series(c).addDive();

      c.read(divePlanNotifierProvider.notifier).loadPlan(first);

      final s = c.read(planSeriesNotifierProvider);
      expect(s.isSeries, isFalse);
      expect(s.selected.state, editor(c));
    });

    test('but moving between its dives does not', () async {
      final c = await makeContainer();
      final notifier = series(c);
      notifier.addDive();
      notifier.previous();
      notifier.next();

      expect(c.read(planSeriesNotifierProvider).dives, hasLength(2));
    });
  });

  test('a series cannot be logged yet; a single dive can', () async {
    final c = await makeContainer();
    expect(c.read(planConvertAllowedProvider), isTrue);
    series(c).addDive();
    expect(c.read(planConvertAllowedProvider), isFalse);
  });

  test('segments keep their own tank after a dive is added', () async {
    final c = await makeContainer();
    series(c).addDive();
    final state = editor(c);
    final tankIds = state.tanks.map((t) => t.id).toSet();
    expect(state.segments, isNotEmpty);
    for (final PlanSegment segment in state.segments) {
      expect(tankIds, contains(segment.tankId));
    }
  });

  group('after the settings change', () {
    test('editing the first dive keeps the dives after it', () async {
      final c = await makeContainer();
      series(c).addDive();
      series(c).select(0);

      series(c).configChanged();
      c.read(divePlanNotifierProvider.notifier).updateGradientFactors(30, 70);

      expect(c.read(planSeriesNotifierProvider).dives, hasLength(2));
    });

    test('editing a one-dive plan keeps its name', () async {
      final c = await makeContainer();
      series(c).renameSelected('Blue Hole');

      series(c).configChanged();
      c.read(divePlanNotifierProvider.notifier).updateGradientFactors(30, 70);

      expect(c.read(planSeriesNotifierProvider).selected.name, 'Blue Hole');
    });
  });

  group('naming a dive', () {
    test('names the selected dive without touching the editor', () async {
      final c = await makeContainer();
      series(c).addDive();
      final before = editor(c);

      series(c).renameSelected('Wreck');

      final s = c.read(planSeriesNotifierProvider);
      expect(s.dives[1].name, 'Wreck');
      expect(s.dives[0].name, isNull);
      expect(editor(c), before);
    });

    test("keeps each dive's name while moving between them", () async {
      final c = await makeContainer();
      series(c).renameSelected('Wreck');
      series(c).addDive();
      series(c).renameSelected('Reef');

      series(c).previous();
      series(c).next();

      final s = c.read(planSeriesNotifierProvider);
      expect(s.dives.map((d) => d.name), ['Wreck', 'Reef']);
    });

    test('starting a new plan drops the names', () async {
      final c = await makeContainer();
      series(c).renameSelected('Wreck');
      c.read(divePlanNotifierProvider.notifier).newPlan();
      expect(c.read(planSeriesNotifierProvider).selected.name, isNull);
    });
  });

  group('the series survives', () {
    test('a settings change on the first dive, then an edit', () async {
      final c = await makeContainer();
      series(c).addDive();
      series(c).select(0);

      series(c).configChanged();
      c.read(divePlanNotifierProvider.notifier).updateGradientFactors(30, 70);

      expect(c.read(planSeriesNotifierProvider).dives, hasLength(2));
    });

    test('stepping past the first dive, then an edit', () async {
      final c = await makeContainer();
      series(c).addDive();
      series(c).select(0);

      series(c).previous();
      c.read(divePlanNotifierProvider.notifier).updateGradientFactors(30, 70);

      expect(c.read(planSeriesNotifierProvider).dives, hasLength(2));
    });

    test('removing a dive the editor is not on, then an edit', () async {
      final c = await makeContainer();
      series(c).addDive();
      series(c).addDive();
      series(c).select(0);

      series(c).removeDive(2);
      c.read(divePlanNotifierProvider.notifier).updateGradientFactors(30, 70);

      expect(c.read(planSeriesNotifierProvider).dives, hasLength(2));
    });
  });

  test('a load is a load even as the first change this sees', () async {
    final c = await makeContainer();
    series(c).renameSelected('Wreck');

    c.read(divePlanNotifierProvider.notifier).loadPlan(editor(c).copyWith());

    expect(c.read(planSeriesNotifierProvider).selected.name, isNull);
  });

  test('renaming the plan names it on every dive', () async {
    final c = await makeContainer();
    series(c).addDive();

    c.read(divePlanNotifierProvider.notifier).updateName('Wreck week');

    final s = c.read(planSeriesNotifierProvider);
    expect(s.dives.map((d) => d.state.name), ['Wreck week', 'Wreck week']);
    series(c).select(0);
    expect(editor(c).name, 'Wreck week');
  });

  test('a DPV mission on an earlier dive holds + back', () async {
    final c = await makeContainer();
    series(c).addDive();
    series(c).select(0);

    c.read(divePlanNotifierProvider.notifier).enableMission(const DpvMission());

    expect(c.read(canAddSeriesDiveProvider), isFalse);
  });

  group('computing the series', () {
    test('a single dive shares the live outcome', () async {
      final c = await makeContainer();
      expect(
        c.read(planSeriesResultsProvider).single.outcome,
        same(c.read(planOutcomeProvider)),
      );
    });

    test('naming a dive runs nothing', () async {
      final c = await makeContainer();
      series(c).addDive();
      final before = c.read(planSeriesResultsProvider);

      series(c).renameSelected('Wreck');

      expect(c.read(planSeriesResultsProvider), same(before));
    });
  });

  group('following a logged dive', () {
    final end = DateTime(2026, 10, 25, 11);
    SeriesFollow follow({double otu = 40}) => SeriesFollow(
      loggedDives: [
        SeriesLoggedDive(
          id: 'logged',
          diveNumber: 7,
          start: end.subtract(const Duration(minutes: 45)),
          end: end,
          endInstant: end,
          otu: otu,
        ),
      ],
      endCns: 20,
    );

    test('the first dive starts from it in the editor', () async {
      final c = await makeContainer();
      series(c).followDive(follow(), surfaceInterval: const Duration(hours: 2));

      expect(editor(c).surfaceInterval, const Duration(hours: 2));
      expect(editor(c).initialCns, 20);
      expect(editor(c).initialOtu, 40);
      expect(editor(c).sourceDiveId, isNull);
    });

    test('holds Convert to Dive back until it stops following', () async {
      final c = await makeContainer();
      series(c).followDive(follow(), surfaceInterval: const Duration(hours: 2));
      expect(c.read(planConvertAllowedProvider), isFalse);

      series(c).unfollow();
      expect(c.read(planConvertAllowedProvider), isTrue);
    });

    test('applies from a later dive too', () async {
      final c = await makeContainer();
      series(c).addDive();
      series(c).followDive(follow(), surfaceInterval: const Duration(hours: 2));

      final s = c.read(planSeriesNotifierProvider);
      expect(s.follow, isNotNull);
      expect(s.dives.first.state.surfaceInterval, const Duration(hours: 2));
    });

    test('is refused for a replan, which keeps its own seed', () async {
      final c = await makeContainer();
      c.read(planSeriesNotifierProvider);
      final notifier = c.read(divePlanNotifierProvider.notifier);
      notifier.loadPlan(editor(c).copyWith(sourceDiveId: 'replanned'));
      final before = editor(c);

      series(c).followDive(follow(), surfaceInterval: const Duration(hours: 2));

      expect(c.read(planSeriesNotifierProvider).follow, isNull);
      expect(editor(c), same(before));
      expect(c.read(followAllowedProvider), isFalse);
    });

    test('is refused from a later dive of a replan too', () async {
      final c = await makeContainer();
      c.read(planSeriesNotifierProvider);
      final notifier = c.read(divePlanNotifierProvider.notifier);
      notifier.loadPlan(editor(c).copyWith(sourceDiveId: 'replanned'));
      series(c).addDive();

      expect(c.read(followAllowedProvider), isFalse);
      series(c).followDive(follow(), surfaceInterval: const Duration(hours: 2));

      expect(c.read(planSeriesNotifierProvider).follow, isNull);
    });

    test('marks the plan as changed, as stopping does', () async {
      final c = await makeContainer();
      final notifier = c.read(divePlanNotifierProvider.notifier);
      series(c);
      notifier.loadPlan(editor(c).copyWith(isDirty: false));

      series(c).followDive(follow(), surfaceInterval: const Duration(hours: 2));
      expect(editor(c).isDirty, isTrue);

      notifier.markSaved();
      series(c).unfollow();
      expect(editor(c).isDirty, isTrue);
    });

    test('Fill marks the plan as changed', () async {
      final c = await makeContainer();
      final notifier = c.read(divePlanNotifierProvider.notifier);
      series(c).followDive(follow(), surfaceInterval: const Duration(hours: 2));
      notifier.markSaved();

      series(c).fillAllTanks();

      expect(editor(c).isDirty, isTrue);
    });

    test(
      'a logged dive picked in the last follow does not carry over',
      () async {
        final c = await makeContainer();
        series(
          c,
        ).followDive(follow(), surfaceInterval: const Duration(hours: 2));
        c.read(viewedLoggedDiveIdProvider.notifier).state = 'logged';
        expect(c.read(viewedLoggedDiveProvider)?.id, 'logged');

        series(c).unfollow();
        series(
          c,
        ).followDive(follow(), surfaceInterval: const Duration(hours: 2));

        expect(c.read(viewedLoggedDiveProvider), isNull);
      },
    );

    test('a later dive still counts the logged dive', () async {
      final c = await makeContainer();
      series(c).followDive(follow(), surfaceInterval: const Duration(hours: 1));
      series(c).addDive();

      expect(editor(c).initialOtu, greaterThan(40));
    });

    test('the computed series counts it on a later dive too', () async {
      final c = await makeContainer();
      series(c).followDive(follow(), surfaceInterval: const Duration(hours: 1));
      series(c).addDive();

      final results = c.read(planSeriesResultsProvider);
      expect(results[0].state.initialOtu, 40);
      expect(results[1].state.initialOtu, greaterThan(40));
    });

    test('the first dive drops the logged OTU once its interval passes '
        'a day', () async {
      final c = await makeContainer();
      series(c).followDive(follow(), surfaceInterval: const Duration(hours: 1));

      c
          .read(divePlanNotifierProvider.notifier)
          .setSurfaceInterval(const Duration(hours: 25));

      expect(editor(c).initialOtu, 0);
    });

    test('unfollowing clears what it carried in', () async {
      final c = await makeContainer();
      series(c).followDive(follow(), surfaceInterval: const Duration(hours: 1));
      series(c).unfollow();

      expect(c.read(planSeriesNotifierProvider).follow, isNull);
      expect(editor(c).surfaceInterval, isNull);
      expect(editor(c).initialCns, isNull);
      expect(editor(c).initialOtu, isNull);
    });

    test('a new plan starts without it', () async {
      final c = await makeContainer();
      series(c).followDive(follow(), surfaceInterval: const Duration(hours: 1));
      c.read(divePlanNotifierProvider.notifier).newPlan();

      expect(c.read(planSeriesNotifierProvider).follow, isNull);
    });
  });
}
