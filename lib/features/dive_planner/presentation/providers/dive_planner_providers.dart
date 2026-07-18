import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_planner/data/services/plan_calculator_service.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';

const _uuid = Uuid();

// ============================================================================
// Service Providers
// ============================================================================

/// Provider for the PlanCalculatorService configured with user settings.
final planCalculatorServiceProvider = Provider<PlanCalculatorService>((ref) {
  final gfLow = ref.watch(gfLowProvider);
  final gfHigh = ref.watch(gfHighProvider);
  final ppO2MaxWorking = ref.watch(ppO2MaxWorkingProvider);
  final ppO2MaxDeco = ref.watch(ppO2MaxDecoProvider);
  final cnsWarningThreshold = ref.watch(cnsWarningThresholdProvider);

  return PlanCalculatorService(
    gfLow: gfLow,
    gfHigh: gfHigh,
    ppO2Warning: ppO2MaxWorking,
    ppO2Critical: ppO2MaxDeco,
    cnsWarningThreshold: cnsWarningThreshold,
    cnsMethod: ref.watch(cnsCalculationMethodProvider),
  );
});

// ============================================================================
// State Notifiers
// ============================================================================

/// StateNotifier for managing dive plan editing state.
class DivePlanNotifier extends StateNotifier<DivePlanState> {
  final PlanCalculatorService _calculator;
  final double Function() _getDefaultReservePressure;
  final DivePlanRepository? _repository;

  /// The persisted aggregate this state was loaded from (or last saved as);
  /// preserves fields the legacy state does not carry across a save cycle.
  domain.DivePlan? _loaded;

  DivePlanNotifier(
    this._calculator, {
    double reservePressure = DivePlanState.kDefaultReservePressureBar,
    double Function()? getDefaultReservePressure,
    DivePlanRepository? repository,
  }) : _getDefaultReservePressure =
           getDefaultReservePressure ?? (() => reservePressure),
       _repository = repository,
       super(_createInitialState(reservePressure: reservePressure));

  static DivePlanState _createInitialState({
    double reservePressure = DivePlanState.kDefaultReservePressureBar,
  }) {
    final now = DateTime.now();
    return DivePlanState(
      id: _uuid.v4(),
      name: 'New Dive Plan',
      segments: [],
      tanks: [_createDefaultTank()],
      reservePressure: reservePressure,
      createdAt: now,
      updatedAt: now,
    );
  }

  static DiveTank _createDefaultTank() {
    return DiveTank(
      id: _uuid.v4(),
      name: 'Primary',
      volume: 11.1, // AL80
      workingPressure: 207.0,
      startPressure: 200.0,
      gasMix: const GasMix(o2: 21, he: 0),
      role: TankRole.backGas,
      order: 0,
    );
  }

  // --------------------------------------------------------------------------
  // Plan Management
  // --------------------------------------------------------------------------

  /// Reset to a new empty plan.
  void newPlan() {
    _loaded = null;
    state = _createInitialState(reservePressure: _getDefaultReservePressure());
  }

  /// Load an existing plan for editing.
  void loadPlan(DivePlanState plan) {
    state = plan;
  }

  /// Load a persisted plan by id. Returns false when it does not exist.
  Future<bool> loadPlanById(String planId) async {
    final repository = _repository;
    if (repository == null) return false;
    final plan = await repository.getPlan(planId);
    if (plan == null || !mounted) return false;
    _loaded = plan;
    state = stateFromDivePlan(plan);
    return true;
  }

