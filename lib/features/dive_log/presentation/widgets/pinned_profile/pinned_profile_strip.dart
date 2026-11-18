import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/utils/chart_drag_crossing.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_palette.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
import 'package:submersion/features/dive_log/presentation/utils/gas_consumption_tooltip.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart'
    show TooltipRow;
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/pinned_strip_layer_animator.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_band_painter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_tooltip_rows.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_line_painter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_marker_painter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_painter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_lift.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_tooltip.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_values.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Room below the strip the tooltip may take: enough for its own five rows,
/// and more for each row a card layer adds (issue #4562).
const double _tooltipRoom = 240;

/// Room a tooltip row takes.
const double _tooltipRowRoom = 24;

/// The strip's own tooltip rows, which [_tooltipRoom] is sized for.
const int _ownTooltipRows = 5;

/// Corner radius of the profile card the strip condenses out of when the
/// theme's card shape gives none: Material 3's default card radius.
const double _defaultCardRadius = 12;

/// The look of the profile card the strip condenses out of, resolved from
/// the theme as [Card] resolves it, so the strip pinned among the other cards
/// matches them in every theme preset (#4488): its [fill], its bottom
/// [corners] and its outline [side].
///
/// A translucent card fill (Deep dark) is composited over the page surface,
/// as the card is: the strip lies over scrolling content, which would
/// otherwise show through it.
({Color fill, BorderRadius corners, BorderSide side}) _cardLook(
  BuildContext context,
) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final shape = theme.cardTheme.shape;
  final radius = shape is RoundedRectangleBorder
      ? shape.borderRadius.resolve(Directionality.of(context))
      : BorderRadius.circular(_defaultCardRadius);
  return (
    fill: Color.alphaBlend(
      theme.cardTheme.color ?? scheme.surfaceContainerLow,
      scheme.surface,
    ),
    corners: BorderRadius.only(
      bottomLeft: radius.bottomLeft,
      bottomRight: radius.bottomRight,
    ),
    side: shape is OutlinedBorder ? shape.side : BorderSide.none,
  );
}

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
/// shrinking footprint of the profile card), its bottom corners rounded like
/// the card's. Its depth line starts exactly on the full chart's
/// ([morphFrom]) and moves continuously into the strip, so only one depth
/// line is ever seen.
class PinnedProfileStrip extends ConsumerStatefulWidget {
  const PinnedProfileStrip({
    super.key,
    required this.dive,
    this.condense = 1,
    this.backgroundOpacity = 1,
    this.morphFrom,
    this.layers = StripLayerState.none,
  });

  final Dive dive;

  /// The layers of the cards in view and how far each has faded in, and how
  /// far the strip has grown for them (issue #4562).
  final StripLayerState layers;

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
    final card = _cardLook(context);
    // The diver's chart colours, so the strip draws each line as the full
    // chart does.
    final palette = ProfileMetricPalette(
      overrides: ref.watch(
        settingsProvider.select((s) => s.profileMetricColors),
      ),
      temperatureAuto: colors.tertiary,
    );
    final depthColor = palette.colorOf(ProfileMetric.depth);
    final values = pinnedStripValuesAt(
      chartProfile: profile,
      analysis: analysis,
      cursorIndex: cursor,
    );
    final selectedSeconds =
        cursor != null && cursor >= 0 && cursor < profile.length
        ? profile[cursor].timestamp
        : null;
    final layers = widget.layers;
    final consumption = ref.watch(gasConsumptionDisplayProvider);
    final rows = values == null
        ? const <TooltipRow>[]
        : [
            ...pinnedStripTooltipRows(
              values,
              units,
              context.l10n,
              palette: palette,
            ),
            ...stripLayerTooltipRows(
              layers: layers,
              cursorSeconds: selectedSeconds!,
              cursorIndex: cursor,
              units: units,
              l10n: context.l10n,
              // SAC or RMV, as the diver shows gas consumption.
              sacRow: (sacBarPerMin) => gasConsumptionTooltipRow(
                l10n: context.l10n,
                units: units,
                display: consumption,
                sacBarPerMin: sacBarPerMin,
                tankVolume: widget.dive.sacReferenceVolume,
              ),
            ),
          ];
    // Settled, the strip is as tall as its line layers have grown it.
    final stripHeight =
        kPinnedStripHeight +
        layers.grow * (kPinnedStripGrownHeight - kPinnedStripHeight);

