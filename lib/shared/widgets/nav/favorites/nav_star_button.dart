import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Star glyph size inside rail rows.
const double _starSize = 18;

/// Hit box of the star toggle; comfortably larger than the glyph but short
/// enough not to stretch a 44px rail row.
const double kNavStarBoxSize = 28;

/// The star that toggles a destination's Favorites membership.
///
/// Renders a filled, primary-tinted star when [isFavorite] (tapping it
/// removes the destination from Favorites) and an outline star otherwise
/// (tapping adds it). [dim] fades the outline star so unstarred rail rows
/// stay quiet until hovered; it has no effect on the filled star.
class NavStarButton extends StatelessWidget {
  const NavStarButton({
    super.key,
    required this.isFavorite,
    required this.onPressed,
    this.dim = false,
  });

  final bool isFavorite;
  final VoidCallback onPressed;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final color = isFavorite
        ? scheme.primary
        : scheme.onSurfaceVariant.withValues(alpha: dim ? 0.45 : 1);

    return IconButton(
      iconSize: _starSize,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: kNavStarBoxSize,
        height: kNavStarBoxSize,
      ),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      tooltip: isFavorite
          ? l10n.nav_tooltip_removeFromFavorites
          : l10n.nav_tooltip_addToFavorites,
      color: color,
      icon: Icon(isFavorite ? Icons.star : Icons.star_border),
      onPressed: onPressed,
    );
  }
}
