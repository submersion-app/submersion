import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/nav/favorites/nav_favorites_section.dart';
import 'package:submersion/shared/widgets/nav/favorites/nav_rail_tile.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';

/// Everything the wide-screen rail shows above its destination list: the
/// optional collapse toggle, the Home tile, and the Favorites block.
///
/// Home lives here rather than in [NavigationRail.destinations] because the
/// rail cannot interleave arbitrary widgets between destinations, and the
/// Favorites block has to sit directly under Home.
///
/// The block animates its width with the same duration and curve the rail
/// uses for its extend transition, and clips its fixed-width children while
/// the two are mid-flight, so the leading column never reports overflow.
class NavRailLeading extends StatelessWidget {
  const NavRailLeading({
    super.key,
    required this.extended,
    required this.home,
    required this.currentLocation,
    required this.onNavigate,
    required this.accentOf,
    this.railHasDestinations = true,
    this.collapseToggle,
  });

  final bool extended;
  final NavDestination home;
  final String currentLocation;
  final ValueChanged<NavDestination> onNavigate;
  final Color? Function(String id) accentOf;

  /// False once every destination has been starred, so the Favorites block
  /// drops the divider that would otherwise separate it from an empty rail.
  final bool railHasDestinations;

  /// The expand/collapse button, when the viewport is wide enough to offer
  /// one. Rendered above Home so it keeps its current position.
  final Widget? collapseToggle;

  @override
  Widget build(BuildContext context) {
    final width = extended ? kNavRailExtendedWidth : kNavRailCollapsedWidth;
    return AnimatedContainer(
      duration: kThemeAnimationDuration,
      curve: Curves.easeInOut,
      width: width,
      child: ClipRect(
        child: OverflowBox(
          fit: OverflowBoxFit.deferToChild,
          alignment: AlignmentDirectional.centerStart,
          minWidth: width,
          maxWidth: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?collapseToggle,
              NavRailTile(
                key: const ValueKey('navRailHome'),
                extended: extended,
                selected: currentLocation.startsWith(home.route),
                icon: home.icon,
                selectedIcon: home.selectedIcon,
                label: home.label(context.l10n),
                accent: accentOf(home.id),
                onTap: () => onNavigate(home),
              ),
              NavFavoritesSection(
                extended: extended,
                currentLocation: currentLocation,
                onSelect: onNavigate,
                accentOf: accentOf,
                showEndDivider: railHasDestinations,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
