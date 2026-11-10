import 'package:flutter/material.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/info/dive_profile_info.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart_host.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/info_sheet/info_button.dart';

/// The dive log's chart, pared back for a dive shown in the planner: depth,
/// NDL, deco stops and the ceiling, and nothing else until the diver turns
/// it on. Scoped to the view, so the dive log keeps its own choices.
final loggedDiveChartOverrides = [
  profileLegendProvider.overrideWith(_LoggedDiveLegend.new),
  showMaxDepthMarkerProvider.overrideWithValue(false),
  showPressureThresholdMarkersProvider.overrideWithValue(false),
];

class _LoggedDiveLegend extends ProfileLegend {
  @override
  ProfileLegendState build() => super.build().copyWith(
    // The right axis reads NDL, not the temperature it would default to.
    rightAxisMetric: ProfileRightAxisMetric.ndl,
    showNdl: true,
    showDecoStops: true,
    showCeiling: true,
    showTemperature: false,
    showPressure: false,
    showTankPressure: const {},
    showGas: false,
    showHeartRate: false,
    showSac: false,
    showAscentRateColors: false,
    showAscentRateLine: false,
    showEvents: false,
    showComputedEvents: false,
    showMaxDepthMarker: false,
    showPressureMarkers: false,
    showGasSwitchMarkers: false,
    showLateGasSwitches: false,
    showPhotoMarkers: false,
    showPpO2: false,
    showPpN2: false,
    showPpHe: false,
    showMod: false,
    showDensity: false,
    showGf: false,
    showSurfaceGf: false,
    showMeanDepth: false,
    showTts: false,
    showCns: false,
    showOtu: false,
    showO2Cells: false,
    showGtr: false,
  );
}

/// The profile of the logged dive [diveId] (issue #3565), in the planner's
/// chart slot: the dive log's chart, which also ghosts the plan the dive was
/// dived from, when it has one.
class LoggedDiveChart extends ConsumerWidget {
  const LoggedDiveChart({super.key, required this.diveId});

  final String diveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ref
        .watch(diveProvider(diveId))
        .when(
          // A reload keeps the chart, with its zoom and toggles.
          skipLoadingOnReload: true,
          data: (dive) => dive == null || dive.profile.isEmpty
              ? _Placeholder(message: l10n.dashboard_recentDives_noProfileData)
              : ProviderScope(
                  overrides: loggedDiveChartOverrides,
                  child: ProfileLegendSnapshotScope(
                    child: DiveProfileChartHost(
                      dive: dive,
                      legendLeading: HeaderInfoButton(
                        title: l10n.diveLog_detail_section_diveProfile,
                        height: 40,
                        width: 40,
                        content: diveProfileInfoFor,
                      ),
                    ),
                  ),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _Placeholder(
            message: l10n.dashboard_recentDives_profileLoadError,
          ),
        );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
