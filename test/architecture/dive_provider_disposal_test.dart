import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_3d/application/compare_providers.dart'
    as dive_3d;
import 'package:submersion/features/dive_3d/application/providers.dart';
import 'package:submersion/features/dive_3d/application/spatial_providers.dart';
import 'package:submersion/features/dive_3d/application/tissue_providers.dart';
import 'package:submersion/features/dive_lab/presentation/providers/compare_providers.dart'
    as lab;
import 'package:submersion/features/dive_lab/presentation/providers/lab_draft_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/buoyancy_history_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/buoyancy_twin_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/chart_tank_pressures_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_analysis_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/outlier_suggestion_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_logged_dive_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_overlay_provider.dart';

/// Per-dive families holding decoded samples or analyses must auto-dispose
/// (#4254).
///
/// Riverpod 3 defaults `isAutoDispose` to false, so a `.family` keyed per dive
/// keeps one entry per dive for the process lifetime. For these that entry is
/// a full detail dive, a source's samples, or a `ProfileAnalysis` with 16
/// compartment states per sample, so every dive a session opened stayed in
/// memory. Each now auto-disposes and calls `retainDiveData`, which keeps it
/// warm for a window after its last listener leaves.
///
/// The list covers the heavy families and every per-dive family that watches
/// one. A keep-forever watcher holds its dependency alive as surely as the
/// dependency keeping itself, so adding a per-dive family that watches any of
/// these means adding it here too.
///
/// Asserted through `dynamic` for the reason given in
/// `media_provider_disposal_test.dart`: the declaring type of
/// `isAutoDispose` is not exported.
void main() {
  final mustAutoDispose = <String, dynamic>{
    // The decoded dive and its samples.
    'diveProvider': diveProvider,
    'diveProfileProvider': diveProfileProvider,
    'sourceProfilesProvider': sourceProfilesProvider,
    'tankPressuresProvider': tankPressuresProvider,
    // The analysis pipeline.
    'analysisDiveProvider': analysisDiveProvider,
    'diveAnalysisSeriesProvider': diveAnalysisSeriesProvider,
    'profileAnalysisProvider': profileAnalysisProvider,
    'sourceProfileAnalysisProvider': sourceProfileAnalysisProvider,
    'residualCnsProvider': residualCnsProvider,
    'residualTissueStateProvider': residualTissueStateProvider,
    'diveProfileAnalysisProvider': diveProfileAnalysisProvider,
    'profileQuickStatsProvider': profileQuickStatsProvider,
    // Dive detail sections that watch them.
    'outlierSuggestionProvider': outlierSuggestionProvider,
    'estimatedTankPressuresProvider': estimatedTankPressuresProvider,
    'buoyancyTwinProvider': buoyancyTwinProvider,
    'buoyancyHistoryProvider': buoyancyHistoryProvider,
    'gasSwitchSegmentsProvider': gasSwitchSegmentsProvider,
    'phaseSegmentsProvider': phaseSegmentsProvider,
    'cylinderSacProvider': cylinderSacProvider,
    'isMultiTankDiveProvider': isMultiTankDiveProvider,
    'safetyReviewProvider': safetyReviewProvider,
    'trackForDiveProvider': trackForDiveProvider,
    // 3D views.
    'dive3dSceneDataProvider': dive3dSceneDataProvider,
    'dive3dZAxisProvider': dive3dZAxisProvider,
    'dive3dGeometryProvider': dive3dGeometryProvider,
    'tissueDecoStatusesProvider': tissueDecoStatusesProvider,
    'tissueSurfaceProvider': tissueSurfaceProvider,
    'tissue3dSceneProvider': tissue3dSceneProvider,
    'tissueSurfaceGridProvider': tissueSurfaceGridProvider,
    'tissueRuntimeSecondsProvider': tissueRuntimeSecondsProvider,
    'computerComparisonProfilesProvider':
        dive_3d.computerComparisonProfilesProvider,
    'spatialReckonedPathProvider': spatialReckonedPathProvider,
    'spatialGeometryProvider': spatialGeometryProvider,
    // Dive Lab and the planner's plan-vs-actual views.
    'hasLinkedPlanProvider': lab.hasLinkedPlanProvider,
    'plannedColumnProvider': lab.plannedColumnProvider,
    'labDefaultBranchProvider': labDefaultBranchProvider,
    'labRequestInputsProvider': labRequestInputsProvider,
    'linkedPlanComparisonProvider': linkedPlanComparisonProvider,
    'plannedProfileOverlayProvider': plannedProfileOverlayProvider,
    'linkedPlanRangeTableProvider': linkedPlanRangeTableProvider,
    'seriesFollowProvider': seriesFollowProvider,
    // Per buddy, but holds hydrated dives.
    'divesForBuddyProvider': divesForBuddyProvider,
  };

  for (final entry in mustAutoDispose.entries) {
    test('${entry.key} auto-disposes', () {
      expect(
        entry.value.isAutoDispose,
        isTrue,
        reason:
            '${entry.key} holds a dive\'s decoded samples or analysis, or '
            'watches a provider that does. Riverpod 3 keeps a family entry '
            'forever unless the provider passes isAutoDispose: true, so every '
            'dive a session visits would stay in memory.',
      );
    });
  }
}
