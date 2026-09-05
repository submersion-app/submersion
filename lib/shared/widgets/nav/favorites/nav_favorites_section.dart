import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/nav/favorites/nav_favorites_provider.dart';
import 'package:submersion/shared/widgets/nav/favorites/nav_rail_tile.dart';
import 'package:submersion/shared/widgets/nav/favorites/nav_star_button.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';

/// The Favorites block of the wide-screen rail, rendered under Home.
///
/// Lists the starred destinations in the user's order as [NavRailTile]s.
/// Starring moves a destination here (it leaves the rail proper), and the
/// filled star on each tile moves it back. Reordering is drag and drop: a
/// trailing handle on desktop when the rail is extended, long-press anywhere
/// on the tile otherwise. When nothing is starred the extended rail shows a
/// muted hint; the collapsed rail shows nothing at all rather than an empty
/// divider pair.
class NavFavoritesSection extends ConsumerWidget {
  const NavFavoritesSection({
    super.key,
    required this.extended,
    required this.currentLocation,
    required this.onSelect,
    required this.accentOf,
    this.showEndDivider = true,
  });

  final bool extended;

  /// Current router path, used to highlight the favorite being viewed.
  final String currentLocation;

  final ValueChanged<NavDestination> onSelect;

  /// Per-destination accent color lookup shared with the rail.
  final Color? Function(String id) accentOf;

  /// Whether to draw the divider separating Favorites from the rail's own
  /// destinations. Callers pass false once every destination has been
  /// starred, so the block does not end in a rule with nothing under it.
  final bool showEndDivider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(navFavoriteDestinationsProvider);
    if (!extended && favorites.isEmpty) return const SizedBox.shrink();

    final width = extended ? kNavRailExtendedWidth : kNavRailCollapsedWidth;
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (extended) _Header() else const _RailDivider(),
          if (favorites.isEmpty)
            const _EmptyHint()
          else
            _FavoritesList(
              favorites: favorites,
              extended: extended,
              currentLocation: currentLocation,
              onSelect: onSelect,
              accentOf: accentOf,
            ),
          if (showEndDivider)
            const _RailDivider(key: ValueKey('navFavoritesEndDivider')),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, top: 8, bottom: 4),
      child: Text(
        context.l10n.nav_favorites,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: const ValueKey('navFavoritesEmptyHint'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        context.l10n.nav_favorites_emptyHint,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _RailDivider extends StatelessWidget {
  const _RailDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 9, thickness: 1, indent: 16, endIndent: 16);
  }
}

class _FavoritesList extends ConsumerWidget {
  const _FavoritesList({
    required this.favorites,
    required this.extended,
    required this.currentLocation,
    required this.onSelect,
    required this.accentOf,
  });

  final List<NavDestination> favorites;
  final bool extended;
  final String currentLocation;
  final ValueChanged<NavDestination> onSelect;
  final Color? Function(String id) accentOf;

  bool _usesDragHandle(BuildContext context) {
    if (!extended) return false;
    return switch (Theme.of(context).platform) {
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useHandle = _usesDragHandle(context);
    final notifier = ref.read(navFavoritesNotifierProvider.notifier);
    // A fixed height keeps the list's viewport out of the rail's intrinsic
    // height pass (viewports cannot report intrinsics) and lets the list
    // shrink-wrap without scrolling.
    return SizedBox(
      key: const ValueKey('navFavoritesList'),
      height: favorites.length * kNavRailTileHeight,
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemExtent: kNavRailTileHeight,
        buildDefaultDragHandles: false,
        itemCount: favorites.length,
        onReorderItem: notifier.reorder,
        itemBuilder: (context, index) {
          final destination = favorites[index];
          final tile = NavRailTile(
            extended: extended,
            selected: currentLocation.startsWith(destination.route),
            icon: destination.icon,
            selectedIcon: destination.selectedIcon,
            label: destination.label(context.l10n),
            accent: accentOf(destination.id),
            onTap: () => onSelect(destination),
            // The icon-only tile has no room for a star, so right-click
            // un-stars it there (long-press is taken by drag-to-reorder).
            onSecondaryTap: extended
                ? null
                : () => notifier.remove(destination.id),
            trailing: extended
                ? _ExtendedTrailing(
                    onRemove: () => notifier.remove(destination.id),
                    dragHandle: useHandle ? _DragHandle(index: index) : null,
                  )
                : null,
          );
          return KeyedSubtree(
            key: ValueKey('navFavorite:${destination.id}'),
            child: useHandle
                ? tile
                : ReorderableDelayedDragStartListener(
                    index: index,
                    child: tile,
                  ),
          );
        },
      ),
    );
  }
}

/// Filled star (un-favorite) followed by the optional desktop drag handle.
class _ExtendedTrailing extends StatelessWidget {
  const _ExtendedTrailing({required this.onRemove, this.dragHandle});

  final VoidCallback onRemove;
  final Widget? dragHandle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NavStarButton(isFavorite: true, onPressed: onRemove),
        ?dragHandle,
      ],
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return ReorderableDragStartListener(
      index: index,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Tooltip(
          message: context.l10n.nav_tooltip_dragToReorder,
          child: Icon(
            Icons.drag_handle,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
