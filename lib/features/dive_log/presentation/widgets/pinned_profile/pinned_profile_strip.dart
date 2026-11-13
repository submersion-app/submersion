import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_palette.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart'
    show TooltipRow;
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_painter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_tooltip.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_values.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Room below the strip the tooltip may take: enough for its five rows.
const double _tooltipRoom = 240;

/// How far toward white the max-depth label moves on a dark surface, where
/// the chart's dark max-depth colour would not read.
const double _darkLabelLift = 0.45;

/// Corner radius of the profile card the strip condenses out of.
const double _cardRadius = 12;

/// The thin, scrubbable dive profile pinned at the top of dive details once
/// the full profile card scrolls away (issue #4423).
///
/// It reads and writes the same shared cursor as the full chart,
/// [profileTrackingIndexProvider], so every card that follows the chart
/// follows the strip too. Like the full chart, lifting a finger or moving the
/// mouse away clears the cursor. While the cursor is set, its values float in
/// a compact tooltip below the strip (issue #4509), drawn in the app's
/// overlay so nothing the strip sits in can clip it.
///
/// The same widget draws the condense itself, so it never swaps for another
/// at any point: below [condense] 1 it fills whatever box it is given (the
/// shrinking footprint of the profile card), its corners rounding like the
/// card's. Its depth line starts exactly on the full chart's ([morphFrom])
/// and moves continuously into the strip, so only one depth line is ever
/// seen.
class PinnedProfileStrip extends ConsumerStatefulWidget {
  const PinnedProfileStrip({
    super.key,
    required this.dive,
    this.condense = 1,
    this.backgroundOpacity = 1,
    this.morphFrom,
  });

  final Dive dive;

  /// How far the shape has condensed into the strip, from 0 to 1. At 1 the
  /// strip is its pinned [kPinnedStripHeight]; below 1 it needs a bounded
  /// height from its parent.
  final double condense;

  /// The opacity of the strip's surface, faded in over the card before the
  /// shape moves.
  final double backgroundOpacity;

  /// Where the full chart draws its depth line, in this widget's
  /// coordinates: the line's mapping at [condense] 0. Null when the chart
  /// has not reported its plot.
  final PlotMapping? morphFrom;

  @override
  ConsumerState<PinnedProfileStrip> createState() => _PinnedProfileStripState();
}

class _PinnedProfileStripState extends ConsumerState<PinnedProfileStrip> {
  final LayerLink _link = LayerLink();

  /// Always showing: its builder draws nothing while there is no cursor, so
  /// the strip never has to show or hide it in the middle of a build.
  final OverlayPortalController _portal = OverlayPortalController()..show();

  String get _diveId => widget.dive.id;

  void _write(int? index) {
    final notifier = ref.read(profileTrackingIndexProvider(_diveId).notifier);
    if (notifier.state != index) notifier.state = index;
  }

  void _scrubTo(double dx, double width, List<DiveProfilePoint> profile) {
    if (profile.length < 2 || width <= 0) return;
    final first = profile.first.timestamp;
    final span = profile.last.timestamp - first;
    final seconds = first + (dx / width).clamp(0.0, 1.0) * span;
    setProfileCursorSeconds(ref, _diveId, profile, seconds.round());
  }

