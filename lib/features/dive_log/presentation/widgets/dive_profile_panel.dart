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

/// Panel that displays the dive profile chart for the currently highlighted
/// dive. Tooltip overlays on top of content below the chart.
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
  int? _selectedPointIndex;
  double _cursorLocalX = 0;
  final LayerLink _tooltipLayerLink = LayerLink();
  OverlayEntry? _tooltipOverlay;

  @override
  void didUpdateWidget(_DiveProfilePanelContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.diveId != oldWidget.diveId) {
      _removeTooltipOverlay();
      _selectedPointIndex = null;
    }
  }

  @override
  void dispose() {
    _removeTooltipOverlay();
    super.dispose();
  }

  void _removeTooltipOverlay() {
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;
  }

  void _onPointSelected(int? index) {
    setState(() => _selectedPointIndex = index);
    if (index == null) {
      _removeTooltipOverlay();
    } else {
      _showTooltipOverlay();
    }
  }

  void _showTooltipOverlay() {
    _removeTooltipOverlay();

    _tooltipOverlay = OverlayEntry(
      builder: (context) =>
          _TooltipOverlay(link: _tooltipLayerLink, panelState: this),
    );

    Overlay.of(context).insert(_tooltipOverlay!);
  }

  @override
  Widget build(BuildContext context) {
    final diveAsync = ref.watch(diveProvider(widget.diveId));
    final colorScheme = Theme.of(context).colorScheme;

    return diveAsync.when(
      loading: () => const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SizedBox(
        height: 100,
        child: Center(
          child: Text(
            'Error loading dive',
            style: TextStyle(color: colorScheme.error),
          ),
        ),
      ),
      data: (dive) {
        if (dive == null || dive.profile.isEmpty) {
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
          // Chart with tooltip anchor at bottom + cursor tracking
          CompositedTransformTarget(
            link: _tooltipLayerLink,
            child: Listener(
              onPointerHover: (event) {
                _cursorLocalX = event.localPosition.dx;
                _tooltipOverlay?.markNeedsBuild();
              },
              onPointerMove: (event) {
                _cursorLocalX = event.localPosition.dx;
                _tooltipOverlay?.markNeedsBuild();
              },
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
                  onPointSelected: _onPointSelected,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Overlay widget that renders the tooltip floating below the chart,
/// matching the dive detail tooltip visual style.
class _TooltipOverlay extends StatelessWidget {
  final LayerLink link;
  final _DiveProfilePanelContentState panelState;

  const _TooltipOverlay({required this.link, required this.panelState});

  @override
  Widget build(BuildContext context) {
    final index = panelState._selectedPointIndex;
    if (index == null) return const SizedBox.shrink();

    final ref = panelState.ref;
    final diveId = panelState.widget.diveId;
    final diveAsync = ref.read(diveProvider(diveId));
    final dive = diveAsync.valueOrNull;
    if (dive == null || index >= dive.profile.length) {
      return const SizedBox.shrink();
    }

    final point = dive.profile[index];
    final analysis = ref.read(profileAnalysisProvider(diveId)).valueOrNull;
    final settings = ref.read(settingsProvider);
    final units = UnitFormatter(settings);
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onInverseSurface;

    final rowStyle = TextStyle(
      fontFamily: 'RobotoMono',
      fontSize: 14,
      color: onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final rows = <Widget>[];

    void addRow(String label, String value, Color bulletColor) {
      rows.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('\u25CF ', style: TextStyle(color: bulletColor, fontSize: 12)),
            Text(label.padRight(8), style: rowStyle),
            Text(value, style: rowStyle),
          ],
        ),
      );
    }

    // Time
    final minutes = point.timestamp ~/ 60;
    final seconds = point.timestamp % 60;
    addRow(
      'Time',
      '$minutes:${seconds.toString().padLeft(2, '0')}',
      onSurface.withValues(alpha: 0.5),
    );

    // Depth
    addRow('Depth', units.formatDepth(point.depth), const Color(0xFF2196F3));

    // Temperature
    if (point.temperature != null) {
      addRow(
        'Temp',
        units.formatTemperature(point.temperature),
        colorScheme.tertiary,
      );
    }

    // Ceiling
    final ceilingCurve = analysis?.ceilingCurve;
    if (ceilingCurve != null && index < ceilingCurve.length) {
      final ceiling = ceilingCurve[index];
      if (ceiling > 0) {
        addRow('Ceiling', units.formatDepth(ceiling), const Color(0xFFD32F2F));
      }
    }

    // NDL
    if (point.ndl != null) {
      final ndlValue = point.ndl! < 0 ? 'DECO' : '${point.ndl! ~/ 60} min';
      addRow('NDL', ndlValue, Colors.orange);
    }

    return CompositedTransformFollower(
      link: link,
      targetAnchor: Alignment.bottomLeft,
      followerAnchor: Alignment.topCenter,
      offset: Offset(panelState._cursorLocalX, 0),
      child: Align(
        alignment: Alignment.topLeft,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.inverseSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows,
            ),
          ),
        ),
      ),
    );
  }
}
