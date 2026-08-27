import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Previous / next controls for a fullscreen media pager.
///
/// Sits in the viewer's [Stack] alongside the other chrome overlays and is
/// mounted only while the chrome is showing, so tapping the photo hides these
/// with the rest of it.
///
/// The widget covers the whole viewer so the buttons can pin themselves to its
/// left and right edges. That is safe on top of the viewer's full-bleed
/// tap-to-toggle target: a [Row] does not hit-test its empty space, so only
/// the two buttons consume pointers and centre taps fall through to the
/// toggle beneath.
class MediaNavArrows extends StatelessWidget {
  const MediaNavArrows({
    super.key,
    required this.currentIndex,
    required this.totalCount,
    required this.onPrevious,
    required this.onNext,
  });

  /// Zero-based index of the item on screen.
  final int currentIndex;

  /// Number of items in the pager (documents already filtered out).
  final int totalCount;

  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    // A single-item gallery has nowhere to go.
    if (totalCount < 2) return const SizedBox.shrink();

    final hasPrevious = currentIndex > 0;
    final hasNext = currentIndex < totalCount - 1;

    // In RTL the pager itself runs the other way (a horizontal PageView takes
    // its axis direction from Directionality), and the Row below flips the
    // buttons onto the opposite edges. The chevrons are not auto-mirrored, so
    // they have to be swapped by hand to keep pointing the way the page moves.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final previousIcon = rtl ? Icons.chevron_right : Icons.chevron_left;
    final nextIcon = rtl ? Icons.chevron_left : Icons.chevron_right;

    return Positioned.fill(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            // Each end drops the arrow that would be a no-op rather than
            // parking a disabled control over the photo; spaceBetween keeps
            // the surviving one on its own edge.
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (hasPrevious)
                _NavArrow(
                  icon: previousIcon,
                  tooltip: context.l10n.media_photoViewer_previousTooltip,
                  onPressed: onPrevious,
                )
              else
                const SizedBox.shrink(),
              if (hasNext)
                _NavArrow(
                  icon: nextIcon,
                  tooltip: context.l10n.media_photoViewer_nextTooltip,
                  onPressed: onNext,
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single circular chevron button, legible over any photo.
class _NavArrow extends StatelessWidget {
  const _NavArrow({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.4),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        iconSize: 32,
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
