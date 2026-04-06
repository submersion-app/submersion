import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/data/services/profile_markers_service.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Panel that displays the dive profile chart for the currently highlighted
/// dive. Tooltip floats as an Overlay on top of all content below.
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
      height: 100,
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
  Dive? _lastDive;
  List<TooltipRow>? _tooltipRows;
  Offset _globalCursorPos = Offset.zero;
  OverlayEntry? _overlayEntry;
  final GlobalKey _chartAreaKey = GlobalKey();

  @override
  void didUpdateWidget(_DiveProfilePanelContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.diveId != oldWidget.diveId) {
      _removeOverlay();
      _tooltipRows = null;
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onTooltipData(List<TooltipRow>? rows) {
    _tooltipRows = rows;
    if (rows == null || rows.isEmpty) {
      _removeOverlay();
      return;
    }
    // Schedule overlay update after current frame completes
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_tooltipRows == null || _tooltipRows!.isEmpty) {
        _removeOverlay();
        return;
      }
      if (_overlayEntry == null) {
        _overlayEntry = OverlayEntry(builder: (_) => _buildOverlayTooltip());
        Overlay.of(context).insert(_overlayEntry!);
      } else {
        _overlayEntry!.markNeedsBuild();
      }
    });
  }

  void _onPointerUpdate(Offset globalPos) {
    _globalCursorPos = globalPos;
    _overlayEntry?.markNeedsBuild();
  }

  Widget _buildOverlayTooltip() {
    final rows = _tooltipRows;
    if (rows == null || rows.isEmpty) return const SizedBox.shrink();

    // Get chart area bottom in global coordinates
    final chartBox =
        _chartAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (chartBox == null || !chartBox.attached) return const SizedBox.shrink();

    final chartBottomLeft = chartBox.localToGlobal(
      Offset(0, chartBox.size.height),
    );

    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onInverseSurface;
    final rowStyle = TextStyle(
      fontFamily: 'RobotoMono',
      fontSize: 14,
      color: onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    // Convert global coords to overlay-local and clamp within chart bounds
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final overlayOffset =
        overlay?.globalToLocal(_globalCursorPos) ?? _globalCursorPos;
    final overlayChartBottom =
        overlay?.globalToLocal(chartBottomLeft) ?? chartBottomLeft;
    final overlayChartTopLeft =
        overlay?.globalToLocal(chartBox.localToGlobal(Offset.zero)) ??
        Offset.zero;
    final chartRight = overlayChartTopLeft.dx + chartBox.size.width;

    // Estimate tooltip width (~220px) and clamp so it stays in frame
    const tooltipWidth = 220.0;
    const halfTooltip = tooltipWidth / 2;
    final clampedX = overlayOffset.dx.clamp(
      overlayChartTopLeft.dx + halfTooltip,
      chartRight - halfTooltip,
    );

    return Positioned(
      left: clampedX,
      top: overlayChartBottom.dy + 4,
      child: FractionalTranslation(
        translation: const Offset(-0.5, 0),
        child: IgnorePointer(
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: colorScheme.inverseSurface,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: rows.map((row) {
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
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // diveProvider loads the full dive with profile data
    final fullDive = ref.watch(diveProvider(widget.diveId)).valueOrNull;
    if (fullDive != null) {
      _lastDive = fullDive;
    }
    final dive = _lastDive;

    if (dive == null) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (dive.profile.isEmpty) {
      return SizedBox(
        height: 100,
        child: Center(
          child: Text(
            'No profile data for this dive',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }
    return _buildProfileContent(context, dive);
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

    // Profile markers (same as dive detail page)
    final showMaxDepthMarker = ref.watch(showMaxDepthMarkerProvider);
    final showPressureThresholdMarkers = ref.watch(
      showPressureThresholdMarkersProvider,
    );
    final markers = <ProfileMarker>[];
    if (dive.profile.isNotEmpty) {
      if (showMaxDepthMarker && analysis != null) {
        final m = ProfileMarkersService.getMaxDepthMarker(
          profile: dive.profile,
          maxDepthTimestamp: analysis.maxDepthTimestamp,
          maxDepth: analysis.maxDepth,
        );
        if (m != null) markers.add(m);
      }
      if (showPressureThresholdMarkers && dive.tanks.isNotEmpty) {
        markers.addAll(
          ProfileMarkersService.getPressureThresholdMarkers(
            profile: dive.profile,
            tanks: dive.tanks,
            tankPressures: tankPressures,
          ),
        );
      }
    }

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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header bar
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
          // Chart with cursor tracking
          Listener(
            key: _chartAreaKey,
            onPointerHover: (e) => _onPointerUpdate(e.position),
            onPointerMove: (e) => _onPointerUpdate(e.position),
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
                markers: markers,
                showMaxDepthMarker: showMaxDepthMarker,
                showPressureThresholdMarkers: showPressureThresholdMarkers,
                tanks: dive.tanks,
                tankPressures: tankPressures,
                gasSwitches: gasSwitches,
                tooltipBelow: true,
                onPointSelected: (_) {},
                onTooltipData: _onTooltipData,
              ),
            ),
          ),
          // Tiny spacer
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
