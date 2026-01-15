import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_planner/data/services/plan_calculator_service.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';

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
  );
});

// ============================================================================
// State Notifiers
// ============================================================================

/// StateNotifier for managing dive plan editing state.
class DivePlanNotifier extends StateNotifier<DivePlanState> {
  final PlanCalculatorService _calculator;

  DivePlanNotifier(this._calculator) : super(_createInitialState());

  static DivePlanState _createInitialState() {
    final now = DateTime.now();
    return DivePlanState(
      id: _uuid.v4(),
      name: 'New Dive Plan',
      segments: [],
      tanks: [_createDefaultTank()],
      createdAt: now,
      updatedAt: now,
    );
  }

  static DiveTank _createDefaultTank() {
    return DiveTank(
      id: _uuid.v4(),
      name: 'Primary',
      volume: 11.1, // AL80
      workingPressure: 207,
      startPressure: 200,
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
    state = _createInitialState();
  }

  /// Load an existing plan for editing.
  void loadPlan(DivePlanState plan) {
    state = plan;
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
    if (newIndex > oldIndex) newIndex--;
    final segment = segments.removeAt(oldIndex);
    segments.insert(newIndex, segment);
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

  /// Add a simple dive profile (descent + bottom + ascent).
  void addSimplePlan({
    required double maxDepth,
    required int bottomTimeMinutes,
  }) {
    if (state.tanks.isEmpty) return;

    final tank = state.tanks.first;
    final segments = _calculator.createSimplePlan(
      maxDepth: maxDepth,
      bottomTimeMinutes: bottomTimeMinutes,
      tank: tank,
    );

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

  /// Update dive site.
  void updateSite(String? siteId) {
    state = state.copyWith(
      siteId: siteId,
      clearSiteId: siteId == null,
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

  /// Load tissue state from a previous dive (for repetitive planning).
  void loadTissueFromDive(Dive previousDive) {
    // This would require accessing the profile analysis to get end tissue state
    // For now, we'll just set the surface interval
    if (previousDive.dateTime.isBefore(DateTime.now())) {
      final interval = DateTime.now().difference(previousDive.dateTime);
      setSurfaceInterval(interval);
    }
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

  /// Mark the plan as saved.
  void markSaved() {
    state = state.copyWith(isDirty: false);
  }

  /// Convert the plan to a Dive entity for saving.
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
      id: state.id,
      dateTime: DateTime.now(),
      duration: Duration(seconds: totalTime),
      maxDepth: maxDepth,
      avgDepth: avgDepth,
      tanks: state.tanks,
      profile: profilePoints,
      notes: state.notes,
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
      return DivePlanNotifier(calculator);
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
    initialTissueState: state.initialTissueState,
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

/// Currently selected tab index in planner page.
final plannerTabIndexProvider = StateProvider<int>((ref) => 0);

/// Whether the simple plan dialog is shown.
final showSimplePlanDialogProvider = StateProvider<bool>((ref) => false);
