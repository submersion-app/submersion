import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/utils/minutes_seconds.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/profile_surface_lead_in.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_depth_at.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const double _chartHeight = 180;
const double _cursorDotSize = 10;

/// Room under the deepest point, as a fraction of it, so the line does not
/// run along the chart's bottom edge.
const double _depthHeadroom = 1.1;

/// The shallowest depth the chart spans, in metres, so a profile that never
/// left the surface still has a scale.
const double _minChartDepth = 1;

/// Whether [profile] has a span of time to pick on.
bool canPickOnProfile(List<DiveProfilePoint> profile) =>
    profile.length >= 2 && profile.last.timestamp > 0;

/// Opens the sheet for picking a gas switch time on the dive's [profile]
/// (issue #4089). Resolves with the chosen seconds, or null on cancel. Pass
/// the dive's other switches as [otherSwitchTimes] and the row cylinder's
/// starts as [breathStarts]; both are drawn as markers. [profile] must pass
/// [canPickOnProfile].
Future<int?> showGasSwitchTimeSheet(
  BuildContext context, {
  required List<DiveProfilePoint> profile,
  required int initialSeconds,
  required UnitFormatter units,
  List<int> otherSwitchTimes = const [],
  List<int> breathStarts = const [],
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _GasSwitchTimeSheet(
      profile: profile,
      initialSeconds: initialSeconds,
      units: units,
      otherSwitchTimes: otherSwitchTimes,
      breathStarts: breathStarts,
    ),
  );
}

class _GasSwitchTimeSheet extends StatefulWidget {
  const _GasSwitchTimeSheet({
    required this.profile,
    required this.initialSeconds,
    required this.units,
    required this.otherSwitchTimes,
    required this.breathStarts,
  });

  final List<DiveProfilePoint> profile;
  final int initialSeconds;
  final UnitFormatter units;
  final List<int> otherSwitchTimes;
  final List<int> breathStarts;

  @override
  State<_GasSwitchTimeSheet> createState() => _GasSwitchTimeSheetState();
}

class _GasSwitchTimeSheetState extends State<_GasSwitchTimeSheet> {
  late final int _span = widget.profile.last.timestamp;
  late final double _chartDepth =
      widget.profile.map((p) => p.depth).fold(_minChartDepth, math.max) *
      _depthHeadroom;
  late int _seconds = widget.initialSeconds.clamp(0, _span);

  // Built once: a drag moves only the cursor above it, so a long profile is
  // not laid out again on every pointer event.
  late final Widget _chart = _ProfileLine(
    profile: widget.profile,
    span: _span,
    chartDepth: _chartDepth,
    otherSwitchTimes: widget.otherSwitchTimes,
    breathStarts: widget.breathStarts,
  );

  void _moveTo(double dx, double width) {
    final fraction = (dx / width).clamp(0.0, 1.0);
    setState(() => _seconds = (fraction * _span).round());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final depth = profileDepthAt(widget.profile, _seconds);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.diveLog_edit_gasSwitches_pickTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.diveLog_edit_gasSwitches_pickReadout(
                formatMinutesSeconds(_seconds),
                widget.units.formatDepth(depth),
              ),
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: _chartHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  return GestureDetector(
                    key: const ValueKey('gas-switch-time-chart'),
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => _moveTo(d.localPosition.dx, width),
                    onHorizontalDragStart: (d) =>
                        _moveTo(d.localPosition.dx, width),
                    onHorizontalDragUpdate: (d) =>
                        _moveTo(d.localPosition.dx, width),
                    child: ExcludeSemantics(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: RepaintBoundary(child: _chart),
                          ),
                          _Cursor(
                            x: width * _seconds / _span,
                            y: _chartHeight * (depth ?? 0) / _chartDepth,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Semantics(
              label: l10n.diveLog_edit_gasSwitches_pickTitle,
              // Time runs left to right on the chart in every language, so the
              // slider must too. No inset, so its thumb sits under the cursor.
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Slider(
                  value: _seconds.toDouble(),
                  max: _span.toDouble(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  semanticFormatterCallback: (value) =>
                      formatMinutesSeconds(value.round()),
                  onChanged: (value) =>
                      setState(() => _seconds = value.round()),
                ),
              ),
            ),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.common_action_cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_seconds),
                  child: Text(l10n.diveLog_edit_gasSwitches_pickConfirm),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A vertical line through the chosen time with a dot on the profile.
class _Cursor extends StatelessWidget {
  const _Cursor({required this.x, required this.y});

  final double x;
  final double y;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return Positioned(
      key: const ValueKey('gas-switch-time-cursor'),
      left: x - _cursorDotSize / 2,
      top: 0,
      bottom: 0,
      width: _cursorDotSize,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 0,
            bottom: 0,
            child: SizedBox(
              key: const ValueKey('gas-switch-time-line'),
              width: 1.5,
              child: ColoredBox(color: color),
            ),
          ),
          Positioned(
            top: y - _cursorDotSize / 2,
            child: Container(
              width: _cursorDotSize,
              height: _cursorDotSize,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }
}

/// The depth profile, surface at the top, with thin markers at the dive's
/// other switches and the row cylinder's breathing starts.
class _ProfileLine extends StatelessWidget {
  const _ProfileLine({
    required this.profile,
    required this.span,
    required this.chartDepth,
    required this.otherSwitchTimes,
    required this.breathStarts,
  });

  final List<DiveProfilePoint> profile;
  final int span;
  final double chartDepth;
  final List<int> otherSwitchTimes;
  final List<int> breathStarts;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: span.toDouble(),
        minY: -chartDepth,
        maxY: 0,
        clipData: const FlClipData.all(),
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              if (shouldDrawSurfaceLeadIn(profile)) const FlSpot(0, 0),
              for (final p in profile) FlSpot(p.timestamp.toDouble(), -p.depth),
            ],
            color: colors.primary,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            aboveBarData: BarAreaData(
              show: true,
              color: colors.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
        extraLinesData: ExtraLinesData(
          verticalLines: [
            for (final t in otherSwitchTimes)
              if (t >= 0 && t <= span)
                VerticalLine(
                  x: t.toDouble(),
                  color: colors.outline,
                  strokeWidth: 1,
                  dashArray: const [3, 3],
                ),
            for (final t in breathStarts)
              if (t >= 0 && t <= span)
                VerticalLine(
                  x: t.toDouble(),
                  color: colors.tertiary,
                  strokeWidth: 1,
                ),
          ],
        ),
      ),
      duration: Duration.zero,
    );
  }
}
