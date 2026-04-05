import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Fixed-height panel that displays the dive profile chart for the currently
/// highlighted dive. Shows an empty state when no dive is selected.
class DiveProfilePanel extends ConsumerWidget {
  const DiveProfilePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlightedId = ref.watch(highlightedDiveIdProvider);

    if (highlightedId == null) {
      return _buildEmptyState(context);
    }

    return _DiveProfilePanelContent(diveId: highlightedId);
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.area_chart,
              size: 32,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a dive to view its profile',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiveProfilePanelContent extends ConsumerStatefulWidget {
  final String diveId;

  const _DiveProfilePanelContent({required this.diveId});

  @override
  ConsumerState<_DiveProfilePanelContent> createState() =>
      _DiveProfilePanelContentState();
}

class _DiveProfilePanelContentState
    extends ConsumerState<_DiveProfilePanelContent> {
  List<TooltipRow>? _tooltipRows;

  @override
  void didUpdateWidget(_DiveProfilePanelContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.diveId != oldWidget.diveId) {
      _tooltipRows = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final diveAsync = ref.watch(diveProvider(widget.diveId));
    final colorScheme = Theme.of(context).colorScheme;

    return diveAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Error loading dive',
          style: TextStyle(color: colorScheme.error),
        ),
      ),
      data: (dive) {
        if (dive == null || dive.profile.isEmpty) {
          return Center(
            child: Text(
              'No profile data for this dive',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          );
        }
        return _buildProfileContent(context, dive);
      },
    );
  }

  Widget _buildProfileContent(BuildContext context, Dive dive) {
    final analysis = ref
        .watch(profileAnalysisProvider(widget.diveId))
        .valueOrNull;
    final gasSwitches = ref
        .watch(gasSwitchesProvider(widget.diveId))
        .valueOrNull;
    final tankPressures = ref
        .watch(tankPressuresProvider(widget.diveId))
        .valueOrNull;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final colorScheme = Theme.of(context).colorScheme;

    final siteName = dive.site?.name ?? 'Unknown Site';
    final diveNumber = dive.diveNumber;
    final depthText = units.formatDepth(dive.maxDepth);
    final durationText = dive.effectiveRuntime != null
        ? '${dive.effectiveRuntime!.inMinutes} min'
        : '--';
    final dateText = units.formatDateTime(dive.dateTime, l10n: null);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header bar with dive info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                if (diveNumber != null)
                  Text(
                    '#$diveNumber',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (diveNumber != null) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    siteName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  dateText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  depthText,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Text(
                  durationText,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          // Profile chart
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 4, right: 4),
              child: DiveProfileChart(
                profile: dive.profile,
                diveDuration: dive.effectiveRuntime,
                maxDepth: dive.maxDepth,
                ceilingCurve: analysis?.ceilingCurve,
                ascentRates: analysis?.ascentRates,
                events: analysis?.events,
                ndlCurve: analysis?.ndlCurve,
                sacCurve: analysis?.smoothedSacCurve,
                ppO2Curve: analysis?.ppO2Curve,
                ppN2Curve: analysis?.ppN2Curve,
                ppHeCurve: analysis?.ppHeCurve,
                modCurve: analysis?.modCurve,
                densityCurve: analysis?.densityCurve,
                gfCurve: analysis?.gfCurve,
                surfaceGfCurve: analysis?.surfaceGfCurve,
                meanDepthCurve: analysis?.meanDepthCurve,
                ttsCurve: analysis?.ttsCurve,
                cnsCurve: analysis?.cnsCurve,
                otuCurve: analysis?.otuCurve,
                tanks: dive.tanks,
                tankPressures: tankPressures,
                gasSwitches: gasSwitches,
                tooltipBelow: true,
                onTooltipData: (rows) {
                  setState(() => _tooltipRows = rows);
                },
              ),
            ),
          ),
          // Tooltip below chart (matches dive detail tooltip style)
          _buildTooltipBar(context, colorScheme),
        ],
      ),
    );
  }

  Widget _buildTooltipBar(BuildContext context, ColorScheme colorScheme) {
    if (_tooltipRows == null || _tooltipRows!.isEmpty) {
      return const SizedBox(height: 24);
    }

    final rowStyle = TextStyle(
      fontFamily: 'RobotoMono',
      fontSize: 14,
      color: colorScheme.onInverseSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: _tooltipRows!.map((row) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '\u25CF ',
                style: TextStyle(color: row.bulletColor, fontSize: 12),
              ),
              Text(row.label.padRight(8), style: rowStyle),
              Text(row.value, style: rowStyle),
            ],
          );
        }).toList(),
      ),
    );
  }
}