  @override
  Widget build(BuildContext context) {
    final profile = watchChartProfile(ref, widget.dive);
    final cursor = ref.watch(profileTrackingIndexProvider(_diveId));
    final sourceId = ref.watch(activeDiveSourceProvider(_diveId));
    final analysis = ref
        .watch(
          sourceProfileAnalysisProvider((diveId: _diveId, sourceId: sourceId)),
        )
        .value;
    final units = ref.watch(unitFormatterProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // The diver's chart colours, so the strip draws each line as the full
    // chart does.
    final palette = ProfileMetricPalette(
      overrides: ref.watch(
        settingsProvider.select((s) => s.profileMetricColors),
      ),
      temperatureAuto: colors.tertiary,
    );
    final depthColor = palette.colorOf(ProfileMetric.depth);
    final maxDepthColor = palette.colorOf(ProfileMetric.maxDepth);
    final values = pinnedStripValuesAt(
      chartProfile: profile,
      analysis: analysis,
      cursorIndex: cursor,
    );
    final rows = values == null
        ? const <TooltipRow>[]
        : pinnedStripTooltipRows(values, units, context.l10n, palette: palette);
    final selectedSeconds =
        cursor != null && cursor >= 0 && cursor < profile.length
        ? profile[cursor].timestamp
        : null;
    final deepest = pinnedStripCurve(profile).deepest;

    final condense = widget.condense.clamp(0.0, 1.0);
    final background = widget.backgroundOpacity.clamp(0.0, 1.0);
    final showTooltip = rows.isNotEmpty && condense >= 1;
    return Semantics(
      container: true,
      label: context.l10n.diveLog_pinnedStrip_semantics,
      value: rows.isEmpty
          ? null
          : [for (final r in rows) '${r.label} ${r.value}'].join(', '),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return OverlayPortal(
            controller: _portal,
            overlayChildBuilder: (context) => !showTooltip
                ? const SizedBox.shrink()
                : _FloatingTooltip(
                    link: _link,
                    rows: rows,
                    stripWidth: width,
                    cursorX: _cursorX(profile, selectedSeconds, width),
                  ),
            child: CompositedTransformTarget(
              link: _link,
              child: Material(
                // The card's own colour, so the strip reads as the card
                // condensing.
                color: colors.surfaceContainerLow.withValues(
                  alpha: colors.surfaceContainerLow.a * background,
                ),
                // No shadow while the surface is see-through (it would show
                // through and grey the card), then one that grows with the
                // condense, so it never switches on or off in a single frame
                // either way.
                elevation: background >= 1 ? 2 * condense : 0,
                // Colour and shadow follow the scroll frame by frame already;
                // the surface's own ease would lag a fast scroll and flash.
                animationDuration: Duration.zero,
                // It starts across the card at the plot's top, so only its
                // bottom corners round, like the card's own.
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(_cardRadius * (1 - condense)),
                ),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  height: condense >= 1 ? kPinnedStripHeight : null,
                  child: MouseRegion(
                    onHover: (e) =>
                        _scrubTo(e.localPosition.dx, width, profile),
                    onExit: (_) => _write(null),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) =>
                          _scrubTo(d.localPosition.dx, width, profile),
                      // A mouse still hovers where it clicked, so the cursor
                      // stays until it moves or leaves; a lifted finger
                      // clears.
                      onTapUp: (d) {
                        if (d.kind != PointerDeviceKind.mouse) _write(null);
                      },
                      onTapCancel: () => _write(null),
                      onHorizontalDragStart: (d) =>
                          _scrubTo(d.localPosition.dx, width, profile),
                      onHorizontalDragUpdate: (d) =>
                          _scrubTo(d.localPosition.dx, width, profile),
                      onHorizontalDragEnd: (_) => _write(null),
                      onHorizontalDragCancel: () => _write(null),
                      // Cross-fades with the surface: drawn on the chart's
                      // own line and shading, so at full strength the two
                      // shadings would stack into a darker blue.
                      child: Opacity(
                        opacity: background,
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: PinnedStripPainter(
                            profile: profile,
                            selectedSeconds: selectedSeconds,
                            curveColor: depthColor,
                            // The full chart's depth shading.
                            fillColors: GasColors.gradientColors(depthColor),
                            markerColor: colors.primary,
                            from: widget.morphFrom,
                            morph: condense,
                            ndlCurve: analysis?.ndlCurve,
                            ceilingCurve: analysis?.ceilingCurve,
                            decoStopCurve: analysis?.decoStopCurve,
                            maxDepthLabel: deepest == null
                                ? null
                                : units.formatDepth(deepest.depth),
                            maxDepthLabelColor:
                                theme.brightness == Brightness.dark
                                ? Color.lerp(
                                    maxDepthColor,
                                    Colors.white,
                                    _darkLabelLift,
                                  )!
                                : maxDepthColor,
                            surfaceColor: colors.surfaceContainerLow,
                            ndlColor: palette.colorOf(ProfileMetric.ndl),
                            ceilingColor: palette.colorOf(
                              ProfileMetric.ceiling,
                            ),
                            maxDepthColor: maxDepthColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Where the cursor at [seconds] sits across a strip [width] wide: the
  /// strip runs the whole dive edge to edge.
  static double _cursorX(
    List<DiveProfilePoint> profile,
    int? seconds,
    double width,
  ) {
    if (seconds == null || profile.length < 2) return 0;
    final first = profile.first.timestamp;
    final span = profile.last.timestamp - first;
    if (span <= 0) return 0;
    return ((seconds - first) / span).clamp(0.0, 1.0) * width;
  }
}

/// The tooltip, hung [kPinnedTooltipDrop] below the strip through [link] and
/// placed beside the cursor by [pinnedTooltipLeft].
class _FloatingTooltip extends StatelessWidget {
  const _FloatingTooltip({
    required this.link,
    required this.rows,
    required this.stripWidth,
    required this.cursorX,
  });

  final LayerLink link;
  final List<TooltipRow> rows;
  final double stripWidth;
  final double cursorX;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: CompositedTransformFollower(
      link: link,
      showWhenUnlinked: false,
      targetAnchor: Alignment.bottomLeft,
      offset: const Offset(0, kPinnedTooltipDrop),
      child: SizedBox(
        width: stripWidth,
        height: _tooltipRoom,
        child: IgnorePointer(
          child: CustomSingleChildLayout(
            delegate: _BesideCursor(cursorX),
            child: PinnedStripTooltip(rows: rows),
          ),
        ),
      ),
    ),
  );
}

class _BesideCursor extends SingleChildLayoutDelegate {
  const _BesideCursor(this.cursorX);

  final double cursorX;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    pinnedTooltipLeft(
      cursorX: cursorX,
      tooltipWidth: childSize.width,
      stripWidth: size.width,
    ),
    0,
  );

  @override
  bool shouldRelayout(_BesideCursor old) => old.cursorX != cursorX;
}
