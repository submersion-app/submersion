import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/page_scroll_forwarder.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_profile_strip.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_plot_frame.dart';

/// Builds a live copy of the profile card that fills the height it is given,
/// its chart taking up the slack. [onPlotFrame] is handed to that chart so it
/// reports where its plot is.
typedef SquashedCardBuilder =
    Widget Function(
      BuildContext context,
      ValueChanged<ProfilePlotFrame> onPlotFrame,
    );

/// Pins the profile card to the top of [child], the dive details scroll view,
/// as it scrolls away, and condenses it into a thin, scrubbable strip
/// (issue #4423).
///
/// It runs in two phases, driven by the scroll so it plays at the reader's
/// pace and reverses:
///
/// 1. Squash. The moment the card's top passes the top of the page, a live
///    copy of it ([squashedCard]) pins there, laid out to exactly the height
///    of the card still on screen. The header and footer keep their size and
///    the chart gets shorter, with its axes, grid and every line intact.
/// 2. Hand-over. Once the chart is down to its last [kSquashRange], the strip
///    fades in over the copy with its depth line exactly on the copy's, then
///    condenses into place. Only one depth line is ever seen.
///
/// Whatever is drawn always covers all of the card still on screen, so the
/// real card never shows around it, and nothing here takes space in the
/// scroll content, so the page never reflows.
class PinnedProfileOverlay extends StatefulWidget {
  const PinnedProfileOverlay({
    super.key,
    required this.dive,
    required this.profileKey,
    required this.squashedCard,
    required this.child,
    this.enabled = true,
  });

  final Dive dive;
  final GlobalKey profileKey;
  final SquashedCardBuilder squashedCard;
  final Widget child;

  /// Whether anything is drawn at all. The overlay stays in the tree when it
  /// is not, so turning the strip on or off never moves [child], the page's
  /// scroll view, to a new parent, which would reset its position.
  final bool enabled;

  @override
  State<PinnedProfileOverlay> createState() => _PinnedProfileOverlayState();
}

class _PinnedProfileOverlayState extends State<PinnedProfileOverlay> {
  /// The card's rect in scroll-content coordinates (its top as if the page
  /// were scrolled to 0), or null when the card is not on the page.
  Rect? _cardInContent;
  double _pixels = 0;

  /// The pinned copy's latest plot frame, and where that plot sits within
  /// the copy (its offset from the copy's top-left).
  ProfilePlotFrame? _copyFrame;
  Rect? _copyPlot;

  /// Marks the copy's root, to measure its plot against.
  final GlobalKey _copyRootKey = GlobalKey();

  /// How far the copy can squash, from its measured plot; and the squash it
  /// was last laid out with, which that measurement adds back to find the
  /// plot's resting height.
  double _squashRange = kSquashRange;
  double _layoutSquash = 0;

  /// Whether the page, scrolled to [pixels], has the pinned card or strip
  /// over its top: the card's top is above the page's.
  bool coversTopAt(double pixels) {
    final card = _cardInContent;
    return widget.enabled && card != null && card.top - pixels < 0;
  }