    final condense = widget.condense.clamp(0.0, 1.0);
    final background = widget.backgroundOpacity.clamp(0.0, 1.0);
    // How far the strip has lifted off the page. Nothing while the surface
    // is see-through (a shadow would show through and grey the card), then
    // growing with the condense, so it never switches on or off in a single
    // frame either way.
    final lift = background >= 1 ? condense : 0.0;
    final showTooltip = rows.isNotEmpty && condense >= 1;
    final stripPainter = PinnedStripPainter(
      profile: profile,
      curveColor: depthColor,
      // The full chart's depth shading.
      fillColors: GasColors.gradientColors(depthColor),
      from: widget.morphFrom,
      morph: condense,
      ndlCurve: analysis?.ndlCurve,
      ceilingCurve: analysis?.ceilingCurve,
      decoStopCurve: analysis?.decoStopCurve,
      surfaceColor: card.fill,
      ndlColor: palette.colorOf(ProfileMetric.ndl),
      ceilingColor: palette.colorOf(ProfileMetric.ceiling),
      maxDepthColor: palette.colorOf(ProfileMetric.maxDepth),
      curveHeight: stripHeight,
      extraMaxDepthMeters: _ghostDepth(profile, layers),
    );
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
                    room: _tooltipRoomFor(
                      rows.length,
                      MediaQuery.sizeOf(context).height,
                    ),
                    // Where the cursor line is drawn, through the strip's own
                    // mapping.
                    cursorX: selectedSeconds == null
                        ? 0
                        : stripPainter
                              .mappingFor(Size(width, stripHeight))
                              .project(selectedSeconds, 0)
                              .dx,
                  ),
            child: CompositedTransformTarget(
              link: _link,
              // Its own shadow, clearly deeper than the cards it covers in
              // every theme preset and much stronger in dark mode, where
              // black barely darkens the page (#4554). It falls only beside
              // and below, never up onto the card or header above.
              child: ClipRect(
                clipper: const PinnedStripShadowClip(),
                child: DecoratedBox(
                  key: const ValueKey('pinnedStripShadow'),
                  decoration: BoxDecoration(
                    borderRadius: card.corners,
                    boxShadow: pinnedStripShadows(
                      theme.brightness,
                      strength: lift,
                    ),
                  ),
                  child: Material(
                    // The card's own colour, so the strip reads as the card
                    // condensing.
                    color: card.fill.withValues(
                      alpha: card.fill.a * background,
                    ),
                    // No shadow of its own: the DecoratedBox around it draws
                    // the strip's, and a second would stack under it.
                    elevation: 0,
                    // Colour follows the scroll frame by frame already; the
                    // surface's own ease would lag a fast scroll and flash.
                    animationDuration: Duration.zero,
                    // It starts on the card's plot and pins flush under the
                    // header at the card's width, so only its bottom corners
                    // round, like the card's own, condensing and pinned alike
                    // (#4488).
                    shape: RoundedRectangleBorder(borderRadius: card.corners),
                    clipBehavior: Clip.antiAlias,
                    child: CustomPaint(
                      // Its outline on the sides and bottom only: its top
                      // crosses the card at the plot's top and pins flush under
                      // the header. The theme's card outline where there is
                      // one, fading in with the surface; otherwise, in dark
                      // mode, a faint light rim growing in with the shadow.
                      foregroundPainter: PinnedStripOutlinePainter(
                        side: pinnedStripEdge(
                          brightness: theme.brightness,
                          themeSide: card.side,
                          surfaceOpacity: background,
                          strength: lift,
                        ),
                        corners: card.corners,
                      ),
                      child: SizedBox(
                        height: condense >= 1 ? stripHeight : null,
                        child: MouseRegion(
                          onHover: (e) =>
                              _scrubTo(e.localPosition.dx, width, profile),
                          // A scrub that strays off the strip goes on until
                          // its drag ends, which clears the cursor (#4611).
                          onExit: (e) {
                            if (!isDragCrossing(e)) _write(null);
                          },
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (d) =>
                                _scrubTo(d.localPosition.dx, width, profile),
                            // A mouse still hovers where it clicked, so the
                            // cursor stays until it moves or leaves; a lifted
                            // finger clears.
                            onTapUp: (d) {
                              if (d.kind != PointerDeviceKind.mouse) {
                                _write(null);
                              }
                            },
                            onTapCancel: () => _write(null),
                            onHorizontalDragStart: (d) =>
                                _scrubTo(d.localPosition.dx, width, profile),
                            onHorizontalDragUpdate: (d) =>
                                _scrubTo(d.localPosition.dx, width, profile),
                            onHorizontalDragEnd: (_) => _write(null),
                            onHorizontalDragCancel: () => _write(null),
                            // Cross-fades with the surface: drawn on the
                            // chart's own line and shading, so at full strength
                            // the two shadings would stack into a darker blue.
                            child: Opacity(
                              opacity: background,
                              child: _Layered(
                                strip: stripPainter,
                                layers: layers,
                                // Its own layer: moving the cursor repaints
                                // only the cursor.
                                cursor: PinnedStripCursorPainter(
                                  strip: stripPainter,
                                  selectedSeconds: selectedSeconds,
                                  color: colors.primary,
                                ),
                              ),
                            ),
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
}

/// Room below the strip for a tooltip of [rows] rows: more for each row a
/// card layer adds, but never over half of a screen [screenHeight] tall, a
/// short window included, or its last rows would fall off it. Past that its
/// box scales down to fit.
double _tooltipRoomFor(int rows, double screenHeight) {
  final wanted = math.max(
    _tooltipRoom,
    _tooltipRoom + (rows - _ownTooltipRows) * _tooltipRowRoom,
  );
  return math.min(wanted, screenHeight / 2);
}

/// The deepest point of the ghost depth lines showing, faded in with them,
/// so the depth axis eases out to a deeper ghost rather than jumping.
double _ghostDepth(List<DiveProfilePoint> profile, StripLayerState layers) {
  final own = pinnedStripCurve(profile).maxDepthMeters;
  var deepest = 0.0;
  for (final ghost in layers.data.ghosts) {
    final strength = layers.strengthOf(ghost.layer);
    if (strength <= 0 || ghost.maxDepth <= own) continue;
    deepest = math.max(deepest, own + (ghost.maxDepth - own) * strength);
  }
  return deepest;
}

/// The strip's painters, bottom to top: the card layers' bands, the depth
/// curve and its own marks, the card layers' lines and marks, the cursor.
/// The card layers' painters are left out while no layer shows.
class _Layered extends StatelessWidget {
  const _Layered({
    required this.strip,
    required this.layers,
    required this.cursor,
  });

  final PinnedStripPainter strip;
  final StripLayerState layers;
  final PinnedStripCursorPainter cursor;

  @override
  Widget build(BuildContext context) {
    final depth = CustomPaint(
      size: Size.infinite,
      painter: strip,
      foregroundPainter: layers.strengths.isEmpty ? cursor : null,
    );
    if (layers.strengths.isEmpty) return depth;
    final shows = layers.strengths.keys;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (shows.any(
          (l) => l == StripLayer.phases || l == StripLayer.safetyFindings,
        ))
          CustomPaint(
            painter: StripBandPainter(strip: strip, layers: layers),
          ),
        depth,
        CustomPaint(
          painter: StripLinePainter(strip: strip, layers: layers),
          foregroundPainter: StripMarkerPainter(strip: strip, layers: layers),
        ),
        CustomPaint(foregroundPainter: cursor),
      ],
    );
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
    required this.room,
  });

  final LayerLink link;
  final List<TooltipRow> rows;
  final double stripWidth;
  final double cursorX;

  /// Height the tooltip may take below the strip.
  final double room;

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
        height: room,
        // The strip's semantics value already reads these rows, so they are
        // not announced a second time from here.
        child: ExcludeSemantics(
          child: IgnorePointer(
            child: CustomSingleChildLayout(
              delegate: _BesideCursor(cursorX),
              // At the largest text sizes the rows are wider than the room;
              // the box scales down to fit, as the full chart's does.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: PinnedStripTooltip(rows: rows),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _BesideCursor extends SingleChildLayoutDelegate {
  const _BesideCursor(this.cursorX);

  final double cursorX;

  /// The room the tooltip may take: the strip's width less its margins.
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen().deflate(
        const EdgeInsets.symmetric(horizontal: kPinnedTooltipEdgeMargin),
      );

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

/// Draws the strip's outline, where the theme's cards have one, along its
/// sides and bottom, rounding its bottom [corners] as the card does. It has
/// no top edge: while condensing the strip's top crosses the card at the
/// plot's top, where a line would split the card in two, and pinned it sits
/// flush under the header.
class PinnedStripOutlinePainter extends CustomPainter {
  const PinnedStripOutlinePainter({required this.side, required this.corners});

  final BorderSide side;
  final BorderRadius corners;

  @override
  void paint(Canvas canvas, Size size) {
    if (side.style == BorderStyle.none || side.width <= 0) return;
    // Stroked on its centre line, inset by half its width, so it lies inside
    // the surface's clip like the card's own outline.
    final half = side.width / 2;
    final rect = (Offset.zero & size).deflate(half);
    Radius inset(Radius r) => Radius.elliptical(
      (r.x - half).clamp(0.0, rect.width / 2),
      (r.y - half).clamp(0.0, rect.height),
    );
    final left = inset(corners.bottomLeft);
    final right = inset(corners.bottomRight);
    final path = Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.left, rect.bottom - left.y)
      ..arcToPoint(
        Offset(rect.left + left.x, rect.bottom),
        radius: left,
        clockwise: false,
      )
      ..lineTo(rect.right - right.x, rect.bottom)
      ..arcToPoint(
        Offset(rect.right, rect.bottom - right.y),
        radius: right,
        clockwise: false,
      )
      ..lineTo(rect.right, rect.top);
    canvas.drawPath(path, side.toPaint());
  }

  @override
  bool shouldRepaint(PinnedStripOutlinePainter oldDelegate) =>
      side != oldDelegate.side || corners != oldDelegate.corners;
}
