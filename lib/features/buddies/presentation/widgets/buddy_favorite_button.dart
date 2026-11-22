import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The favourite star shown on every buddy surface: the list tiles, the
/// detail page and the "Add buddy" picker sheet (issues #1336, #638). It
/// shows whether the buddy is a favourite and writes nothing on a tap:
/// buddies edit in place (issue #4527, phase 3), so the favourite is set on
/// the buddy's page, in its sitting.
///
/// [unselectedColor] lets a list row match its own secondary-text tint;
/// left null, the star inherits the surrounding IconTheme (the app bar's
/// icon color, for instance). The favorite color is always the theme's
/// primary color, unlike the unselected one.
class BuddyFavoriteButton extends StatelessWidget {
  final bool isFavorite;
  final double iconSize;
  final Color? unselectedColor;

  const BuddyFavoriteButton({
    super.key,
    required this.isFavorite,
    this.iconSize = 24,
    this.unselectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isFavorite ? context.l10n.query_buddies_favorite : null,
      child: SizedBox.square(
        dimension: 32,
        child: Center(
          child: Icon(
            isFavorite ? Icons.star : Icons.star_border,
            size: iconSize,
            color: isFavorite
                ? Theme.of(context).colorScheme.primary
                : unselectedColor,
          ),
        ),
      ),
    );
  }
}
