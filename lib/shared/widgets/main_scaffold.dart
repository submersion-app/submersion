import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/l10n/l10n_extension.dart';

class MainScaffold extends StatefulWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  /// When true, the user has manually collapsed the rail (overrides auto-extend)
  bool _isCollapsed = false;

  // Routes that appear in the "More" menu on mobile
  static const _moreRoutes = [
    '/equipment',
    '/buddies',
    '/dive-centers',
    '/certifications',
    '/courses',
    '/statistics',
    '/planning',
    '/transfer',
    '/settings',
  ];

  int _calculateSelectedIndex(
    BuildContext context, {
    required bool isWideScreen,
  }) {
    final location = GoRouterState.of(context).uri.path;

    if (isWideScreen) {
      // Wide screen: All items in the rail
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
    } else {
      // Mobile: Dashboard, Dives, Sites, Trips, More
      if (location.startsWith('/dashboard')) return 0;
      if (location.startsWith('/dives')) return 1;
      if (location.startsWith('/sites')) return 2;
      if (location.startsWith('/trips')) return 3;
      // Check if current route is in "More" menu
      for (final route in _moreRoutes) {
        if (location.startsWith(route)) return 4;
      }
      return 0;
    }
  }

  void _onDestinationSelected(
    BuildContext context,
    int index, {
    required bool isWideScreen,
  }) {
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
      // Mobile navigation: Dashboard, Dives, Sites, Trips, More
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
          _showMoreMenu(context);
          break;
      }
    }
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fixed header
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
            // Scrollable menu items
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: const Icon(Icons.backpack),
                    title: Text(sheetContext.l10n.nav_equipment),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.go('/equipment');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.people),
                    title: Text(sheetContext.l10n.nav_buddies),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.go('/buddies');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.store),
                    title: Text(sheetContext.l10n.nav_diveCenters),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.go('/dive-centers');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.card_membership),
                    title: Text(sheetContext.l10n.nav_certifications),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.go('/certifications');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.school),
                    title: Text(sheetContext.l10n.nav_courses),
                    subtitle: Text(sheetContext.l10n.nav_coursesSubtitle),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.go('/courses');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.bar_chart),
                    title: Text(sheetContext.l10n.nav_statistics),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.go('/statistics');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit_calendar),
                    title: Text(sheetContext.l10n.nav_planning),
                    subtitle: Text(sheetContext.l10n.nav_planningSubtitle),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.go('/planning');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.sync_alt),
                    title: Text(sheetContext.l10n.nav_transfer),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.go('/transfer');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: Text(sheetContext.l10n.nav_settings),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.go('/settings');
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
        body: Row(
          children: [
            NavigationRail(
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
                  _onDestinationSelected(context, index, isWideScreen: true),
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
                  icon: const Icon(Icons.card_membership_outlined),
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
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    // Mobile layout with BottomNavigationBar
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) =>
            _onDestinationSelected(context, index, isWideScreen: false),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: context.l10n.nav_home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.scuba_diving_outlined),
            selectedIcon: const Icon(Icons.scuba_diving),
            label: context.l10n.nav_dives,
          ),
          NavigationDestination(
            icon: const Icon(Icons.location_on_outlined),
            selectedIcon: const Icon(Icons.location_on),
            label: context.l10n.nav_sites,
          ),
          NavigationDestination(
            icon: const Icon(Icons.flight_outlined),
            selectedIcon: const Icon(Icons.flight),
            label: context.l10n.nav_trips,
          ),
          NavigationDestination(
            icon: const Icon(Icons.more_horiz_outlined),
            selectedIcon: const Icon(Icons.more_horiz),
            label: context.l10n.nav_more,
          ),
        ],
      ),
    );
  }
}
