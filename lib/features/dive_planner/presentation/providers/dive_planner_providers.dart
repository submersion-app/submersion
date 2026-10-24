import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/core/deco/schedule_policy.dart' show AirBreakPolicy;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_engine.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_scenario_service.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart'
    show planEngineConfigProvider, resolvedPlanEngineConfigProvider;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_planner/data/services/plan_calculator_service.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/ccr_loop_slots.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/segment_chain.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';

const _uuid = Uuid();

/// A CCR setpoint pair in bar. The two halves are only meaningful together,
/// so they travel as one value.
typedef CcrSetpoints = ({double low, double high});

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
    gasModel: ref.watch(gasModelProvider),
  );
});

// ============================================================================
// State Notifiers
// ============================================================================

/// StateNotifier for managing dive plan editing state.
class DivePlanNotifier extends StateNotifier<DivePlanState> {
  /// Snapshot taken at construction, deliberately not kept in sync with the
  /// diver's settings -- see [divePlanNotifierProvider] for why this notifier
  /// cannot subscribe to them. Only safe for calls that read no setting, which
  /// today means [PlanCalculatorService.generateProfilePoints] (pure geometry).
  /// Deco math belongs in [planOutcomeProvider], which recomputes on every
  /// settings change.
  final PlanCalculatorService _calculator;

  /// The diver's current planner config, for the few edits that author
  /// segments themselves (the quick plan's descent, a mission's round
  /// trip) and so need an unset rate resolved against Settings now rather
  /// than at engine time (issue #3552). Read on each call, never cached.
  final PlanEngineConfig Function() _getEngineConfig;
  final PlannerWaterType Function() _getDefaultPlannerWaterType;
  final CcrSetpoints Function() _getDefaultCcrSetpoints;
  final DivePlanRepository? _repository;

  /// Loads the diver's equipment, for refreshing a mission's scooters from
  /// the items they were picked from when a plan is opened.
  final Future<List<EquipmentItem>> Function() _loadEquipment;

  static final _log = LoggerService.forClass(DivePlanNotifier);

  /// The persisted aggregate this state was loaded from (or last saved as);
  /// preserves fields the legacy state does not carry across a save cycle.
  domain.DivePlan? _loaded;

  /// Whether this plan already exists in the database.
  ///
  /// [_loaded] is set by [save] and [loadPlanById] and cleared by [newPlan], so
  /// this is an accurate "has been persisted" signal. The plan canvas uses it
  /// to prompt for a name on the first save only.
  ///
  /// Note that [loadPlan] deliberately does not set [_loaded] and therefore
  /// reports `false`. That method has no production call sites today; a future
  /// production caller must set [_loaded] as [loadPlanById] does.
  bool get isPersisted => _loaded != null;

  /// Resolves each defaulted source once, so the initial plan and every later
  /// [newPlan] are provably built from the same one. Dart forbids reading a
  /// field in an initializer list, so without this hop the private constructor
  /// would have to repeat each `??` in its `super` call.
  factory DivePlanNotifier(
    PlanCalculatorService calculator, {
    PlanEngineConfig Function()? getEngineConfig,
    PlannerWaterType Function()? getDefaultPlannerWaterType,
    CcrSetpoints Function()? getDefaultCcrSetpoints,
    DivePlanRepository? repository,
    Future<List<EquipmentItem>> Function()? loadEquipment,
  }) {
    return DivePlanNotifier._(
      calculator,
      getEngineConfig: getEngineConfig ?? (() => const PlanEngineConfig()),
      getDefaultPlannerWaterType:
          getDefaultPlannerWaterType ?? (() => PlannerWaterType.salt),
      getDefaultCcrSetpoints: getDefaultCcrSetpoints ?? _fallbackCcrSetpoints,
      repository: repository,
      loadEquipment: loadEquipment ?? (() async => const <EquipmentItem>[]),
    );
  }

  DivePlanNotifier._(
    this._calculator, {
    required PlanEngineConfig Function() getEngineConfig,
    required PlannerWaterType Function() getDefaultPlannerWaterType,
    required CcrSetpoints Function() getDefaultCcrSetpoints,
    DivePlanRepository? repository,
    required Future<List<EquipmentItem>> Function() loadEquipment,
  }) : _getEngineConfig = getEngineConfig,
       _getDefaultPlannerWaterType = getDefaultPlannerWaterType,
       _getDefaultCcrSetpoints = getDefaultCcrSetpoints,
       _repository = repository,
       _loadEquipment = loadEquipment,
       super(
         _createInitialState(plannerWaterType: getDefaultPlannerWaterType()),
       );

  static CcrSetpoints _fallbackCcrSetpoints() => (
    low: domain.DivePlan.specSetpointLow,
    high: domain.DivePlan.specSetpointHigh,
  );

