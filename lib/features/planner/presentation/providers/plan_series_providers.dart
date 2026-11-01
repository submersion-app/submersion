import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_series_calculator.dart'
    as calculator;
import 'package:submersion/features/planner/domain/services/plan_series_edits.dart'
    as edits;
import 'package:submersion/features/planner/domain/services/plan_series_settings.dart'
    as settings;
import 'package:submersion/features/planner/domain/services/plan_series_tanks.dart'
    as series_tanks;
import 'package:submersion/features/planner/domain/services/plan_setting_groups.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

const _uuid = Uuid();

/// Holds a repetitive series of planned dives (issue #3565) around the
/// existing editor: [divePlanNotifierProvider] keeps editing whichever dive
/// is selected, and this keeps every other dive.
///
/// Selecting a dive stores the one being edited and loads the selected one
/// into the editor with everything the dives before it carry in applied.
/// Edits made in the editor flow back here. A plan the editor starts or
/// loads by itself (New plan, a saved plan) starts a new one-dive series.
class PlanSeriesNotifier extends StateNotifier<PlanSeries> {
  PlanSeriesNotifier({
    required DivePlanNotifier editor,
    required DivePlanState Function() readEditor,
    required PlanEngineConfig Function() getConfig,
    String Function()? newId,
  }) : _editor = editor,
       _readEditor = readEditor,
       _getConfig = getConfig,
       _newId = newId ?? _uuid.v4,
       _seenLoads = editor.loadCount,
       super(PlanSeries.single(readEditor()));

  final DivePlanNotifier _editor;
  final DivePlanState Function() _readEditor;
  final PlanEngineConfig Function() _getConfig;
  final String Function() _newId;

  /// True while this notifier is the one changing the editor, so the change
  /// is not mistaken for a diver's edit.
  bool _pushing = false;

  /// Results of the dives before the selected one. They only change when a
  /// different dive is selected or the settings change.
  List<calculator.SeriesDiveResult> _earlier = const [];

  /// The editor's [DivePlanNotifier.loadCount] when this last saw a change.
  int _seenLoads;

  /// Called on every change of the editor's plan.
  void editorChanged(DivePlanState? previous, DivePlanState next) {
    final loaded = _editor.loadCount != _seenLoads;
    _seenLoads = _editor.loadCount;
    if (_pushing) return;
    // A plan loaded from outside starts over, even under the id of a dive
    // already here: a saved plan opened again is that plan as saved.
    final index = loaded
        ? -1
        : state.dives.indexWhere((d) => d.state.id == next.id);
    if (index < 0) {
      _earlier = const [];
      state = PlanSeries.single(next);
      return;
    }
    final before = state.dives[index].state;
    state = edits.updateDiveState(state, index, next);
    // A setting changed on the first dive is the series'; on a later dive,
    // that dive's own.
    state = settings.shareSettingEdits(
      state,
      index,
      before: before,
      newId: _newId,
    );
    // The name is the whole plan's, so every dive takes a new one.
    if (previous?.name != next.name) {
      state = edits.setPlanName(state, next.name);
    }
    // The diver set the interval, so it leads and the start follows from it.
    // The OTU carried in depends on how long ago each earlier dive ended.
    if ((index > 0 || state.follow != null) &&
        previous?.surfaceInterval != next.surfaceInterval) {
      state = edits.anchorInterval(state, index);
      final carried = calculator.carriedState(
        state.dives,
        index,
        _earlier,
        follow: state.follow,
      );
      if (carried.initialOtu != next.initialOtu ||
          carried.startDateTime != next.startDateTime) {
        _push(
          next.copyWith(
            initialOtu: carried.initialOtu,
            startDateTime: carried.startDateTime,
            clearStartDateTime: carried.startDateTime == null,
          ),
        );
      }
    }
  }

  /// Re-seeds the selected dive after the engine settings changed. What a
  /// first dive carries comes from the logged dive it follows, not the
  /// engine, so it has nothing to re-seed.
  void configChanged() {
    if (state.selectedIndex > 0) _loadSelected();
  }

  void select(int index) {
    final target = index.clamp(0, state.dives.length - 1);
    if (target == state.selectedIndex) return;
    state = edits.selectDive(state, target);
    _loadSelected();
  }

  void previous() => select(state.selectedIndex - 1);

  void next() => select(state.selectedIndex + 1);

  /// Adds a dive after the last one and selects it.
  void addDive() {
    if (!edits.canAppendDive(state)) return;
    state = edits
        .appendDive(state, newId: _newId)
        .copyWith(structureChanged: true);
    _loadSelected();
  }

  void removeDive(int index) {
    final before = state;
    state = edits.removeDive(state, index);
    if (identical(before, state)) return;
    state = state.copyWith(structureChanged: true);
    _loadSelected();
  }

