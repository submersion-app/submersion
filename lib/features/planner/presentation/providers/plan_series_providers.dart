import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_series_calculator.dart'
    as calculator;
import 'package:submersion/features/planner/domain/services/plan_series_edits.dart'
    as edits;
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
  late int _seenLoads = _editor.loadCount;

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
    state = edits.updateDiveState(state, index, next);
    // The OTU carried in depends on how long ago each earlier dive ended.
    if ((index > 0 || state.follow != null) &&
        previous?.surfaceInterval != next.surfaceInterval) {
      final carried = calculator.carriedState(
        state.dives,
        index,
        _earlier,
        follow: state.follow,
      );
      if (carried.initialOtu != next.initialOtu) {
        _push(next.copyWith(initialOtu: carried.initialOtu));
      }
    }
  }

  /// Re-seeds the selected dive after the engine settings changed.
  void configChanged() => _loadSelected();

  void select(int index) {
    if (index == state.selectedIndex) return;
    state = edits.selectDive(state, index);
    _loadSelected();
  }

  void previous() => select(state.selectedIndex - 1);

  void next() => select(state.selectedIndex + 1);

  /// Adds a dive after the last one and selects it.
  void addDive() {
    if (!edits.canAppendDive(state)) return;
    state = edits.appendDive(state, newId: _newId);
    _loadSelected();
  }

  void removeDive(int index) {
    final before = state;
    state = edits.removeDive(state, index);
    if (!identical(before, state)) _loadSelected();
  }

  /// Names the selected dive; a blank name clears it. The name is the
  /// series' own, so the editor is left alone.
  void renameSelected(String name) {
    state = edits.renameDive(state, state.selectedIndex, name);
  }

  /// Follows the logged dives in [follow]: the first dive starts from the
  /// followed one, after [surfaceInterval].
  void followDive(SeriesFollow follow, {required Duration surfaceInterval}) {
    state = edits.followDive(state, follow, surfaceInterval: surfaceInterval);
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
      ref.listen<PlanEngineConfig>(
        planEngineConfigProvider,
        (_, _) => notifier.configChanged(),
      );
      return notifier;
    });

/// Every dive of the series computed in order, for the navigator and the
/// series checks. The selected dive's result matches [planOutcomeProvider].
final planSeriesResultsProvider = Provider<List<calculator.SeriesDiveResult>>((
  ref,
) {
  final series = ref.watch(planSeriesNotifierProvider);
  return calculator.computeSeries(
    series.dives,
    config: ref.watch(planEngineConfigProvider),
    follow: series.follow,
  );
});

/// Whether a dive can be added after the last one.
final canAddSeriesDiveProvider = Provider<bool>(
  (ref) => edits.canAppendDive(ref.watch(planSeriesNotifierProvider)),
);

/// Whether the plan can be saved. A series of more than one dive cannot be
/// saved until series persistence lands (issue #3565, phase 3).
final planSaveAllowedProvider = Provider<bool>(
  (ref) => !ref.watch(planSeriesNotifierProvider).isSeries,
);

/// Whether the selected dive can follow a logged dive. Only the first dive
/// of a series can: every later one starts from the dive before it.
final followAllowedProvider = Provider<bool>(
  (ref) =>
      ref.watch(planSeriesNotifierProvider.select((s) => s.selectedIndex)) == 0,
);

/// The tanks of the selected dive that Fill would top up, with the pressure
/// it fills each to. Empty on a first dive that follows no logged dive,
/// where nothing is carried in.
final seriesFillPressuresProvider = Provider<Map<String, double>>((ref) {
  final series = ref.watch(planSeriesNotifierProvider);
  final index = series.selectedIndex;
  if (index == 0 && series.follow == null) return const {};
  return {
    for (final tank in series.selected.state.tanks)
      if (edits.fullPressureFor(series, index, tank.id) case final full?
          when (tank.startPressure ?? 0) < full)
        tank.id: full,
  };
});
