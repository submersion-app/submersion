import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/auto_update/presentation/widgets/update_banner.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/download_exit_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/global_drop_target.dart';
import 'package:submersion/shared/widgets/nav/nav_primary_provider.dart';

class MainScaffold extends ConsumerStatefulWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  /// When true, the user has manually collapsed the rail (overrides auto-extend)
  bool _isCollapsed = false;

  int _calculateSelectedIndex(
    BuildContext context, {
    required bool isWideScreen,
  }) {
    final location = GoRouterState.of(context).uri.path;

    if (isWideScreen) {
      // Wide-screen rail: ordered by default kNavDestinations.
      if (location.startsWith('/dashboard')) return 0;
      if (location.startsWith('/dives')) return 1;
      if (location.startsWith('/sites')) return 2;
      if (location.startsWith('/trips')) return 3;
      if (location.startsWith('/equipment')) return 4;
      if (location.startsWith('/buddies')) return 5;
      if (location.startsWith('/dive-centers')) return 6;
      if (location.startsWith('/certifications')) return 7;
      if (location.startsWith('/courses')) return 8;
      if (location.startsWith('/statistics')) return 9;
      if (location.startsWith('/planning')) return 10;
      if (location.startsWith('/transfer')) return 11;
      if (location.startsWith('/settings')) return 12;
      return 0;
    }

    // Mobile: iterate the dynamic primary list (length 5: [dashboard, 3 middle, more]).
    final primary = ref.read(navPrimaryDestinationsProvider);
    for (var i = 0; i < primary.length - 1; i++) {
      final route = primary[i].route;
      if (route.isNotEmpty && location.startsWith(route)) return i;
    }
    return primary.length - 1; // fall through to More (index 4)
  }

  Future<void> _onDestinationSelected(
    int index, {
    required bool isWideScreen,
  }) async {
    // Guard: if a download is in progress, confirm before navigating away
    final isDownloading = ref.read(downloadNotifierProvider).isDownloading;
    if (isDownloading) {
      final shouldLeave = await showDownloadExitConfirmation(context);
      if (!shouldLeave || !mounted) return;
      await ref.read(downloadNotifierProvider.notifier).cancelDownload();
      if (!mounted) return;
    }

    if (isWideScreen) {
      switch (index) {
        case 0:
          context.go('/dashboard');
          break;
        case 1:
          context.go('/dives');
          break;
        case 2:
          context.go('/sites');
          break;
        case 3:
          context.go('/trips');
          break;
        case 4:
          context.go('/equipment');
          break;
        case 5:
          context.go('/buddies');
          break;
        case 6:
          context.go('/dive-centers');
          break;
        case 7:
          context.go('/certifications');
          break;
        case 8:
          context.go('/courses');
          break;
        case 9:
          context.go('/statistics');
          break;
        case 10:
          context.go('/planning');
          break;
        case 11:
          context.go('/transfer');
          break;
        case 12:
          context.go('/settings');
          break;
      }
    } else {
      final primary = ref.read(navPrimaryDestinationsProvider);
      if (index == primary.length - 1) {
        _showMoreMenu(context);
        return;
      }
      context.go(primary[index].route);
    }
  }

  void _showMoreMenu(BuildContext context) {
    final overflow = ref.read(navOverflowDestinationsProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    sheetContext.l10n.nav_more,
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: sheetContext.l10n.nav_tooltip_closeMenu,
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final destination in overflow)
                    ListTile(
                      leading: Icon(destination.icon),
                      title: Text(destination.label(sheetContext.l10n)),
                      subtitle: destination.subtitle != null
                          ? Text(destination.subtitle!(sheetContext.l10n))
                          : null,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        context.go(destination.route);
                      },
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth >= 800;
    final isDesktopExtended = screenWidth >= 1200;
    final selectedIndex = _calculateSelectedIndex(
      context,
      isWideScreen: isWideScreen,
    );

    if (isWideScreen) {
      // Desktop/Tablet layout with NavigationRail
      // Only allow collapse toggle when screen is wide enough for extended mode
      final showExtended = isDesktopExtended && !_isCollapsed;

      return Scaffold(
        body: GlobalDropTarget(
          child: SafeArea(
            child: Row(
              children: [
                // Wrap in a scrollable container so the rail doesn't overflow
                // on short screens (e.g. phone landscape with 13 destinations).
                LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: NavigationRail(
                            extended: showExtended,
                            minExtendedWidth: 190,
                            leading: isDesktopExtended
                                ? IconButton(
                                    icon: Icon(
                                      _isCollapsed
                                          ? Icons.keyboard_double_arrow_right
                                          : Icons.keyboard_double_arrow_left,
                                    ),
                                    tooltip: _isCollapsed
                                        ? context.l10n.nav_tooltip_expandMenu
                                        : context.l10n.nav_tooltip_collapseMenu,
                                    onPressed: () {
                                      setState(() {
                                        _isCollapsed = !_isCollapsed;
                                      });
                                    },
                                  )
                                : null,
                            selectedIndex: selectedIndex,
                            onDestinationSelected: (index) =>
                                _onDestinationSelected(
                                  index,
                                  isWideScreen: true,
                                ),
                            destinations: [
                              NavigationRailDestination(
                                icon: const Icon(Icons.home_outlined),
                                selectedIcon: const Icon(Icons.home),
                                label: Text(context.l10n.nav_home),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.scuba_diving_outlined),
                                selectedIcon: const Icon(Icons.scuba_diving),
                                label: Text(context.l10n.nav_dives),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.location_on_outlined),
                                selectedIcon: const Icon(Icons.location_on),
                                label: Text(context.l10n.nav_sites),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.flight_outlined),
                                selectedIcon: const Icon(Icons.flight),
                                label: Text(context.l10n.nav_trips),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.backpack_outlined),
                                selectedIcon: const Icon(Icons.backpack),
                                label: Text(context.l10n.nav_equipment),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.people_outlined),
                                selectedIcon: const Icon(Icons.people),
                                label: Text(context.l10n.nav_buddies),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.store_outlined),
                                selectedIcon: const Icon(Icons.store),
                                label: Text(context.l10n.nav_diveCenters),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(
                                  Icons.card_membership_outlined,
                                ),
                                selectedIcon: const Icon(Icons.card_membership),
                                label: Text(context.l10n.nav_certifications),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.school_outlined),
                                selectedIcon: const Icon(Icons.school),
                                label: Text(context.l10n.nav_courses),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.bar_chart_outlined),
                                selectedIcon: const Icon(Icons.bar_chart),
                                label: Text(context.l10n.nav_statistics),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.edit_calendar_outlined),
                                selectedIcon: const Icon(Icons.edit_calendar),
                                label: Text(context.l10n.nav_planning),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.sync_alt_outlined),
                                selectedIcon: const Icon(Icons.sync_alt),
                                label: Text(context.l10n.nav_transfer),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.settings_outlined),
                                selectedIcon: const Icon(Icons.settings),
                                label: Text(context.l10n.nav_settings),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: Column(
                    children: [
                      const UpdateBanner(),
                      Expanded(child: widget.child),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Mobile layout with BottomNavigationBar
    return Scaffold(
      body: GlobalDropTarget(
        child: Column(
          children: [
            const UpdateBanner(),
            Expanded(child: widget.child),
          ],
        ),
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final primary = ref.watch(navPrimaryDestinationsProvider);
          return NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) =>
                _onDestinationSelected(index, isWideScreen: false),
            destinations: [
              for (final destination in primary)
                NavigationDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: destination.label(context.l10n),
                ),
            ],
          );
        },
      ),
    );
  }
}