  /// Update plan name.
  void updateName(String name) {
    state = state.copyWith(
      name: name,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Update plan notes.
  void updateNotes(String notes) {
    state = state.copyWith(
      notes: notes,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  // --------------------------------------------------------------------------
  // Segment CRUD
  // --------------------------------------------------------------------------

  /// Add a new segment to the plan.
  void addSegment(PlanSegment segment) {
    final segments = [...state.segments, segment];
    _updateSegmentOrders(segments);
    state = state.copyWith(
      segments: segments,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Update an existing segment.
  void updateSegment(String id, PlanSegment segment) {
    final segments = state.segments.map((s) {
      return s.id == id ? segment : s;
    }).toList();
    state = state.copyWith(
      segments: segments,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Replace one segment with one or more segments in place (used by the
  /// chart's split gesture). Orders are renumbered.
  void replaceSegment(String id, List<PlanSegment> replacements) {
    final segments = List<PlanSegment>.from(state.segments);
    final index = segments.indexWhere((s) => s.id == id);
    if (index < 0) return;
    segments
      ..removeAt(index)
      ..insertAll(index, replacements);
    _updateSegmentOrders(segments);
    state = state.copyWith(
      segments: segments,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Remove a segment from the plan.
  void removeSegment(String id) {
    final segments = state.segments.where((s) => s.id != id).toList();
    _updateSegmentOrders(segments);
    state = state.copyWith(
      segments: segments,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Reorder segments (drag-and-drop).
  void reorderSegments(int oldIndex, int newIndex) {
    final segments = [...state.segments];
    final segment = segments.removeAt(oldIndex);
    segments.insert(newIndex.clamp(0, segments.length), segment);
    _updateSegmentOrders(segments);
    state = state.copyWith(
      segments: segments,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  void _updateSegmentOrders(List<PlanSegment> segments) {
    for (int i = 0; i < segments.length; i++) {
      if (segments[i].order != i) {
        segments[i] = segments[i].copyWith(order: i);
      }
    }
  }

  /// Add a simple dive profile as the bottom portion only: a descent and a
  /// bottom segment. The ascent and any decompression are always computed by
  /// the PlanEngine from the deepest segment, so authoring a fixed ascent
  /// here would suppress real deco stops.
  void addSimplePlan({
    required double maxDepth,
    required int bottomTimeMinutes,
  }) {
    if (state.tanks.isEmpty) return;

    final tank = state.tanks.first;
    final segments = <PlanSegment>[
      PlanSegment.descent(
        id: _uuid.v4(),
        targetDepth: maxDepth,
        tankId: tank.id,
        gasMix: tank.gasMix,
        order: 0,
      ),
      PlanSegment.bottom(
        id: _uuid.v4(),
        depth: maxDepth,
        durationMinutes: bottomTimeMinutes,
        tankId: tank.id,
        gasMix: tank.gasMix,
        order: 1,
      ),
    ];

    state = state.copyWith(
      segments: segments,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  // --------------------------------------------------------------------------
  // Tank CRUD
  // --------------------------------------------------------------------------

  /// Add a new tank to the plan.
  void addTank(DiveTank tank) {
    final tanks = [...state.tanks, tank];
    state = state.copyWith(
      tanks: tanks,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Replace the equipment attached to the plan (Gear & Weights, v104).
  void setEquipmentIds(List<String> ids) {
    state = state.copyWith(
      equipmentIds: ids,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Accept (or clear, with both null) a weight prediction snapshot.
  void setPlannedWeight(double? totalKg, Map<String, double>? placement) {
    state = state.copyWith(
      plannedWeightKg: totalKg,
      plannedWeightPlacement: placement,
      clearPlannedWeight: totalKg == null,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Update an existing tank.
  void updateTank(String id, DiveTank tank) {
    final tanks = state.tanks.map((t) {
      return t.id == id ? tank : t;
    }).toList();

    // Also update gas mix in segments using this tank
    final segments = state.segments.map((s) {
      if (s.tankId == id) {
        return s.copyWith(gasMix: tank.gasMix);
      }
      return s;
    }).toList();

    state = state.copyWith(
      tanks: tanks,
      segments: segments,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Remove a tank from the plan.
  void removeTank(String id) {
    // Don't allow removing the last tank
    if (state.tanks.length <= 1) return;

    final tanks = state.tanks.where((t) => t.id != id).toList();

    // Reassign segments using removed tank to first tank
    final firstTankId = tanks.first.id;
    final segments = state.segments.map((s) {
      if (s.tankId == id) {
        return s.copyWith(tankId: firstTankId, gasMix: tanks.first.gasMix);
      }
      return s;
    }).toList();

    state = state.copyWith(
      tanks: tanks,
      segments: segments,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  // --------------------------------------------------------------------------
  // Settings
  // --------------------------------------------------------------------------

  /// Update gradient factors.
  void updateGradientFactors(int gfLow, int gfHigh) {
    state = state.copyWith(
      gfLow: gfLow,
      gfHigh: gfHigh,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Update SAC rate.
  void updateSacRate(double sacRate) {
    state = state.copyWith(
      sacRate: sacRate,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Update ascent and/or descent rate in meters per minute.
  void updateRates({double? ascent, double? descent}) {
    state = state.copyWith(
      ascentRate: ascent,
      descentRate: descent,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Update dive site.
  void updateSite(String? siteId) {
    state = state.copyWith(
      siteId: siteId,
      clearSiteId: siteId == null,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Update altitude for altitude diving.
  void updateAltitude(double? altitude) {
    state = state.copyWith(
      altitude: altitude,
      clearAltitude: altitude == null,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Update reserve pressure in bar.
  void updateReservePressure(double reservePressure) {
    state = state.copyWith(
      reservePressure: reservePressure,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Switch between open circuit and CCR.
  void updateMode(domain.PlanMode mode) {
    state = state.copyWith(
      mode: mode,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Update CCR setpoints; only supplied values change.
  void updateSetpoints({double? low, double? high, double? switchDepth}) {
    state = state.copyWith(
      setpointLow: low,
      setpointHigh: high,
      setpointSwitchDepth: switchDepth,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Update contingency configuration; only supplied values change.
  void updateContingencies({
    double? depthDelta,
    int? timeMinutes,
    domain.TurnPressureRule? turnRule,
    double? turnFraction,
    bool clearTurnRule = false,
  }) {
    state = state.copyWith(
      deviationDepthDelta: depthDelta,
      deviationTimeMinutes: timeMinutes,
      turnPressureRule: turnRule,
      turnPressureFraction: turnFraction,
      clearTurnPressureRule: clearTurnRule,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  // --------------------------------------------------------------------------
  // Repetitive Dive Support
  // --------------------------------------------------------------------------

  /// Set surface interval for repetitive dive planning.
  void setSurfaceInterval(Duration? interval) {
    state = state.copyWith(
      surfaceInterval: interval,
      clearSurfaceInterval: interval == null,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Follow a logged dive: seed tissues from its end-of-dive compartments
  /// and set the surface interval separating it from this plan.
  void setFollowedDive({
    required String diveId,
    List<TissueCompartment>? compartments,
    required Duration surfaceInterval,
  }) {
    state = state.copyWith(
      sourceDiveId: diveId,
      initialTissueState: compartments,
      clearInitialTissueState: compartments == null,
      surfaceInterval: surfaceInterval,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Stop following a dive: drop the seed tissues and surface interval.
  void clearFollowedDive() {
    state = state.copyWith(
      clearSourceDiveId: true,
      clearSurfaceInterval: true,
      clearInitialTissueState: true,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Record (or clear) the dive created from this plan via convert-to-dive.
  void setLinkedDive(String? diveId) {
    state = state.copyWith(
      linkedDiveId: diveId,
      clearLinkedDiveId: diveId == null,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Clear repetitive dive settings.
  void clearRepetitiveDiveSettings() {
    state = state.copyWith(
      clearSurfaceInterval: true,
      clearInitialTissueState: true,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  // --------------------------------------------------------------------------
  // Persistence
  // --------------------------------------------------------------------------

  /// Persist the current plan (and its summary numbers for the list view).
  Future<void> save({PlanSummaryData? summary}) async {
    final repository = _repository;
    if (repository == null) {
      state = state.copyWith(isDirty: false);
      return;
    }
    final plan = divePlanFromState(state, existing: _loaded);
    await repository.savePlan(plan, summary: summary);
    _loaded = plan;
    if (mounted) {
      state = state.copyWith(isDirty: false);
    }
  }

  /// Mark the plan as saved without persisting (legacy path; prefer [save]).
  void markSaved() {
    state = state.copyWith(isDirty: false);
  }

  /// Convert the plan to a Dive entity for saving.
  ///
  /// The dive gets a fresh id (converting twice yields two dives) and its
  /// tanks shed their plan-side ids so the repository generates new rows.
  Dive toDive() {
    // Generate profile points from segments
    final profilePoints = _calculator.generateProfilePoints(state.segments);

    // Calculate max/avg depth
    double maxDepth = 0;
    double totalDepthTime = 0;
    int totalTime = 0;

    for (final segment in state.segments) {
      if (segment.startDepth > maxDepth) maxDepth = segment.startDepth;
      if (segment.endDepth > maxDepth) maxDepth = segment.endDepth;
      totalDepthTime += segment.avgDepth * segment.durationSeconds;
      totalTime += segment.durationSeconds;
    }

    final avgDepth = totalTime > 0 ? totalDepthTime / totalTime : 0.0;

    return Dive(
      id: _uuid.v4(),
      name: state.name,
      dateTime: DateTime.now(),
      runtime: Duration(seconds: totalTime),
      maxDepth: maxDepth,
      avgDepth: avgDepth,
      tanks: [for (final tank in state.tanks) tank.copyWith(id: '')],
      profile: profilePoints,
      notes: state.notes,
      altitude: state.altitude,
      gradientFactorLow: state.gfLow,
      gradientFactorHigh: state.gfHigh,
      isPlanned: true,
    );
  }
}

/// Provider for the dive plan notifier.
final divePlanNotifierProvider =
    StateNotifierProvider<DivePlanNotifier, DivePlanState>((ref) {
      final calculator = ref.watch(planCalculatorServiceProvider);
      // Default reserve: 50 bar for metric, 500 psi (~34.47 bar) for imperial
      final read = ref.read;
      double defaultReserve() {
        final unit = read(pressureUnitProvider);
        return unit == PressureUnit.psi
            ? PressureUnit.psi.convert(500, PressureUnit.bar)
            : DivePlanState.kDefaultReservePressureBar;
      }

      return DivePlanNotifier(
        calculator,
        reservePressure: defaultReserve(),
        getDefaultReservePressure: defaultReserve,
        repository: ref.watch(divePlanRepositoryProvider),
      );
    });

// ============================================================================
// Computed Providers
// ============================================================================

/// Provider for auto-calculated plan results.
///
/// This automatically recalculates whenever the plan state changes.
final planResultsProvider = Provider<PlanResult>((ref) {
  final state = ref.watch(divePlanNotifierProvider);
  final calculator = ref.watch(planCalculatorServiceProvider);

  if (state.segments.isEmpty) {
    return PlanResult.empty();
  }

  return calculator.calculatePlan(
    segments: state.segments,
    tanks: state.tanks,
    sacRate: state.sacRate,
    reservePressure: state.reservePressure,
    initialTissueState: state.initialTissueState,
    // Altitude finally reaches the deco math; 0 keeps the legacy sea-level
    // surface pressure. Water type comes to the planner in Phase 2.
    environment: DiveEnvironment.forConditions(
      altitudeMeters: (state.altitude ?? 0) > 0 ? state.altitude : null,
    ),
  );
});

/// Provider for generated profile points (for charting).
final planProfilePointsProvider = Provider<List<DiveProfilePoint>>((ref) {
  final state = ref.watch(divePlanNotifierProvider);
  final calculator = ref.watch(planCalculatorServiceProvider);

  return calculator.generateProfilePoints(state.segments);
});

/// Provider for checking if plan has warnings.
final planHasWarningsProvider = Provider<bool>((ref) {
  final results = ref.watch(planResultsProvider);
  return results.warnings.isNotEmpty;
});

/// Provider for critical warnings only.
final planCriticalWarningsProvider = Provider<List<PlanWarning>>((ref) {
  final results = ref.watch(planResultsProvider);
  return results.warnings
      .where((w) => w.severity == PlanWarningSeverity.critical)
      .toList();
});

/// Provider for plan validity (no critical warnings, has segments).
final planIsValidProvider = Provider<bool>((ref) {
  final state = ref.watch(divePlanNotifierProvider);
  final criticalWarnings = ref.watch(planCriticalWarningsProvider);

  return state.segments.isNotEmpty && criticalWarnings.isEmpty;
});

// ============================================================================
// Selection/UI State Providers
// ============================================================================

/// Currently selected segment for editing.
final selectedSegmentIdProvider = StateProvider<String?>((ref) => null);

/// Whether the simple plan dialog is shown.
final showSimplePlanDialogProvider = StateProvider<bool>((ref) => false);