  /// Names the selected dive; a blank name clears it. The name is the
  /// series' own, so the editor is left alone.
  void renameSelected(String name) {
    state = edits
        .renameDive(state, state.selectedIndex, name)
        .copyWith(structureChanged: true);
  }

  /// Replaces the series with [series], as saved or opened, and loads its
  /// selected dive. Not an outside load: it is the series doing the loading.
  void loadSeries(PlanSeries series) {
    _earlier = const [];
    state = series;
    _loadSelected();
  }

  /// Links dives to their entries in the log, by index.
  void setLinkedDives(Map<int, String> links) {
    state = state.copyWith(
      dives: [
        for (final (index, dive) in state.dives.indexed)
          if (links[index] case final id?)
            dive.copyWith(state: dive.state.copyWith(linkedDiveId: id))
          else
            dive,
      ],
    );
    _loadSelected();
  }

  /// Forgets the log entries of removed dives, once they have been offered.
  void clearRemovedLinkedDives() {
    state = state.copyWith(removedLinkedDiveIds: const {});
  }

  /// Sets when the first dive starts, whichever dive is selected.
  void setFirstStart(DateTime start) {
    state = edits.setDiveStart(state, 0, start);
    _loadSelected();
  }

  /// Sets when the selected dive starts, as clock digits stamped UTC; null
  /// clears it. A later dive's interval then comes from it (see
  /// [PlanSeriesDive.fixedStart]).
  void setSelectedStart(DateTime? start) {
    final index = state.selectedIndex;
    state = edits.setDiveStart(state, index, start);
    _push(
      calculator.carriedState(
        state.dives,
        index,
        _earlier,
        follow: state.follow,
      ),
    );
  }

  /// Puts the selected dive back on the series' settings of [group].
  void resetGroupToSeries(PlanSettingGroup group) {
    state = settings.resetGroupToSeries(
      state,
      state.selectedIndex,
      group,
      newId: _newId,
    );
    _loadSelected();
  }

  /// Makes the selected dive's settings of [group] the series'.
  void applyGroupToAll(PlanSettingGroup group) {
    state = settings.applyGroupToAll(
      state,
      state.selectedIndex,
      group,
      newId: _newId,
    );
    _loadSelected();
  }

  /// Follows the logged dives in [follow]: the first dive starts from the
  /// followed one, after [surfaceInterval]. Ignored for a replan, which
  /// keeps the seed it was opened with (see [followAllowedProvider]).
  void followDive(SeriesFollow follow, {required Duration surfaceInterval}) {
    if (isReplan(state)) return;
    state = edits.followDive(
      state,
      follow,
      surfaceInterval: surfaceInterval,
      newId: _newId,
    );
    // The first dive took the followed dive's tanks, and it is the series'.
    state = series_tanks.followSeriesTanks(state, newId: _newId);
    _loadSelected();
  }

  /// Stops following a logged dive.
  void unfollow() {
    if (state.follow == null) return;
    state = edits.unfollow(state);
    _loadSelected();
  }

  /// Fills one tank of the selected dive.
  void fillTank(String tankId) {
    state = edits.fillTank(state, state.selectedIndex, tankId);
    _push(state.selected.state);
  }

  /// Fills every tank of the selected dive.
  void fillAllTanks() {
    state = edits.fillAllTanks(state, state.selectedIndex);
    _push(state.selected.state);
  }

  void _loadSelected() {
    final index = state.selectedIndex;
    _earlier = calculator.computeSeries(
      state.dives.sublist(0, index),
      config: _getConfig(),
      follow: state.follow,
    );
    _push(
      calculator.carriedState(
        state.dives,
        index,
        _earlier,
        follow: state.follow,
      ),
    );
  }

  /// Loads [plan] into the editor and stores what the editor ends up with.
  void _push(DivePlanState plan) {
    _pushing = true;
    try {
      _editor.loadPlan(plan);
    } finally {
      _pushing = false;
      // Loading the state the editor already holds notifies nobody, so this
      // load would otherwise read as an outside one at the next edit.
      _seenLoads = _editor.loadCount;
    }
    state = edits.updateDiveState(
      state,
      state.selectedIndex,
      _readEditor(),
      pinTypedPressures: false,
    );
  }
}

/// The repetitive series around the plan being edited (issue #3565).
///
/// Like [divePlanNotifierProvider] this must never rebuild, which would
/// lose the series, so it reads everything and listens for changes.
final planSeriesNotifierProvider =
    StateNotifierProvider<PlanSeriesNotifier, PlanSeries>((ref) {
      final notifier = PlanSeriesNotifier(
        editor: ref.read(divePlanNotifierProvider.notifier),
        readEditor: () => ref.read(divePlanNotifierProvider),
        getConfig: () => ref.read(planEngineConfigProvider),
      );
      ref.listen<DivePlanState>(
        divePlanNotifierProvider,
        notifier.editorChanged,
      );
      // Deferred: when the planner comes back after a settings change, the
      // config refreshes inside a widget's build, where providers cannot be
      // changed.
      ref.listen<PlanEngineConfig>(
        planEngineConfigProvider,
        (_, _) => Future.microtask(() {
          if (notifier.mounted) notifier.configChanged();
        }),
      );
      return notifier;
    });

