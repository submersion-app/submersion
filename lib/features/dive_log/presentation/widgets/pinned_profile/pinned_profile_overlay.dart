import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/ui/chart_viewport.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/pinned_strip_layer_animator.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/pinned_strip_layer_host.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_card_marker.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_cards_in_view.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/page_scroll_forwarder.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_profile_strip.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_painter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_plot_frame.dart';

/// Builds a live copy of the profile card that fills the height it is given,
/// its chart taking up the slack. [onPlotFrame] is handed to that chart so it
/// reports where its plot is, and [viewport] is the zoom window it shows.
typedef SquashedCardBuilder =
    Widget Function(
      BuildContext context,
      ValueChanged<ProfilePlotFrame> onPlotFrame,
      ChartViewport viewport,
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
/// 2. Hand-over. Part way into the squash, the strip fades in over the copy's
///    plot with its depth line exactly on the copy's, then condenses into
///    place, settling as the plot reaches the top. Only one depth line is
///    ever seen. The rest of the copy below its plot (its axis and legend)
///    then slides up under the settled strip, as the page does (#4579).
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
    this.chartViewport,
  });

  final Dive dive;
  final GlobalKey profileKey;
  final SquashedCardBuilder squashedCard;
  final Widget child;

  /// Whether anything is drawn at all. The overlay stays in the tree when it
  /// is not, so turning the strip on or off never moves [child], the page's
  /// scroll view, to a new parent, which would reset its position.
  final bool enabled;

  /// The zoom window of the full card's chart, if the reader has zoomed it.
  /// The copy starts there, so pinning never jumps the zoom, and zooms out
  /// to the whole dive as the page scrolls ([zoomOutProgress]). Read when
  /// the copy is built, not listened to: the full card is under the copy
  /// then and cannot be zoomed.
  final ValueListenable<ChartViewport>? chartViewport;

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

  /// The plot's measured height with no squash, or null until measured. Not
  /// derived from [_squashRange], which is clamped at 0 for a plot shorter
  /// than [kMinPlotHeight].
  double? _restPlotHeight;

  /// Whether the page, scrolled to [pixels], has the pinned card or strip
  /// over its top: the card's top is above the page's.
  bool coversTopAt(double pixels) {
    final card = _cardInContent;
    return widget.enabled && card != null && card.top - pixels < 0;
  }

  Rect? get _card => _cardInContent?.shift(Offset(0, -_pixels));

  /// The cards that add layers to the strip (issue #4562), their rects in
  /// scroll-content coordinates as last measured, and which of them are in
  /// view at the current scroll.
  final PinnedStripCardRegistry _cards = PinnedStripCardRegistry();
  Map<DiveDetailSectionId, Rect> _cardRects = const {};
  Set<DiveDetailSectionId> _inView = const {};

  @override
  void initState() {
    super.initState();
    _cards.onChanged = _scheduleMeasure;
    _scheduleMeasure();
  }

  /// Works out which marked cards are in view at the current scroll, and
  /// rebuilds only when that changes.
  void _updateInView() {
    final viewport = _lastConstraints?.maxHeight;
    // With the strip off nothing is drawn, so no card is worth tracking.
    final inView = !widget.enabled || viewport == null || !viewport.isFinite
        ? const <DiveDetailSectionId>{}
        : cardsInView(
            cardsInContent: _cardRects,
            pixels: _pixels,
            viewportHeight: viewport,
            previously: _inView,
          );
    if (!setEquals(inView, _inView)) setState(() => _inView = inView);
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
    _cardRects = widget.enabled && overlay is RenderBox
        ? _cards.measure(overlay, _pixels)
        : const {};
    _updateInView();
    final plotBox = boxOf(_copyFrame?.plotKey.currentContext);
    final copyBox = boxOf(_copyRootKey.currentContext);
    final measured = plotBox == null || copyBox == null
        ? null
        : plotBox.localToGlobal(Offset.zero, ancestor: copyBox) & plotBox.size;
    // While the copy is not built (pinned, or not yet pinned) its plot keeps
    // the place it last had: it is the card's layout, which does not move
    // while hidden. Forgetting it made the first frame of a fast scroll back
    // squash wrongly and flash the half-faded strip.
    final plot = measured ?? _copyPlot;
    // The plot takes all of the squash, so its resting height is its height
    // now plus the squash it was laid out with.
    final rest = measured == null
        ? _restPlotHeight
        : measured.height + _layoutSquash;
    final range = rest == null
        ? _squashRange
        : squashRangeFor(restPlotHeight: rest);
    // Only the plot's place and width are read when building; its height
    // follows from the squash, so a plot that only got shorter (every frame
    // of the squash) needs no second build.
    final plotMoved =
        plot?.topLeft != _copyPlot?.topLeft || plot?.width != _copyPlot?.width;
    if (card != _cardInContent ||
        plotMoved ||
        range != _squashRange ||
        rest != _restPlotHeight) {
      setState(() {
        _cardInContent = card;
        _copyPlot = plot;
        _squashRange = range;
        _restPlotHeight = rest;
      });
    } else {
      _copyPlot = plot;
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
  /// instead of trailing it by a frame. Its ranges are those of the zoom
  /// window [viewport] the copy is handed this frame, for the same reason.
  PlotMapping? _copyMappingAt(double squash, ChartViewport viewport) {
    final plot = _copyPlot;
    final frame = _copyFrame?.withViewport(viewport);
    if (plot == null || frame == null) return null;
    final restHeight = _restPlotHeight ?? _squashRange + kMinPlotHeight;
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
      final covers = coversTopAt(pixels);
      // Only a scroll that pins, moves or unpins the card needs a build; one
      // with nothing drawn either side (or the strip off), or with the strip
      // settled and the card gone from under it either side, just records
      // it.
      if ((wasIdle && !covers) || (_restingAt(_pixels) && _restingAt(pixels))) {
        _pixels = pixels;
      } else {
        setState(() => _pixels = pixels);
      }
      // Re-measured as the squash begins, as a backstop for anything that
      // moved the card unseen while nothing was drawn.
      if (wasIdle && covers) _scheduleMeasure();
      _updateInView();
    }
    // Content above the card can change height (a card loading in), so the
    // recorded position is refreshed once the frame is laid out.
    if (notification is ScrollEndNotification) _scheduleMeasure();
    return false;
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    if (notification.depth == 0) {
      _notePosition(notification);
      final pixels = notification.metrics.pixels;
      // A content resize can move the offset with the card staying put in
      // the content, which the measure alone would not rebuild for.
      if (pixels != _pixels) setState(() => _pixels = pixels);
      // Not judged here: the content may have resized, and the card rects
      // are from before it. The measure that follows judges them afresh.
      _scheduleMeasure();
    }
    return false;
  }

  /// The scroll past the card's top at which its plot reaches the top of the
  /// page: the squash and slide are done, and so is the hand-over.
  ///
  /// Until the copy has reported its plot, where that sits is unknown, and
  /// taking it as the card's top settled the strip for a frame on a first
  /// jump into the hand-over. The hand-over is then taken to run on until
  /// the card has all but left, so it never settles early.
  double get _plotAtTop {
    final plot = _copyPlot;
    if (plot != null) return _squashRange + plot.top;
    final card = _cardInContent;
    return card == null
        ? _squashRange
        : math.max(_squashRange, card.height - kPinnedStripHeight);
  }

  /// The scroll past the card's top at which the strip starts to fade in
  /// over the pinned copy.
  double get _handOverStart => _plotAtTop * kHandOverOverlap;

  /// The hand-over's progress with the page scrolled to [pixels], 0 when
  /// nothing is pinned. At 1 the strip is settled.
  double _handOverAt(double pixels) {
    final card = _cardInContent?.shift(Offset(0, -pixels));
    if (!widget.enabled || card == null || card.top >= 0) return 0;
    return condenseProgress(card: card, start: _handOverStart, end: _plotAtTop);
  }

  /// Whether, with the page scrolled to [pixels], the strip is settled and
  /// none of the card is left on screen below it: what is drawn no longer
  /// depends on the scroll.
  bool _restingAt(double pixels) {
    final card = _cardInContent?.shift(Offset(0, -pixels));
    return card != null && card.bottom <= 0 && _handOverAt(pixels) >= 1;
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
        final handOver = _handOverAt(_pixels);
        // The layers of the cards in view, eased in and out (issue #4562).
        // Always built, so the page never moves to a new parent.
        return PinnedStripLayerHost(
          dive: widget.dive,
          shown: pinned && handOver > 0,
          settled: pinned && handOver >= 1,
          cardsInView: _inView,
          builder: (context, layers) => _overPage(pinned ? card : null, layers),
        );
      },
    );
  }

  /// The page with what is pinned over it.
  Widget _overPage(Rect? card, StripLayerState layers) {
    final drawn = card == null ? null : _pinned(card, layers);
    // Clipped to the page here, not by the stack: a stack clips only for
    // a child placed past its edges, and the pinned box never is, though
    // the copy in it slides up past the page's top. Unclipped, that part
    // drew over the dive's header beside the strip (#4488).
    return ClipRect(
      child: Stack(
        children: [
          NotificationListener<ScrollMetricsNotification>(
            onNotification: _onMetrics,
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: PinnedStripCardScope(
                registry: _cards,
                child: widget.child,
              ),
            ),
          ),
          // Always mounted, empty while nothing is pinned: a drag that
          // unpins the card (dragging the copy back down) keeps scrolling
          // the page instead of stopping dead as its recognizer goes.
          Positioned.fromRect(
            key: const ValueKey('pinnedProfileBox'),
            rect: drawn?.box ?? Rect.zero,
            // It lies over the page, not in its scroll view: vertical drags
            // and wheel scrolls on it go on to the page.
            // A semantics container of its own while something is pinned:
            // the copy in it is rebuilt as the page reads the dive again
            // (after Set as primary, say), and merged into the page's node
            // it tripped the framework's `node.built` check (issue #4527).
            // Empty, it adds no node.
            child: Semantics(
              container: drawn != null,
              child: PageScrollForwarder(
                position: () => _pagePosition,
                child: drawn?.child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// What is pinned over the page for [card]: the [box] it all covers, on
  /// the overlay, and the [child] drawn in it. [animated] are the card layers
  /// the strip draws, and how far it has grown for them.
  ({Rect box, Widget child}) _pinned(Rect card, StripLayerState animated) {
    // One motion: the squash and the slide share the scroll, finishing
    // together as the plot reaches the top, and the strip starts to fade in
    // before they do, so no step starts or stops on its own.
    final range = _squashRange;
    final plotTop = _copyPlot?.top ?? 0;
    final squash = squashDepth(card: card, range: range, plotTop: plotTop);
    _layoutSquash = squash;
    final t = condenseProgress(
      card: card,
      start: _handOverStart,
      end: _plotAtTop,
    );
    // The full chart is covered well before its plot reaches the top, so
    // none of its data is seen leaving the view.
    const fadeEnd = kCondenseFadeEnd;
    final morph = condenseMorphProgress(t, fadeEnd: fadeEnd);
    // What is left of the strip's growth runs with the morph, so however
    // fast the page is scrolled it is complete as the strip settles, and the
    // strip never grows after (#4579).
    final layers = animated.condensedBy(morph);
    // The copy, on the page: at the card's place, slid up by its share of
    // the scroll.
    final copyOrigin = Offset(
      card.left,
      -slideDepth(card: card, range: range, plotTop: plotTop),
    );
    // Zoomed in on the full card, the copy starts at its window and zooms
    // out to the whole dive by the time its plot reaches the top.
    final viewport = ChartViewport.lerp(
      widget.chartViewport?.value ?? ChartViewport.reset,
      ChartViewport.reset,
      zoomOutProgress(card: card, plotAtTop: range + plotTop),
    );
    final copy = _copyMappingAt(squash, viewport);

    // The strip grows out of the plot alone, inside the card's margin: only
    // the part that becomes the strip fades, while the header and legend
    // above stay clear and slide off as they are. A see-through surface over
    // the whole card washed it all grey.
    final margin =
        (Theme.of(context).cardTheme.margin ?? const EdgeInsets.all(4)).resolve(
          Directionality.of(context),
        );
    final plotOnPage = copy?.rect.shift(copyOrigin);
    // Only the plot becomes the strip: it starts on the plot, held in view,
    // and the card below the plot (its axis and legend) is never under it,
    // so the strip is never a tall, mostly empty box (#4579). Without a
    // plot from the copy, it covers the card to its bottom instead.
    final keptPlot = copy?.shift(copyOrigin).keptInView().rect;
    // Across, it starts on the plot too, inside the chart's axes, and widens
    // with its curve: a surface at the card's width from the start showed as
    // blank bands beside the curve. It stays within the card's margin.
    final innerLeft = card.left + margin.left;
    final innerRight = card.right - margin.right;
    final from = Rect.fromLTRB(
      math.max(innerLeft, plotOnPage?.left ?? innerLeft),
      math.max(0, plotOnPage?.top ?? 0),
      math.min(innerRight, plotOnPage?.right ?? innerRight),
      keptPlot?.bottom ?? math.max(card.bottom - margin.bottom, 0),
    );
    // Pinned, it is the card's width, so it is only as wide as the other
    // cards on the page (#4488): the condense moves its top up to the
    // page's, its sides out to the card's margin and its bottom to the
    // strip's height.
    // Its line layers grow it (issue #4562), already while it condenses, so
    // it heads straight for the height it settles at (#4579).
    final stripHeight =
        kPinnedStripHeight +
        layers.grow * (kPinnedStripGrownHeight - kPinnedStripHeight);
    final toward = Rect.lerp(
      from,
      Rect.fromLTRB(innerLeft, 0, innerRight, stripHeight),
      morph,
    )!;
    // Its bottom never rises above the copy's plot, or the full chart would
    // show beneath it as it shrinks; the plot slides up under it instead.
    final stripBox = Rect.fromLTRB(
      toward.left,
      toward.top,
      toward.right,
      math.max(toward.bottom, plotOnPage?.bottom ?? toward.bottom),
    );

    // Everything drawn, which always covers all of the card still on screen.
    final box = Rect.fromLTRB(
      math.min(card.left, stripBox.left),
      0,
      math.max(card.right, stripBox.right),
      math.max(card.bottom, stripBox.bottom),
    );
    final copyAt = copyOrigin - box.topLeft;
    final stripAt = stripBox.shift(-box.topLeft);
    return (
      box: box,
      child: Stack(
        // Settled, the box is the strip's own size, so clipping to it cut
        // off the strip's whole shadow, which falls below it onto the page
        // (#4488). The overlay clips everything to the page instead.
        clipBehavior: Clip.none,
        children: [
          // The live copy: squashed to what is left of the card, then
          // sliding up at its squashed height, header first, as the card
          // itself would; it keeps the card's width while the strip takes
          // over on top of it. It is the card the reader sees, so it is
          // the one they use: it takes taps and hovers itself. It stays
          // while any of the card is on screen, sliding up under the
          // settled strip.
          if (card.bottom > 0)
            Positioned(
              key: const ValueKey('pinnedSquashedCard'),
              left: copyAt.dx,
              top: copyAt.dy,
              width: card.width,
              height: card.height - squash,
              child: KeyedSubtree(
                key: _copyRootKey,
                child: widget.squashedCard(context, _onCopyFrame, viewport),
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
                  layers: layers,
                  condense: morph,
                  backgroundOpacity: condenseBackgroundOpacity(
                    t,
                    fadeEnd: fadeEnd,
                  ),
                  // Where the strip's line starts: the copy's, once the copy
                  // slides its plot past the top held at the top instead,
                  // so the line never leaves the view; handed so the
                  // painter's blend keeps it on the box's edges as the box
                  // widens ([morphStartFor]).
                  // Settled, the strip draws its own curve alone, so it
                  // does not repaint for a mapping that moves with the
                  // scroll but is no longer used.
                  morphFrom: morph >= 1 || copy == null
                      ? null
                      : morphStartFor(
                          start: copy.shift(copyOrigin).keptInView(),
                          // Where the strip's own curve area ends up, on the
                          // page: across the pinned strip, under the top.
                          end: pinnedStripCurveRect(
                            Size(innerRight - innerLeft, stripHeight),
                            curveHeight: stripHeight,
                          ).shift(Offset(innerLeft, 0)),
                          box: stripBox,
                          own: pinnedStripCurveRect(
                            stripBox.size,
                            curveHeight: stripHeight,
                          ),
                          morph: morph,
                        ),
                ),
              ),
            ),
        ],
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
  // Room for the grown strip: the section it lands on may well add a line
  // layer, and the strip grows after the landing (issue #4562).
  final room = overlay.coversTopAt(reveal.offset)
      ? kPinnedStripGrownHeight
      : 0.0;
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
