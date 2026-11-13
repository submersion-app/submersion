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

/// The settled strip's elevation: Material 3's level 2, the lift of an app
/// bar with content scrolled under it, so the strip reads as pinned over the
/// page rather than as one more card in it.
const double kPinnedStripElevation = 3;

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
    final maxDepthColor = palette.colorOf(ProfileMetric.maxDepth);
    final values = pinnedStripValuesAt(
      chartProfile: profile,
      analysis: analysis,
      cursorIndex: cursor,
    );
    final rows = values == null
        ? const <TooltipRow>[]
        : pinnedStripTooltipRows(values, units, context.l10n, palette: palette);
    final deepest = pinnedStripCurve(profile).deepest;
    final selectedSeconds =
        cursor != null && cursor >= 0 && cursor < profile.length
        ? profile[cursor].timestamp
        : null;

    final condense = widget.condense.clamp(0.0, 1.0);
    final background = widget.backgroundOpacity.clamp(0.0, 1.0);
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
      maxDepthLabel: deepest == null ? null : units.formatDepth(deepest.depth),
      maxDepthLabelColor: theme.brightness == Brightness.dark
          ? Color.lerp(maxDepthColor, Colors.white, _darkLabelLift)!
          : maxDepthColor,
      maxDepthLabelStyle: theme.textTheme.labelSmall,
      surfaceColor: card.fill,
      ndlColor: palette.colorOf(ProfileMetric.ndl),
      ceilingColor: palette.colorOf(ProfileMetric.ceiling),
      maxDepthColor: maxDepthColor,
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
                    // Where the cursor line is drawn, through the strip's own
                    // mapping.
                    cursorX: selectedSeconds == null
                        ? 0
                        : stripPainter
                              .mappingFor(Size(width, kPinnedStripHeight))
                              .project(selectedSeconds, 0)
                              .dx,
                  ),
            child: CompositedTransformTarget(
              link: _link,
              child: Material(
                // The card's own colour, so the strip reads as the card
                // condensing.
                color: card.fill.withValues(alpha: card.fill.a * background),
                // No shadow while the surface is see-through (it would show
                // through and grey the card), then one that grows with the
                // condense, so it never switches on or off in a single frame
                // either way.
                elevation: background >= 1
                    ? kPinnedStripElevation * condense
                    : 0,
                // Colour and shadow follow the scroll frame by frame
                // already; the surface's own ease would lag a fast scroll
                // and flash.
                animationDuration: Duration.zero,
                // It starts across the card at the plot's top and pins flush
                // under the header at the card's width, so only its bottom
                // corners round, like the card's own, condensing and pinned
                // alike (#4488).
                shape: RoundedRectangleBorder(borderRadius: card.corners),
                clipBehavior: Clip.antiAlias,
                child: CustomPaint(
                  // Its outline, where the theme's cards have one, on the sides
                  // and bottom only: its top crosses the card at the plot's top
                  // and pins flush under the header. It fades in with the
                  // surface.
                  foregroundPainter: PinnedStripOutlinePainter(
                    side: card.side.copyWith(
                      color: card.side.color.withValues(
                        alpha: card.side.color.a * background,
                      ),
                    ),
                    corners: card.corners,
                  ),
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
                            painter: stripPainter,
                            // Its own layer: moving the cursor repaints only
                            // the cursor.
                            foregroundPainter: PinnedStripCursorPainter(
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
          );
        },
      ),
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
