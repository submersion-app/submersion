import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Minus / level / plus, led by a reset button once zoomed.
///
/// Extracted from the dive profile legend so the statistics trend charts get
/// the same control rather than a lookalike. Zooming in with no visible way
/// back out is the state this exists to prevent.
class ChartZoomControls extends StatelessWidget {
  const ChartZoomControls({
    super.key,
    required this.zoomLevel,
    required this.minZoom,
    required this.maxZoom,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
    this.keyPrefix,
    this.dense = false,
  });

  final double zoomLevel;
  final double minZoom;
  final double maxZoom;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;

  /// Distinguishes several control rows on one page, as the statistics pages
  /// stack a chart per card.
  final String? keyPrefix;

  /// Drops the buttons' padded 48px tap targets to the 32px box they already
  /// declare, making the row 32px tall instead of 48.
  ///
  /// For hosts where these controls share a line with dense content and the
  /// spare height reads as a band of dead space - the dive profile legend
  /// sits directly above its chart. Off by default: a padded tap target is
  /// the better default on touch.
  final bool dense;

  Key? _key(String name) =>
      keyPrefix == null ? null : ValueKey('$keyPrefix-$name');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isZoomed = zoomLevel > minZoom;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Leads the row so that appearing does not displace the buttons: the
        // hosts pin these controls to the trailing edge, so a trailing reset
        // button would slide minus/plus left and land on the plus the user
        // just clicked.
        if (isZoomed)
          IconButton(
            key: _key('zoom-reset'),
            onPressed: onResetZoom,
            icon: const Icon(Icons.fit_screen),
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            style: dense
                ? IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )
                : null,
            tooltip: context.l10n.diveLog_profile_tooltip_resetZoom,
          ),
        IconButton(
          key: _key('zoom-out'),
          onPressed: zoomLevel > minZoom ? onZoomOut : null,
          icon: const Icon(Icons.remove),
          iconSize: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          style: dense
              ? IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )
              : null,
          tooltip: context.l10n.diveLog_profile_tooltip_zoomOut,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '${zoomLevel.toStringAsFixed(1)}x',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: isZoomed
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        IconButton(
          key: _key('zoom-in'),
          onPressed: zoomLevel < maxZoom ? onZoomIn : null,
          icon: const Icon(Icons.add),
          iconSize: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          style: dense
              ? IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )
              : null,
          tooltip: context.l10n.diveLog_profile_tooltip_zoomIn,
        ),
      ],
    );
  }
}
