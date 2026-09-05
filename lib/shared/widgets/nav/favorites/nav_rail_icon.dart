import 'package:flutter/material.dart';

/// Icon of a wide-screen rail destination, with the touch and mouse
/// affordances for starring it.
///
/// The extended rail exposes a star in the label, but the icon-only rail
/// (800 to 1200px, or collapsed by the user) has no labels at all, so the
/// icon itself accepts a long-press (touch) or right-click (mouse) to move
/// the destination into Favorites. A plain tap still reaches the rail's own
/// selection handling.
///
/// [icon] and [color] are exposed so the accent tinting contract can be
/// read back from [NavigationRailDestination.icon] in tests.
class NavRailIcon extends StatelessWidget {
  const NavRailIcon({
    super.key,
    required this.icon,
    required this.onAddToFavorites,
    this.color,
  });

  final IconData icon;
  final Color? color;
  final VoidCallback onAddToFavorites;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onAddToFavorites,
      onSecondaryTap: onAddToFavorites,
      child: Icon(icon, color: color),
    );
  }
}
