import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_position.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_painter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_values.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Corner radius of the profile card the strip condenses out of.
const double _cardRadius = 12;

/// The thin, scrubbable dive profile pinned at the top of dive details once
/// the full profile card scrolls away (issue #4423).
///
/// It reads and writes the same shared cursor as the full chart,
/// [profileTrackingIndexProvider], so every card that follows the chart
/// follows the strip too. Like the full chart, lifting a finger or moving the
/// mouse away clears the cursor.
///
/// The same widget draws the condense itself, so it never swaps for another
/// at any point: below [condense] 1 it fills whatever box it is given (the
/// shrinking footprint of the profile card), its corners rounding like the
/// card's and its values row fading in. Its depth line starts exactly on the
/// full chart's ([morphFrom]) and moves continuously into the strip, so only
/// one depth line is ever seen.
class PinnedProfileStrip extends ConsumerStatefulWidget {
  const PinnedProfileStrip({
    super.key,
    required this.dive,
    this.condense = 1,
    this.backgroundOpacity = 1,
    this.morphFrom,
    this.pageScroll,
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

  /// The page's scroll position. The strip lies over the page rather than
  /// inside its scroll view, so vertical drags and wheel scrolls that start
  /// on it are handed on to the page, which scrolls as if they started on it.
  final ScrollPosition? Function()? pageScroll;

  @override
  ConsumerState<PinnedProfileStrip> createState() => _PinnedProfileStripState();
}

class _PinnedProfileStripState extends ConsumerState<PinnedProfileStrip> {
  /// Whether the hint speaks to touch. Starts from the platform and follows
  /// whichever kind of pointer last reached the strip.
  late bool _touch = switch (defaultTargetPlatform) {
    TargetPlatform.iOS ||
    TargetPlatform.android ||
    TargetPlatform.fuchsia => true,
    _ => false,
  };

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
    _write(indexForTimestamp(profile, seconds.round()));
  }

  /// The page drag a vertical gesture on the strip is driving.
  Drag? _pageDrag;

  /// Hands a mouse wheel or trackpad scroll over the strip to the page.
  void _forwardWheel(PointerSignalEvent event) {
    final position = widget.pageScroll?.call();
    if (event is! PointerScrollEvent || position == null) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final scroll = e as PointerScrollEvent;
      position.pointerScroll(scroll.scrollDelta.dy);
    });
  }

  @override
  void dispose() {
    _pageDrag?.cancel();
    super.dispose();
  }

  void _noteKind(PointerDeviceKind kind) {
    final touch =
        kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.stylus ||
        kind == PointerDeviceKind.invertedStylus;
    if (touch != _touch) setState(() => _touch = touch);
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
    final values = pinnedStripValuesAt(
      chartProfile: profile,
      analysis: analysis,
      cursorIndex: cursor,
    );
    final colors = Theme.of(context).colorScheme;
    final selectedSeconds =
        cursor != null && cursor >= 0 && cursor < profile.length
        ? profile[cursor].timestamp
        : null;

    final condense = widget.condense.clamp(0.0, 1.0);
    final background = widget.backgroundOpacity.clamp(0.0, 1.0);
    return Semantics(
      container: true,
      label: context.l10n.diveLog_pinnedStrip_semantics,
      child: Material(
        // The card's own colour, so the strip reads as the card condensing.
        color: colors.surfaceContainerLow.withValues(
          alpha: colors.surfaceContainerLow.a * background,
        ),
        // No shadow while the surface is see-through (it would show through
        // and grey the card), then one that grows with the condense, so it
        // never switches on or off in a single frame either way.
        elevation: background >= 1 ? 2 * condense : 0,
        borderRadius: BorderRadius.circular(_cardRadius * (1 - condense)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: condense >= 1 ? kPinnedStripHeight : null,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Listener(
                onPointerDown: (e) => _noteKind(e.kind),
                onPointerHover: (e) => _noteKind(e.kind),
                onPointerSignal: _forwardWheel,
                child: MouseRegion(
                  onHover: (e) => _scrubTo(e.localPosition.dx, width, profile),
                  onExit: (_) => _write(null),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) =>
                        _scrubTo(d.localPosition.dx, width, profile),
                    onTapUp: (_) => _write(null),
                    onTapCancel: () => _write(null),
                    onHorizontalDragStart: (d) =>
                        _scrubTo(d.localPosition.dx, width, profile),
                    onHorizontalDragUpdate: (d) =>
                        _scrubTo(d.localPosition.dx, width, profile),
                    onHorizontalDragEnd: (_) => _write(null),
                    onHorizontalDragCancel: () => _write(null),
                    // Vertical drags scroll the page, with its own physics
                    // (fling included), as if they had started on it.
                    onVerticalDragStart: widget.pageScroll == null
                        ? null
                        : (d) => _pageDrag = widget.pageScroll!()?.drag(
                            d,
                            () => _pageDrag = null,
                          ),
                    onVerticalDragUpdate: widget.pageScroll == null
                        ? null
                        : (d) => _pageDrag?.update(d),
                    onVerticalDragEnd: widget.pageScroll == null
                        ? null
                        : (d) => _pageDrag?.end(d),
                    onVerticalDragCancel: widget.pageScroll == null
                        ? null
                        : () => _pageDrag?.cancel(),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          // Cross-fades with the surface: drawn on the chart's
                          // own line and shading, so at full strength the two
                          // shadings would stack into a darker blue.
                          child: Opacity(
                            opacity: background,
                            child: CustomPaint(
                              painter: PinnedStripPainter(
                                profile: profile,
                                selectedSeconds: selectedSeconds,
                                curveColor: ProfileMetricColors.depth,
                                // The full chart's depth shading.
                                fillColors: GasColors.gradientColors(
                                  ProfileMetricColors.depth,
                                ),
                                markerColor: colors.primary,
                                from: widget.morphFrom,
                                morph: condense,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: kPinnedStripRowHeight,
                          child: Opacity(
                            opacity: condense,
                            child: values == null
                                ? _Hint(touch: _touch)
                                : _ValuesRow(values: values, units: units),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.touch});

  final bool touch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        touch
            ? context.l10n.diveLog_pinnedStrip_hintDrag
            : context.l10n.diveLog_pinnedStrip_hintHover,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _ValuesRow extends StatelessWidget {
  const _ValuesRow({required this.values, required this.units});

  final PinnedStripValues values;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Row(
      children: [
        for (final text in formatPinnedStripValues(values, units, context.l10n))
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
      ],
    );
  }
}
