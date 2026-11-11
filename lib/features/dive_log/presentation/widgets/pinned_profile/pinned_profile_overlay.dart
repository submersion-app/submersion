import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_profile_strip.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_plot_frame.dart';

/// Pins a thin, scrubbable profile strip over the top of [child], the dive
/// details scroll view, once the profile card ([profileKey]) has scrolled
/// away (issue #4423).
///
/// While the card's last stretch leaves the viewport the strip condenses out
/// of it in two phases. First its depth line lies exactly on the full
/// chart's (the chart reports where its plot is, [profilePlotFrameProvider])
/// while its surface fades in over the card, hiding the chart's own line;
/// then the one line left morphs into the strip. Only one depth line is ever
/// seen. Nothing here takes space in the scroll content, so the page never
/// reflows.
class PinnedProfileOverlay extends ConsumerStatefulWidget {
  const PinnedProfileOverlay({
    super.key,
    required this.dive,
    required this.profileKey,
    required this.child,
  });

  final Dive dive;
  final GlobalKey profileKey;
  final Widget child;

  @override
  ConsumerState<PinnedProfileOverlay> createState() =>
      _PinnedProfileOverlayState();
}

class _PinnedProfileOverlayState extends ConsumerState<PinnedProfileOverlay> {
  /// The card's rect in scroll-content coordinates (its top as if the page
  /// were scrolled to 0), or null when the card is not on the page.
  Rect? _cardInContent;

  /// The chart's plot rect, in scroll-content coordinates like the card's.
  Rect? _plotInContent;

  /// The plot frame [_plotInContent] was measured for.
  ProfilePlotFrame? _measuredFrame;
  double _pixels = 0;

  /// Whether the strip is fully pinned, rather than still condensing.
  bool get showingStrip => _progress >= 1;

  Rect? get _card => _cardInContent?.shift(Offset(0, -_pixels));

  double get _progress {
    final card = _card;
    return card == null ? 0 : condenseProgress(cardBottom: card.bottom);
  }

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
  }

  /// Records where the card sits in the scroll content. Runs after layout,
  /// when positions are current; scrolling in between needs no layout,
  /// because the card's on-screen top is its content top minus the offset.
  void _measure() {
    final overlay = context.findRenderObject();
    final frame = ref.read(profilePlotFrameProvider(widget.dive.id));
    Rect? inContent(BuildContext? target) {
      final box = target?.findRenderObject();
      if (overlay is! RenderBox ||
          box is! RenderBox ||
          !box.attached ||
          !box.hasSize) {
        return null;
      }
      final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
      return (topLeft & box.size).shift(Offset(0, _pixels));
    }

    final card = inContent(widget.profileKey.currentContext);
    final plot = inContent(frame?.plotKey.currentContext);
    if (card != _cardInContent ||
        plot != _plotInContent ||
        frame != _measuredFrame) {
      setState(() {
        _cardInContent = card;
        _plotInContent = plot;
        _measuredFrame = frame;
      });
    }
  }

  /// Where the chart draws its depth line right now, in overlay coordinates.
  PlotMapping? get _chartMapping {
    final plot = _plotInContent;
    final frame = _measuredFrame;
    if (plot == null || frame == null) return null;
    return PlotMapping(
      rect: plot.shift(Offset(0, -_pixels)),
      minSeconds: frame.minSeconds,
      maxSeconds: frame.maxSeconds,
      minDepthMeters: frame.minDepthMeters,
      maxDepthMeters: frame.maxDepthMeters,
    );
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final pixels = notification.metrics.pixels;
    if (pixels != _pixels) setState(() => _pixels = pixels);
    // Content above the card can change height (a card loading in), so the
    // recorded position is refreshed once the frame is laid out.
    if (notification is ScrollEndNotification) _scheduleMeasure();
    return false;
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    if (notification.depth == 0) {
      _pixels = notification.metrics.pixels;
      _scheduleMeasure();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // A new plot frame (the chart laid out, zoomed or panned) is measured
    // once the frame it arrived in is laid out.
    if (ref.watch(profilePlotFrameProvider(widget.dive.id)) != _measuredFrame) {
      _scheduleMeasure();
    }
    final card = _card;
    final t = _progress;
    final morph = condenseMorphProgress(t);
    final chart = _chartMapping;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            NotificationListener<ScrollMetricsNotification>(
              onNotification: _onMetrics,
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: widget.child,
              ),
            ),
            // One strip, at one place in the tree, from the first pixel of
            // the condense to pinned: it is never swapped for another widget,
            // so the morph has no cut. It takes input only once pinned.
            if (card != null && t > 0)
              Builder(
                builder: (context) {
                  final box = condenseRect(
                    card: card,
                    width: constraints.maxWidth,
                    t: morph,
                  );
                  return Positioned.fromRect(
                    rect: box,
                    child: IgnorePointer(
                      ignoring: t < 1,
                      child: PinnedProfileStrip(
                        dive: widget.dive,
                        condense: morph,
                        backgroundOpacity: condenseBackgroundOpacity(t),
                        // The chart's line, in the strip's own coordinates.
                        morphFrom: chart?.shift(-box.topLeft),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

/// [Scrollable.ensureVisible] for a section of a page that may be showing
/// the pinned profile strip: while the strip shows, the section lands just
/// below it instead of under it.
Future<void> ensureVisibleBelowPinnedStrip(
  BuildContext target, {
  Duration duration = Duration.zero,
  Curve curve = Curves.ease,
  double alignment = 0,
}) {
  final overlay = target.findAncestorStateOfType<_PinnedProfileOverlayState>();
  final object = target.findRenderObject();
  if (overlay == null || !overlay.showingStrip || object == null) {
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
  final offset = (reveal.offset - kPinnedStripHeight).clamp(
    position.minScrollExtent,
    position.maxScrollExtent,
  );
  if (duration == Duration.zero) {
    position.jumpTo(offset);
    return Future.value();
  }
  return position.animateTo(offset, duration: duration, curve: curve);
}
