import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_profile_strip.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';

/// The share of the condense over which the strip fades in over the card.
const double _fadeInPortion = 0.25;

/// Pins a thin, scrubbable profile strip over the top of [child], the dive
/// details scroll view, once the profile card ([profileKey]) has scrolled
/// away (issue #4423).
///
/// While the card's last stretch leaves the viewport, the strip itself fades
/// in over the card's footprint and condenses into place; the live chart is
/// never transformed. Nothing here takes space in the scroll
/// content, so the page never reflows.
class PinnedProfileOverlay extends StatefulWidget {
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
  State<PinnedProfileOverlay> createState() => _PinnedProfileOverlayState();
}

class _PinnedProfileOverlayState extends State<PinnedProfileOverlay> {
  /// The card's rect in scroll-content coordinates (its top as if the page
  /// were scrolled to 0), or null when the card is not on the page.
  Rect? _cardInContent;
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
    final card = widget.profileKey.currentContext?.findRenderObject();
    Rect? inContent;
    if (overlay is RenderBox &&
        card is RenderBox &&
        card.attached &&
        card.hasSize) {
      final topLeft = card.localToGlobal(Offset.zero, ancestor: overlay);
      inContent = (topLeft & card.size).shift(Offset(0, _pixels));
    }
    if (inContent != _cardInContent) {
      setState(() => _cardInContent = inContent);
    }
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
    final card = _card;
    final t = _progress;
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
            // so the morph has no cut. It fades in over the start of the
            // condense, while the real card is still mostly on screen beneath
            // it, and only takes input once pinned.
            if (card != null && t > 0)
              Positioned.fromRect(
                rect: condenseRect(
                  card: card,
                  width: constraints.maxWidth,
                  t: t,
                ),
                child: IgnorePointer(
                  ignoring: t < 1,
                  child: Opacity(
                    opacity: (t / _fadeInPortion).clamp(0.0, 1.0),
                    child: PinnedProfileStrip(dive: widget.dive, condense: t),
                  ),
                ),
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