/// Every dive of the series computed in order, for the navigator and the
/// series checks. The selected dive's result matches [planOutcomeProvider].
final planSeriesResultsProvider = Provider<List<calculator.SeriesDiveResult>>((
  ref,
) {
  final inputs = ref.watch(planSeriesNotifierProvider.select(_chainInputs));
  final dives = inputs.dives;
  // One dive is the plan in the editor, which that provider already runs.
  if (dives.length == 1) {
    final state = dives.single.state;
    final outcome = ref.watch(planOutcomeProvider);
    final issues = calculator.seriesIssuesFor(
      dives,
      0,
      state,
      outcome.maxDepth,
      const [],
      config: ref.watch(planEngineConfigProvider),
      follow: inputs.follow,
    );
    return [
      calculator.SeriesDiveResult(
        state: state,
        outcome: outcome.withIssues(issues),
        seriesIssues: issues,
      ),
    ];
  }
  return calculator.computeSeries(
    dives,
    config: ref.watch(planEngineConfigProvider),
    follow: inputs.follow,
  );
});

/// What the series raises about the dive in the editor, which the live
/// outcome, computed by the engine alone, has no way to know.
final selectedSeriesIssuesProvider = Provider<List<PlanIssue>>((ref) {
  final index = ref.watch(
    planSeriesNotifierProvider.select((s) => s.selectedIndex),
  );
  final results = ref.watch(planSeriesResultsProvider);
  return index < results.length ? results[index].seriesIssues : const [];
});

/// The series as the chain reads it: without the dives' names or the
/// selection, so neither of those runs the engine again.
PlanSeries _chainInputs(PlanSeries series) => PlanSeries(
  dives: [for (final dive in series.dives) dive.copyWith(clearName: true)],
  follow: series.follow,
);

/// Where the selected dive's settings of a group come from, for its Setup
/// section: null on a single dive, which has no series to share with.
final settingScopeProvider = Provider.family<SettingScope?, PlanSettingGroup>((
  ref,
  group,
) {
  final (isSeries, index, overridden) = ref.watch(
    planSeriesNotifierProvider.select(
      (s) => (
        s.isSeries,
        s.selectedIndex,
        s.selected.settingOverrides.contains(group),
      ),
    ),
  );
  if (!isSeries) return null;
  if (index == 0) return SettingScope.series;
  return overridden ? SettingScope.thisDive : SettingScope.fromSeries;
});

/// Where a dive's settings of a group come from.
enum SettingScope {
  /// The first dive: its settings are the series'.
  series,

  /// A later dive taking the series' settings.
  fromSeries,

  /// A later dive with its own.
  thisDive,
}

/// Whether a dive can be added after the last one.
final canAddSeriesDiveProvider = Provider<bool>(
  (ref) => edits.canAppendDive(ref.watch(planSeriesNotifierProvider)),
);

/// Whether the plan can be turned into a DPV mission.
final missionAllowedProvider = Provider<bool>(
  (ref) => edits.canPlanMission(ref.watch(planSeriesNotifierProvider)),
);

/// Whether the plan saves as a series rather than an ordinary plan.
final planSeriesSavesAsSeriesProvider = Provider<bool>(
  (ref) => ref.watch(planSeriesNotifierProvider.select((s) => s.savesAsSeries)),
);

/// Whether anything in the series has changed since it was saved or opened,
/// on any dive, not only the one in the editor.
final planSeriesDirtyProvider = Provider<bool>(
  (ref) => ref.watch(planSeriesNotifierProvider.select((s) => s.isDirty)),
);

/// Whether the plan can follow a logged dive. A replan cannot: it already
/// starts from the dive before the one it replans, and its source dive is
/// what makes it a replan.
final followAllowedProvider = Provider<bool>(
  (ref) => !ref.watch(planSeriesNotifierProvider.select(isReplan)),
);

/// Whether [series] replans a logged dive. Its first dive does; the dives
/// added after it have no source dive of their own, so the selected dive
/// cannot answer this.
bool isReplan(PlanSeries series) =>
    series.dives.first.state.sourceDiveId != null;

/// The tanks of the selected dive that Fill would top up, with the pressure
/// it fills each to. Empty on a first dive that follows no logged dive,
/// where nothing is carried in.
final seriesFillPressuresProvider = Provider<Map<String, double>>((ref) {
  final series = ref.watch(planSeriesNotifierProvider);
  final index = series.selectedIndex;
  if (index == 0 && series.follow == null) return const {};
  return edits.fillPressures(series, index);
});