  static ({WaterType? waterType, double? salinityPpt}) _waterFieldsFor(
    PlannerWaterType type,
  ) => switch (type) {
    PlannerWaterType.salt => (waterType: WaterType.salt, salinityPpt: null),
    PlannerWaterType.fresh => (waterType: WaterType.fresh, salinityPpt: null),
    PlannerWaterType.custom => (
      waterType: null,
      salinityPpt: DiveEnvironment.typicalSeaSalinityPpt,
    ),
  };

  /// A new plan leaves every Setup field unset, gradient factors and
  /// reserve pressure included, so each live-resolves against the diver's
  /// Settings (issue #3552) instead of being snapshotted at creation.
  static DivePlanState _createInitialState({
    required PlannerWaterType plannerWaterType,
  }) {
    final now = DateTime.now();
    final water = _waterFieldsFor(plannerWaterType);
    return DivePlanState(
      id: _uuid.v4(),
      name: 'New Dive Plan',
      segments: [],
      tanks: [_createDefaultTank()],
      waterType: water.waterType,
      salinityPpt: water.salinityPpt,
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
      startPressure: TankPresets.planFillPressureBar,
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
    state = _createInitialState(
      plannerWaterType: _getDefaultPlannerWaterType(),
    );
  }

  /// Move an untouched plan onto the diver's current planner water default.
  void adoptPlannerWaterIfPristine(PlannerWaterType type) {
    if (isPersisted || state.isDirty || state.segments.isNotEmpty) return;
    final water = _waterFieldsFor(type);
    if (state.waterType == water.waterType &&
        state.salinityPpt == water.salinityPpt) {
      return;
    }
    state = state.copyWith(
      waterType: water.waterType,
      clearWaterType: water.waterType == null,
      salinityPpt: water.salinityPpt,
      clearSalinityPpt: water.salinityPpt == null,
    );
  }

  /// Load an existing plan for editing.
  void loadPlan(DivePlanState plan) {
    state = _withCcrSlots(plan);
  }

  // --------------------------------------------------------------------------
  // CCR loop slots (#3220)
  // --------------------------------------------------------------------------

  /// [s] with its two mandatory loop slots filled when it is a CCR plan
  /// (see [CcrLoopSlots]), and every segment remapped onto a diluent
  /// against that same, possibly just-updated, tank list; any other mode
  /// is returned as it is. Filling a slot is not a diver edit, so
  /// [DivePlanState.isDirty] is left alone.
  ///
  /// The remap matters even when [CcrLoopSlots.ensure] changes nothing
  /// about an *existing* slot split: entering CCR on a plan whose only
  /// pure-O2 cylinder is the segments' own gas (an ordinary OC/SCR O2 deco
  /// bottle) has [CcrLoopSlots] claim that cylinder for the oxygen slot,
  /// which leaves every segment referencing it in violation of "a CCR
  /// segment always breathes a diluent" -- nothing else in [ensure] looks
  /// at segments once a role is decided, so the remap has to happen here,
  /// against the tanks [ensure] actually returned, not the input.
  static DivePlanState _withCcrSlots(DivePlanState s) {
    if (s.mode != domain.PlanMode.ccr) return s;
    final slots = const CcrLoopSlots().ensure(
      s.tanks,
      segments: s.segments,
      newId: _uuid.v4,
    );
    var segmentsChanged = false;
    final segments = [
      for (final segment in s.segments)
        () {
          final mapped = _segmentOnDiluent(segment, slots.tanks);
          if (!identical(mapped, segment)) segmentsChanged = true;
          return mapped;
        }(),
    ];
    if (!slots.changed && !segmentsChanged) return s;
    return s.copyWith(tanks: slots.tanks, segments: segments);
  }

  /// The plan's diluent cylinders, in list order.
  static List<DiveTank> _diluents(List<DiveTank> tanks) =>
      tanks.where((t) => t.role == TankRole.diluent).toList();

  /// [segment] as it is when it already breathes one of [tanks]' diluents,
  /// else moved onto the first diluent, mix and all -- the free-standing
  /// form [_withCcrSlots] uses, against a tank list it computed itself
  /// rather than `state.tanks` (which [updateMode] has not yet committed
  /// at the point it needs this).
  static PlanSegment _segmentOnDiluent(
    PlanSegment segment,
    List<DiveTank> tanks,
  ) {
    final diluents = _diluents(tanks);
    if (diluents.isEmpty || diluents.any((t) => t.id == segment.tankId)) {
      return segment;
    }
    final first = diluents.first;
    return segment.copyWith(tankId: first.id, gasMix: first.gasMix);
  }

  /// On a CCR plan every segment breathes a diluent: [segment] as it is
  /// when it already does, else moved onto the first diluent, mix and all.
  /// The editor only offers diluents there, so this is the backstop for a
  /// segment authored before the tank it names stopped being one.
  PlanSegment _onDiluent(PlanSegment segment) {
    if (state.mode != domain.PlanMode.ccr) return segment;
    return _segmentOnDiluent(segment, state.tanks);
  }

  /// The cylinder a new segment starts on: the first diluent on a CCR plan,
  /// the first cylinder otherwise.
  DiveTank _defaultSegmentTank() {
    if (state.mode == domain.PlanMode.ccr) {
      final diluents = _diluents(state.tanks);
      if (diluents.isNotEmpty) return diluents.first;
    }
    return state.tanks.first;
  }

  /// Load a persisted plan by id. Returns false when it does not exist.
  Future<bool> loadPlanById(String planId) async {
    final repository = _repository;
    if (repository == null) return false;
    final plan = await repository.getPlan(planId);
    if (plan == null || !mounted) return false;
    _loaded = plan;
    state = _withCcrSlots(stateFromDivePlan(plan));
    final mission = plan.mission;
    if (mission != null) {
      // A scooter picked from equipment follows the live item; a manual or
      // deleted one keeps the numbers stored with the plan.
      final live = MissionEdits.withLiveScooters(
        mission,
        await _liveEquipment(plan.id),
      );
      if (!mounted) return false;
      // Regenerated once, so the profile always matches the mission it was
      // saved with; an edit made while the equipment loaded wins.
      if (state.mission == mission) _setMission(live, markDirty: false);
    }
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
    final segments = [...state.segments, _onDiluent(segment)];
    _updateSegmentOrders(segments);
    state = state.copyWith(
      segments: segments,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Update an existing segment.
  void updateSegment(String id, PlanSegment segment) {
    final updated = _onDiluent(segment);
    final segments = state.segments.map((s) {
      return s.id == id ? updated : s;
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

    final tank = _defaultSegmentTank();
    final segments = <PlanSegment>[
      // Descends at the plan's own rate. The old call used PlanSegment
      // .descent without passing one, so the quick plan always dropped at
      // the factory's hardcoded 18 m/min and ignored the rate field. An
      // unset rate follows the diver's Settings (issue #3552).
      PlanSegment.travel(
        id: _uuid.v4(),
        fromDepth: 0,
        targetDepth: maxDepth,
        ratePerMinute: state.descentRate ?? _getEngineConfig().descentRate,
        tankId: tank.id,
        gasMix: tank.gasMix,
        order: 0,
      ),
      PlanSegment.hold(
        id: _uuid.v4(),
        depth: maxDepth,
        durationMinutes: bottomTimeMinutes,
        tankId: tank.id,
        gasMix: tank.gasMix,
        order: 1,
      ),
    ];

    // A quick plan replaces the whole profile, so it also ends a DPV mission
    // that was generating the old one.
    state = state.copyWith(
      segments: segments,
      clearMission: true,
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
    state = _withMissionSegments(
      state.copyWith(tanks: tanks, isDirty: true, updatedAt: DateTime.now()),
    );
  }

  /// Replace the equipment attached to the plan (Gear & Weights, v104).
  ///
  /// Provenance follows the ids so the two never drift (#1487): an id that
  /// survives keeps its row, a new id starts as a loose row, and a dropped
  /// id takes its row with it.
  void setEquipmentIds(List<String> ids) {
    final byId = {for (final p in state.gearProvenance) p.equipmentId: p};
    setGear(ids, [
      for (final id in ids) byId[id] ?? GearProvenance(equipmentId: id),
    ]);
  }

  /// Replace the gear and its provenance in one step, so the ids and their
  /// assembly and set pointers never disagree (issue #1487).
  void setGear(List<String> ids, List<GearProvenance> provenance) {
    state = state.copyWith(
      equipmentIds: ids,
      gearProvenance: provenance,
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

  /// Set (or clear, with `seconds: null` or `<= 0`) the diver-authored
  /// minimum hold time for the stop at [depthMeters].
  ///
  /// Immutable map update: builds a new map rather than mutating
  /// [state.stopMinimums] in place.
  void setStopMinimum(int depthMeters, int? seconds) {
    final updated = Map<int, int>.from(state.stopMinimums);
    if (seconds == null || seconds <= 0) {
      updated.remove(depthMeters);
    } else {
      updated[depthMeters] = seconds;
    }
    state = state.copyWith(
      stopMinimums: updated,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Update an existing tank.
  ///
  /// On a CCR plan the two loop slots keep their identity through an edit
  /// (#3220): the oxygen slot stays the oxygen supply on 100 %, and the only
  /// diluent stays diluent -- the editor does not offer those changes, so
  /// this is the backstop that keeps the plan from losing a slot.
  void updateTank(String id, DiveTank tank) {
    var updated = tank;
    if (state.mode == domain.PlanMode.ccr) {
      final original = state.tanks.where((t) => t.id == id).firstOrNull;
      if (original?.role == TankRole.oxygenSupply) {
        updated = updated.copyWith(
          role: TankRole.oxygenSupply,
          gasMix: const GasMix(o2: 100),
        );
      } else if (original?.role == TankRole.diluent &&
          updated.role != TankRole.diluent &&
          _diluents(state.tanks).length == 1) {
        updated = updated.copyWith(role: TankRole.diluent);
      }
    }
    final tanks = state.tanks.map((t) {
      return t.id == id ? updated : t;
    }).toList();

    // Also update gas mix in segments using this tank
    final segments = state.segments.map((s) {
      if (s.tankId == id) {
        return s.copyWith(gasMix: updated.gasMix);
      }
      return s;
    }).toList();

    state = _withMissionSegments(
      state.copyWith(
        tanks: tanks,
        segments: segments,
        isDirty: true,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Remove a tank from the plan.
  ///
  /// On a CCR plan the oxygen slot and the last diluent cannot go (#3220):
  /// the chip offers no delete for them, and this is the backstop.
  void removeTank(String id) {
    // Don't allow removing the last tank
    if (state.tanks.length <= 1) return;
    final removed = state.tanks.where((t) => t.id == id).firstOrNull;
    if (removed == null) return;
    if (state.mode == domain.PlanMode.ccr) {
      if (removed.role == TankRole.oxygenSupply) return;
      if (removed.role == TankRole.diluent &&
          _diluents(state.tanks).length == 1) {
        return;
      }
    }

    final tanks = state.tanks.where((t) => t.id != id).toList();

    // Reassign segments using the removed tank: to the first diluent on a
    // CCR plan, to the first tank otherwise.
    final fallback = state.mode == domain.PlanMode.ccr
        ? (_diluents(tanks).firstOrNull ?? tanks.first)
        : tanks.first;
    final segments = state.segments.map((s) {
      if (s.tankId == id) {
        return s.copyWith(tankId: fallback.id, gasMix: fallback.gasMix);
      }
      return s;
    }).toList();

    state = _withMissionSegments(
      state.copyWith(
        tanks: tanks,
        segments: segments,
        isDirty: true,
        updatedAt: DateTime.now(),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Settings
  // --------------------------------------------------------------------------

  /// Update gradient factors. Null clears back to the diver's Settings
  /// default (issue #3552, follow-up to v304-307).
  void updateGradientFactors(int? gfLow, int? gfHigh) {
    state = state.copyWith(
      gfLow: gfLow,
      clearGfLow: gfLow == null,
      gfHigh: gfHigh,
      clearGfHigh: gfHigh == null,
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

  /// Clear the SAC rate override, falling back to the diver's Settings
  /// default (issue #3552).
  void clearSacRate() {
    state = state.copyWith(
      clearSacRate: true,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Update any of the four ascent rates, or the descent rate, in meters per
  /// minute. [intermediate] applies between stops deeper than 9 m, [shallow]
  /// between the 9 m and shallower stops, and [finalStretch] from the last
  /// stop to the surface.
  ///
  /// Each is a plan-level override of the diver's Settings default (issue
  /// #3552): a caller passes its concrete value to set one, or omits it (the
  /// default `null`) to leave it as-is - never to clear it, since
  /// [DivePlanState.copyWith]'s own `??` fallback cannot otherwise tell "not
  /// touched" apart from "cleared". Clearing one back to "follow Settings"
  /// goes through the matching `clearX` flag instead.
  void updateRates({
    double? ascent,
    bool clearAscent = false,
    double? intermediate,
    bool clearIntermediate = false,
    double? shallow,
    bool clearShallow = false,
    double? finalStretch,
    bool clearFinalStretch = false,
    double? descent,
    bool clearDescent = false,
  }) {
    state = _withMissionSegments(
      state.copyWith(
        ascentRate: ascent,
        clearAscentRate: clearAscent,
        intermediateAscentRate: intermediate,
        clearIntermediateAscentRate: clearIntermediate,
        shallowAscentRate: shallow,
        clearShallowAscentRate: clearShallow,
        finalAscentRate: finalStretch,
        clearFinalAscentRate: clearFinalStretch,
        descentRate: descent,
        clearDescentRate: clearDescent,
        isDirty: true,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Shallowest metres allowed for the last deco stop.
  static const double minLastStopDepth = 3.0;

  /// Deepest metres allowed for the last deco stop.
  static const double maxLastStopDepth = 6.0;

  /// Set where the final decompression stop is held, 3 to 6 m. It need not
  /// sit on the 3 m grid: the schedule follows the grid down to 6 m and then
  /// holds this depth. Null clears the override back to the diver's
  /// Settings default (issue #3552).
  void updateLastStopDepth(double? meters) {
    final clamped = meters?.clamp(minLastStopDepth, maxLastStopDepth);
    if (clamped == state.lastStopDepth) return;
    state = state.copyWith(
      lastStopDepth: clamped,
      clearLastStopDepth: clamped == null,
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

  /// Update water type for decompression density. Null clears the choice and
  /// leaves the plan on the planner's salt-water fallback.
  /// Clears a custom salinity so a preset is not mixed with an override.
  void updateWaterType(WaterType? waterType) {
    state = state.copyWith(
      waterType: waterType,
      clearWaterType: waterType == null,
      clearSalinityPpt: true,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Switch to custom salinity (ppt). Seeds seawater (35 ppt) when the plan
  /// has no value yet, or the equivalent of a leftover brackish type.
  void selectCustomSalinity() {
    final seed =
        state.salinityPpt ??
        (state.waterType == null
            ? DiveEnvironment.typicalSeaSalinityPpt
            : DiveEnvironment.salinityPptFromDensity(
                DiveEnvironment.forConditions(
                  waterType: state.waterType,
                ).waterDensityKgM3,
              ));
    updateSalinityPpt(seed);
  }

  /// Custom salinity in ppt. Clears [DivePlanState.waterType] so density
  /// comes only from this value.
  void updateSalinityPpt(double? salinityPpt) {
    state = state.copyWith(
      salinityPpt: salinityPpt,
      clearSalinityPpt: salinityPpt == null,
      clearWaterType: true,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Set the air-break (back-gas break) policy for long O2 deco stops; null
  /// disables air breaks.
  /// [explicitlyOff] true forces no air breaks regardless of the diver's
  /// Settings default; false with a null [policy] follows that default
  /// instead (issue #3552).
  void setAirBreaks(AirBreakPolicy? policy, {bool explicitlyOff = false}) {
    state = state.copyWith(
      airBreaks: policy,
      clearAirBreaks: policy == null,
      airBreaksExplicitlyOff: explicitlyOff,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Update reserve pressure in bar.
  /// Null clears back to the diver's Settings default (issue #3552,
  /// follow-up to v304-307).
  void updateReservePressure(double? reservePressure) {
    state = state.copyWith(
      reservePressure: reservePressure,
      clearReservePressure: reservePressure == null,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Update the Subsurface-style Gas options; only supplied values change.
  /// [sacDeco], [sacStressed], [sacFactor], [problemSolvingMinutes],
  /// [gasSwitchStopSeconds], [ppO2Bottom], [ppO2Deco], [bestMixEndMeters]
  /// and [o2Narcotic] are nullable overrides of the diver's Settings - pass
  /// the matching `clear*` flag to fall back again. [sacStressed] falls
  /// back to [sacDeco]'s sibling bottom-SAC-times-factor default rather
  /// than a plain Settings value (issue #3552).
  void updateGasOptions({
    double? sacDeco,
    bool clearSacDeco = false,
    double? sacStressed,
    bool clearSacStressed = false,
    double? sacFactor,
    bool clearSacFactor = false,
    int? problemSolvingMinutes,
    bool clearProblemSolvingMinutes = false,
    int? gasSwitchStopSeconds,
    bool clearGasSwitchStopSeconds = false,
    double? ppO2Bottom,
    bool clearPpO2Bottom = false,
    double? ppO2Deco,
    bool clearPpO2Deco = false,
    double? bestMixEndMeters,
    bool clearBestMixEndMeters = false,
    bool? o2Narcotic,
    bool clearO2Narcotic = false,
  }) {
    state = state.copyWith(
      sacDeco: sacDeco,
      clearSacDeco: clearSacDeco,
      sacStressed: sacStressed,
      clearSacStressed: clearSacStressed,
      sacFactor: sacFactor,
      clearSacFactor: clearSacFactor,
      problemSolvingMinutes: problemSolvingMinutes,
      clearProblemSolvingMinutes: clearProblemSolvingMinutes,
      gasSwitchStopSeconds: gasSwitchStopSeconds,
      clearGasSwitchStopSeconds: clearGasSwitchStopSeconds,
      ppO2Bottom: ppO2Bottom,
      clearPpO2Bottom: clearPpO2Bottom,
      ppO2Deco: ppO2Deco,
      clearPpO2Deco: clearPpO2Deco,
      bestMixEndMeters: bestMixEndMeters,
      clearBestMixEndMeters: clearBestMixEndMeters,
      o2Narcotic: o2Narcotic,
      clearO2Narcotic: clearO2Narcotic,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Switch between open circuit and CCR.
  ///
  /// Entering CCR seeds each setpoint still null (a fresh plan, one that has
  /// never been in CCR mode, or one with only a hand-set half) from the
  /// diver's own CCR ppO2 limits, independently per field. A setpoint the
  /// diver already set (low or high, on its own) is never overwritten. A
  /// null setpoint would still compute with the diver's Settings (the
  /// engine's own fallback, issue #2801); the seed pins the values the plan
  /// was built with, so a later Settings change does not move a plan the
  /// diver has already started editing in CCR.
  ///
  /// Unlike [adoptPlannerWaterIfPristine], there is no later "adopt if
  /// pristine" for these settings: switching mode is itself a diver edit and
  /// already sets `isDirty`, so a plan can never be both in CCR mode and
  /// pristine, and there is nothing left for a later settings change to
  /// adopt into.
  ///
  /// Known limitation: a setpoint is seeded only once, the first time its
  /// field is still null while entering CCR, so cycling CCR -> OC -> CCR
  /// keeps that first seed even if the diver's Settings changed in between.
  /// Clearing on exit would fix that but would also wipe a hand-tuned
  /// setpoint on every OC/SCR/pSCR step of the mode-cycle button, a worse
  /// regression for a rarer case.
  void updateMode(domain.PlanMode mode) {
    final defaults =
        mode == domain.PlanMode.ccr &&
            (state.setpointLow == null || state.setpointHigh == null)
        ? _getDefaultCcrSetpoints()
        : null;
    // Entering CCR fills the two mandatory loop slots (#3220): diluent and
    // oxygen supply, adopted from what the plan already carries or added
    // as placeholders. SCR/PSCR keep the older convenience only: diluent is
    // the diver's explicit per-tank choice there (#3135), and entering with
    // nothing marked yet marks the tank(s) the plan already breathes, once.
    var tanks = state.tanks;
    var segments = state.segments;
    if (mode == domain.PlanMode.ccr) {
      tanks = const CcrLoopSlots()
          .ensure(tanks, segments: segments, newId: _uuid.v4)
          .tanks;
      // Claiming the oxygen slot can take a cylinder an existing segment
      // already breathes (an ordinary OC/SCR O2 deco bottle, say) -- so
      // every segment is remapped onto a diluent against the tanks just
      // computed, the same backstop _onDiluent applies to a later edit
      // (see _withCcrSlots for why this cannot be skipped just because
      // the slots themselves were already both present).
      segments = [
        for (final segment in segments) _segmentOnDiluent(segment, tanks),
      ];
    } else if (mode != domain.PlanMode.oc &&
        !tanks.any((t) => t.role == TankRole.diluent)) {
      final breathedIds = state.segments.map((s) => s.tankId).toSet();
      tanks = [
        for (final tank in tanks)
          breathedIds.contains(tank.id)
              ? tank.copyWith(role: TankRole.diluent)
              : tank,
      ];
    }
    state = state.copyWith(
      mode: mode,
      tanks: tanks,
      segments: segments,
      setpointLow: state.setpointLow ?? defaults?.low,
      setpointHigh: state.setpointHigh ?? defaults?.high,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Update CCR setpoints; only supplied values change.
  void updateSetpoints({
    double? low,
    bool clearLow = false,
    double? high,
    bool clearHigh = false,
    double? switchDepth,
    bool clearSwitchDepth = false,
  }) {
    state = state.copyWith(
      setpointLow: low,
      clearSetpointLow: clearLow,
      setpointHigh: high,
      clearSetpointHigh: clearHigh,
      setpointSwitchDepth: switchDepth,
      clearSetpointSwitchDepth: clearSwitchDepth,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Update contingency configuration; only supplied values change.
  void updateContingencies({
    double? depthDelta,
    bool clearDepthDelta = false,
    int? timeMinutes,
    bool clearTimeMinutes = false,
    domain.TurnPressureRule? turnRule,
    double? turnFraction,
    bool clearTurnRule = false,
  }) {
    state = state.copyWith(
      deviationDepthDelta: depthDelta,
      clearDeviationDepthDelta: clearDepthDelta,
      deviationTimeMinutes: timeMinutes,
      clearDeviationTimeMinutes: clearTimeMinutes,
      turnPressureRule: turnRule,
      turnPressureFraction: turnFraction,
      clearTurnPressureRule: clearTurnRule,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  // --------------------------------------------------------------------------
  // DPV mission (issue #2086)
  // --------------------------------------------------------------------------

  /// Turns the plan into a DPV mission, starting from [starter].
  void enableMission(DpvMission starter) => _setMission(starter);

  /// Replaces the mission and regenerates the plan's segments from it.
  void updateMission(DpvMission mission) => _setMission(mission);

  /// Applies [edit] to the mission as it is now, not as a widget last saw
  /// it: a value committed between a build and a callback survives. Does
  /// nothing when no mission is on.
  void editMission(DpvMission Function(DpvMission current) edit) {
    final current = state.mission;
    if (current == null) return;
    final next = edit(current);
    // An edit that changes nothing (0 typed over no current) is not a change
    // to save.
    if (next == current) return;
    _setMission(next);
  }

  /// Turns the mission off. The segments it last generated stay as ordinary
  /// segments the diver can edit.
  void disableMission() {
    state = state.copyWith(
      clearMission: true,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  void _setMission(DpvMission mission, {bool markDirty = true}) {
    state = _withMissionSegments(
      state.copyWith(
        mission: mission,
        isDirty: markDirty ? true : state.isDirty,
        updatedAt: markDirty ? DateTime.now() : state.updatedAt,
      ),
    );
  }

  /// [s] with its segments regenerated from its mission, when it has one.
  /// The generated profile also reads the plan's tanks and rates, so every
  /// edit to those passes through here too. An unset rate resolves against
  /// the diver's current Settings (issue #3552).
  DivePlanState _withMissionSegments(DivePlanState s) {
    final mission = s.mission;
    if (mission == null) return s;
    return s.copyWith(
      segments: MissionEngine(
        scenarios: MissionScenarioService(
          engine: PlanEngine(config: _getEngineConfig()),
        ),
      ).roundTripSegments(plan: divePlanFromState(s), mission: mission),
    );
  }

  /// The diver's equipment, or none when it cannot be read: a mission's
  /// stored scooters are complete, so the plan still opens.
  Future<List<EquipmentItem>> _liveEquipment(String planId) async {
    try {
      return await _loadEquipment();
    } catch (e, stackTrace) {
      _log.warning(
        'Could not load equipment to refresh the scooters of plan $planId; '
        'using the stored ones',
        error: e,
        stackTrace: stackTrace,
      );
      return const [];
    }
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
    final submitted = state;
    final plan = divePlanFromState(submitted, existing: _loaded);
    final stored = await repository.savePlan(plan, summary: summary);
    _loaded = stored;
    if (!mounted) return;
    // The repository drops a site or dive that no longer exists rather than
    // failing the save (issues #1985 and #2006), so adopt what it stored:
    // otherwise the planner keeps offering a row the database no longer holds.
    // Each is guarded on the id still being the one that was sent, because the
    // diver can pick another during the save's async gap and that newer choice
    // wins. The references are independent, so one can go while another stays.
    final siteWentAway = stored.siteId == null && state.siteId == plan.siteId;
    final sourceDiveWentAway =
        stored.sourceDiveId == null && state.sourceDiveId == plan.sourceDiveId;
    final linkedDiveWentAway =
        stored.linkedDiveId == null && state.linkedDiveId == plan.linkedDiveId;
    // A dropped source dive takes the context it seeded, as clearFollowedDive
    // does. The tissues are never stored, so leaving them would keep seeding
    // deco for a plan that no longer follows a dive, and the schedule would
    // change silently on the next reload. The repository drops the surface
    // interval with the dive. Each keeps the same guard: tissues or an
    // interval the diver set during the async gap are a newer choice.
    final tissuesWentAway =
        sourceDiveWentAway &&
        identical(state.initialTissueState, submitted.initialTissueState);
    final surfaceIntervalWentAway =
        stored.surfaceInterval == null &&
        state.surfaceInterval == plan.surfaceInterval;
    // What was written describes the plan as it was submitted, so an edit made
    // during that async gap is not in the database and the plan is still
    // dirty. Clearing the flag unconditionally disables Save and strands the
    // edit until the diver happens to touch the plan again. Every mutator
    // assigns a fresh state, so reference identity answers this exactly,
    // without depending on the resolution of the clock behind updatedAt.
    final editedDuringSave = !identical(state, submitted);
    state = state.copyWith(
      isDirty: editedDuringSave,
      clearSiteId: siteWentAway,
      clearSourceDiveId: sourceDiveWentAway,
      clearInitialTissueState: tissuesWentAway,
      clearSurfaceInterval: surfaceIntervalWentAway,
      clearLinkedDiveId: linkedDiveWentAway,
    );
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

    for (final leg in const SegmentChain().resolve(state.segments)) {
      if (leg.endDepth > maxDepth) maxDepth = leg.endDepth;
      totalDepthTime += leg.avgDepth * leg.durationSeconds;
      totalTime += leg.durationSeconds;
    }

    final avgDepth = totalTime > 0 ? totalDepthTime / totalTime : 0.0;

    return Dive(
      id: _uuid.v4(),
      name: state.name,
      dateTime: state.startDateTime ?? DateTime.now(),
      runtime: Duration(seconds: totalTime),
      maxDepth: maxDepth,
      avgDepth: avgDepth,
      tanks: [for (final tank in state.tanks) tank.copyWith(id: '')],
      profile: profilePoints,
      notes: state.notes,
      altitude: state.altitude,
      waterType: state.waterType,
      gradientFactorLow: state.gfLow,
      gradientFactorHigh: state.gfHigh,
      isPlanned: true,
    );
  }
}

/// Provider for the dive plan notifier.
///
/// This provider must never rebuild: rebuilding a StateNotifierProvider
/// constructs a new notifier, which throws away the plan the diver is editing.
/// Everything it needs is therefore resolved with `read` rather than `watch` --
/// settings through closures evaluated when a new plan is created, and
/// [planCalculatorServiceProvider] once at construction. Watching the latter
/// rebound the notifier on every deco settings change, silently discarding an
/// in-progress plan.
final divePlanNotifierProvider =
    StateNotifierProvider<DivePlanNotifier, DivePlanState>((ref) {
      final read = ref.read;
      final calculator = read(planCalculatorServiceProvider);
      // A plan entering CCR mode starts on the diver's own CCR ppO2 limits.
      CcrSetpoints defaultCcrSetpoints() => (
        low: read(ccrSetpointLowProvider),
        high: read(ccrSetpointHighProvider),
      );

      final notifier = DivePlanNotifier(
        calculator,
        getEngineConfig: () => read(planEngineConfigProvider),
        getDefaultPlannerWaterType: () =>
            read(settingsProvider).defaultPlannerWaterType,
        getDefaultCcrSetpoints: defaultCcrSetpoints,
        repository: read(divePlanRepositoryProvider),
        loadEquipment: () => read(allEquipmentProvider.future),
      );

      // `listen`, never `watch`: this reacts to settings without rebuilding.
      // No GF listener here any more - gfLow/gfHigh live-resolve on every
      // computation (issue #3552), so there is nothing to push into state.
      ref.listen<PlannerWaterType>(
        settingsProvider.select((s) => s.defaultPlannerWaterType),
        (_, next) => notifier.adoptPlannerWaterIfPristine(next),
      );

      return notifier;
    });

// ============================================================================
// Computed Providers
// ============================================================================

/// Provider for auto-calculated plan results.
///
/// This automatically recalculates whenever the plan state changes.
///
/// The gradient factors come from the plan, not the settings: the plan is
/// seeded from the diver's settings but is editable per plan. Computing them
/// on the settings pair would judge a plan by factors it is not using, and
/// diverge from the plan outcome the canvas displays.
final planResultsProvider = Provider<PlanResult>((ref) {
  final state = ref.watch(divePlanNotifierProvider);
  // The plan's own values, else the diver's Settings defaults (#3552).
  final resolved = ref.watch(resolvedPlanEngineConfigProvider);
  final calculator = ref
      .watch(planCalculatorServiceProvider)
      .withGradientFactors(resolved.gfLow, resolved.gfHigh);

  if (state.segments.isEmpty) {
    return PlanResult.empty();
  }

  return calculator.calculatePlan(
    segments: state.segments,
    tanks: state.tanks,
    sacRate: resolved.sacBottom,
    reservePressure: resolved.reservePressure,
    initialTissueState: state.initialTissueState,
    // Altitude 0 keeps the legacy sea-level surface pressure. Null water
    // type is salt, matching the planner default - though a custom salinity,
    // when set, overrides either one (see DiveEnvironment's precedence).
    environment: DiveEnvironment.forConditions(
      altitudeMeters: (state.altitude ?? 0) > 0 ? state.altitude : null,
      waterType: state.waterType ?? WaterType.salt,
      salinityPpt: state.salinityPpt,
    ),
  );
});

/// Provider for generated profile points (for charting).
final planProfilePointsProvider = Provider<List<DiveProfilePoint>>((ref) {
  final state = ref.watch(divePlanNotifierProvider);
  final calculator = ref.watch(planCalculatorServiceProvider);

  return calculator.generateProfilePoints(state.segments);
});

// ============================================================================
// Selection/UI State Providers
// ============================================================================

/// Currently selected segment for editing.
final selectedSegmentIdProvider = StateProvider<String?>((ref) => null);

/// Whether the simple plan dialog is shown.
final showSimplePlanDialogProvider = StateProvider<bool>((ref) => false);
