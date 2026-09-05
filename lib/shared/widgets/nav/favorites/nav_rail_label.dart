import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/nav/favorites/nav_rail_tile.dart';
import 'package:submersion/shared/widgets/nav/favorites/nav_star_button.dart';

/// Label widget for a wide-screen rail destination: the localized [text]
/// followed by an outline star that moves the destination into Favorites.
///
/// Only unstarred destinations live in the rail (starring moves a destination
/// out of the rail and under the Favorites header), so the star here is
/// always the "add" affordance. It stays dim until the row is hovered so the
/// rail stays quiet.
///
/// The label is clamped to the space the extended rail leaves after its
/// 80px icon column and 8px end padding, so the rail's width is exactly
/// [kNavRailExtendedWidth] and every star lines up in one column.
///
/// Exposes [text] so tests (and the rail order contract) can read the plain
/// label back without digging through the row.
class NavRailLabel extends StatefulWidget {
  const NavRailLabel({
    super.key,
    required this.text,
    required this.onAddToFavorites,
  });

  final String text;
  final VoidCallback onAddToFavorites;

  @override
  State<NavRailLabel> createState() => _NavRailLabelState();
}

class _NavRailLabelState extends State<NavRailLabel> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: SizedBox(
        width:
            kNavRailExtendedWidth - kNavRailCollapsedWidth - kNavRailEndPadding,
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            NavStarButton(
              isFavorite: false,
              dim: !_hovered,
              onPressed: widget.onAddToFavorites,
            ),
          ],
        ),
      ),
    );
  }
}
