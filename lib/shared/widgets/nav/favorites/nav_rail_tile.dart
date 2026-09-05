import 'package:flutter/material.dart';

/// Width of the icon-only rail: the Material 3 [NavigationRail] `minWidth`.
const double kNavRailCollapsedWidth = 80;

/// Width of the extended rail. Passed as [NavigationRail.minExtendedWidth]
/// and used to size the tiles above the rail destinations so both columns
/// line up. Rail labels are clamped to this width too (see NavRailLabel), so
/// the rail never grows past it and the two never drift apart.
const double kNavRailExtendedWidth = 220;

/// Height of one M3 rail destination with `labelType: none`: a 32px
/// indicator plus the 12px destination spacing split above and below it.
const double kNavRailTileHeight = 44;

/// Trailing inset the rail applies after an extended label.
const double kNavRailEndPadding = 8;

const double _indicatorWidth = 56;
const double _indicatorHeight = 32;

/// A tile styled like a Material 3 [NavigationRail] destination, for rows
/// the rail cannot host itself: the Home entry above the Favorites block
/// and the reorderable favorites underneath it.
///
/// [extended] switches between the icon-only column layout and the
/// icon-plus-label row layout, matching what the rail does for its own
/// destinations. [accent] tints the icon in both states, mirroring the
/// per-feature accent applied to the rail's icons.
class NavRailTile extends StatelessWidget {
  const NavRailTile({
    super.key,
    required this.extended,
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.accent,
    this.onTap,
    this.onSecondaryTap,
    this.trailing,
  });

  final bool extended;
  final bool selected;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Color? accent;
  final VoidCallback? onTap;

  /// Optional right-click handler (used to un-star icon-only favorites).
  final VoidCallback? onSecondaryTap;

  /// Optional widget after the label in extended mode (e.g. a drag handle).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final railTheme = NavigationRailTheme.of(context);
    final iconColor =
        accent ??
        (selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant);
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
    );

    final iconPart = SizedBox(
      width: kNavRailCollapsedWidth,
      height: kNavRailTileHeight,
      child: Center(
        child: Container(
          width: _indicatorWidth,
          height: _indicatorHeight,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            shape: railTheme.indicatorShape ?? const StadiumBorder(),
            color: selected
                ? (railTheme.indicatorColor ?? scheme.secondaryContainer)
                : Colors.transparent,
          ),
          child: Icon(selected ? selectedIcon : icon, color: iconColor),
        ),
      ),
    );

    final Widget content = extended
        ? SizedBox(
            width: kNavRailExtendedWidth,
            height: kNavRailTileHeight,
            child: Row(
              children: [
                iconPart,
                Expanded(
                  child: Text(
                    label,
                    style: labelStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ?trailing,
                const SizedBox(width: kNavRailEndPadding),
              ],
            ),
          )
        : Tooltip(message: label, child: iconPart);

    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: onTap,
        onSecondaryTap: onSecondaryTap,
        child: content,
      ),
    );
  }
}