  Rect? get _card => _cardInContent?.shift(Offset(0, -_pixels));

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(PinnedProfileOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
    // A post-frame callback waits for a frame; make sure one comes, or a
    // change reported between frames goes unmeasured until something else
    // repaints.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// The overlay's last constraints: a resize moves the card without any
  /// scrolling, so it is re-measured.
  BoxConstraints? _lastConstraints;

  /// Records where the card sits in the scroll content, and where the pinned
  /// copy's plot is. Runs after layout, when positions are current;
  /// scrolling in between needs no layout, because the card's on-screen top
  /// is its content top minus the offset.
  void _measure() {
    final overlay = context.findRenderObject();
    RenderBox? boxOf(BuildContext? target) {
      final box = target?.findRenderObject();
      return overlay is RenderBox &&
              box is RenderBox &&
              box.attached &&
              box.hasSize
          ? box
          : null;
    }

    Rect? onOverlay(RenderBox? box) => box == null
        ? null
        : box.localToGlobal(Offset.zero, ancestor: overlay! as RenderBox) &
              box.size;

    final card = onOverlay(
      boxOf(widget.profileKey.currentContext),
    )?.shift(Offset(0, _pixels));
    final plotBox = boxOf(_copyFrame?.plotKey.currentContext);
    final copyBox = boxOf(_copyRootKey.currentContext);
    final plot = plotBox == null || copyBox == null
        ? null
        : plotBox.localToGlobal(Offset.zero, ancestor: copyBox) & plotBox.size;
    // The plot takes all of the squash, so its resting height is its height
    // now plus the squash it was laid out with.
    final range = plot == null
        ? _squashRange
        : squashRangeFor(restPlotHeight: plot.height + _layoutSquash);
    if (card != _cardInContent || plot != _copyPlot || range != _squashRange) {
      setState(() {
        _cardInContent = card;
        _copyPlot = plot;
        _squashRange = range;
      });
    }
  }

  /// The copy's chart reports its plot after each layout; a change (the
  /// squash, a resize, a zoom) is measured once that frame is laid out.
  void _onCopyFrame(ProfilePlotFrame frame) {
    if (frame == _copyFrame) return;
    _copyFrame = frame;
    // The chart reports after its layout, so positions are already current:
    // measured now, a frame sooner than scheduling would.
    if (mounted) _measure();
  }

  /// Where the pinned copy draws its depth line, relative to the copy.
  ///
  /// Worked out for this frame's [squash] rather than read from the last
  /// measurement: the plot keeps its place and width and is shorter by the
  /// squash, so the strip's line stays on the chart's while both move,
  /// instead of trailing it by a frame.
  PlotMapping? _copyMappingAt(double squash) {
    final plot = _copyPlot;
    final frame = _copyFrame;
    if (plot == null || frame == null) return null;
    final restHeight = _squashRange + kMinPlotHeight;
    return PlotMapping(
      rect: Rect.fromLTWH(
        plot.left,
        plot.top,
        plot.width,
        (restHeight - squash).clamp(1.0, double.infinity),
      ),
      minSeconds: frame.minSeconds,
      maxSeconds: frame.maxSeconds,
      minDepthMeters: frame.minDepthMeters,
      maxDepthMeters: frame.maxDepthMeters,
    );
  }

  /// The page's scroll position, so the strip, which lies over the page
  /// rather than inside its scroll view, can hand vertical drags and wheel
  /// scrolls on to it.
  ScrollPosition? _pagePosition;

  void _notePosition(Notification notification) {
    final context = switch (notification) {
      ScrollNotification(:final context) => context,
      ScrollMetricsNotification(:final context) => context,
      _ => null,
    };
    if (context != null && context.mounted) {
      _pagePosition = Scrollable.maybeOf(context)?.position ?? _pagePosition;
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    _notePosition(notification);
    final pixels = notification.metrics.pixels;
    if (pixels != _pixels) {
      final wasIdle = !coversTopAt(_pixels);
      setState(() => _pixels = pixels);
      // Re-measured as the squash begins, as a backstop for anything that
      // moved the card unseen while nothing was drawn.
      if (wasIdle && coversTopAt(_pixels)) _scheduleMeasure();
    }
    // Content above the card can change height (a card loading in), so the
    // recorded position is refreshed once the frame is laid out.
    if (notification is ScrollEndNotification) _scheduleMeasure();
    return false;
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    if (notification.depth == 0) {
      _notePosition(notification);
      _pixels = notification.metrics.pixels;
      _scheduleMeasure();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    final pinned = widget.enabled && card != null && card.top < 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints != _lastConstraints) {
          _lastConstraints = constraints;
          _scheduleMeasure();
        }
        return Stack(
          children: [
            NotificationListener<ScrollMetricsNotification>(
              onNotification: _onMetrics,
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: widget.child,
              ),
            ),
            if (pinned) _pinned(card, constraints.maxWidth),
          ],
        );
      },
    );
  }

  Widget _pinned(Rect card, double width) {
    // One motion: the squash and the slide share the scroll, finishing
    // together as the plot reaches the top, and the strip starts to fade in
    // before they do, so no step starts or stops on its own.
    final range = _squashRange;
    final plotTop = _copyPlot?.top ?? 0;
    final squash = squashDepth(card: card, range: range, plotTop: plotTop);
    _layoutSquash = squash;
    final start = (range + plotTop) * kHandOverOverlap;
    final t = condenseProgress(card: card, start: start);
    final morph = condenseMorphProgress(t);
    // The copy, on the page: at the card's place, slid up by its share of
    // the scroll.
    final copyOrigin = Offset(
      card.left,
      -slideDepth(card: card, range: range, plotTop: plotTop),
    );
    final copy = _copyMappingAt(squash);

    // The strip grows out of the plot alone, inside the card's margin: only
    // the part that becomes the strip fades, while the header and legend
    // above stay clear and slide off as they are. A see-through surface over
    // the whole card washed it all grey.
    final margin =
        (Theme.of(context).cardTheme.margin ?? const EdgeInsets.all(4)).resolve(
          Directionality.of(context),
        );
    final plotOnPage = copy?.rect.shift(copyOrigin);
    final from = Rect.fromLTRB(
      card.left + margin.left,
      math.max(0, plotOnPage?.top ?? 0),
      card.right - margin.right,
      math.max(card.bottom - margin.bottom, 0),
    );
    final stripBox = Rect.lerp(
      from,
      Rect.fromLTWH(0, 0, width, kPinnedStripHeight),
      morph,
    )!;

    // Everything drawn, which always covers all of the card still on screen.
    final box = Rect.fromLTRB(
      math.min(card.left, stripBox.left),
      0,
      math.max(card.right, stripBox.right),
      math.max(card.bottom, stripBox.bottom),
    );
    final copyAt = copyOrigin - box.topLeft;
    final stripAt = stripBox.shift(-box.topLeft);
    return Positioned.fromRect(
      key: const ValueKey('pinnedProfileBox'),
      rect: box,
      // It lies over the page, not in its scroll view: vertical drags and
      // wheel scrolls on it go on to the page.
      child: PageScrollForwarder(
        position: () => _pagePosition,
        child: Stack(
          children: [
            // The live copy: squashed to what is left of the card, then
            // sliding up at its squashed height, header first, as the card
            // itself would; it keeps the card's width while the strip takes
            // over on top of it. It is the card the reader sees, so it is
            // the one they use: it takes taps and hovers itself.
            if (t < 1)
              Positioned(
                key: const ValueKey('pinnedSquashedCard'),
                left: copyAt.dx,
                top: copyAt.dy,
                width: card.width,
                height: card.height - squash,
                child: KeyedSubtree(
                  key: _copyRootKey,
                  child: widget.squashedCard(context, _onCopyFrame),
                ),
              ),
            // Keyed, so it stays the same strip when the copy drops out.
            if (t > 0)
              Positioned.fromRect(
                key: const ValueKey('pinnedStrip'),
                rect: stripAt,
                child: IgnorePointer(
                  ignoring: t < 1,
                  child: PinnedProfileStrip(
                    dive: widget.dive,
                    condense: morph,
                    backgroundOpacity: condenseBackgroundOpacity(t),
                    // The copy's line, in the strip's own coordinates.
                    morphFrom: copy?.shift(copyAt - stripAt.topLeft),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// [Scrollable.ensureVisible] for a section of a page that may be showing
/// the pinned profile: when the card will be pinned where the page ends up,
/// the section lands just below the strip instead of under it.
Future<void> ensureVisibleBelowPinnedStrip(
  BuildContext target, {
  Duration duration = Duration.zero,
  Curve curve = Curves.ease,
  double alignment = 0,
}) {
  final overlay = target.findAncestorStateOfType<_PinnedProfileOverlayState>();
  final object = target.findRenderObject();
  if (overlay == null || object == null) {
    return Scrollable.ensureVisible(
      target,
      duration: duration,
      curve: curve,
      alignment: alignment,
    );
  }
  final position = Scrollable.of(target).position;
  final reveal = RenderAbstractViewport.of(
    object,
  ).getOffsetToReveal(object, alignment);
  // Decided by where the page ends up, not where it is: the jump usually
  // starts from the profile card itself, and the strip pins on the way.
  final room = overlay.coversTopAt(reveal.offset) ? kPinnedStripHeight : 0.0;
  final offset = (reveal.offset - room).clamp(
    position.minScrollExtent,
    position.maxScrollExtent,
  );
  if (duration == Duration.zero) {
    position.jumpTo(offset);
    return Future.value();
  }
  return position.animateTo(offset, duration: duration, curve: curve);
}
