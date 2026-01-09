import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    '/statistics',
    '/buddies',
    '/dive-centers',
    '/certifications',
    '/settings',
  ];

  int _calculateSelectedIndex(
    BuildContext context, {
    required bool isWideScreen,
  }) {
    final location = GoRouterState.of(context).uri.path;

    if (isWideScreen) {
      // Wide screen: Home, then all items in the rail
      if (location.startsWith('/dashboard')) return 0;
      if (location.startsWith('/dives')) return 1;
      if (location.startsWith('/sites')) return 2;
      if (location.startsWith('/trips')) return 3;
      if (location.startsWith('/equipment')) return 4;
      if (location.startsWith('/statistics')) return 5;
      if (location.startsWith('/buddies')) return 6;
      if (location.startsWith('/dive-centers')) return 7;
      if (location.startsWith('/certifications')) return 8;
      if (location.startsWith('/settings')) return 9;
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
          context.go('/statistics');
          break;
        case 6:
          context.go('/buddies');
          break;
        case 7:
          context.go('/dive-centers');
          break;
        case 8:
          context.go('/certifications');
          break;
        case 9:
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
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('More', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.backpack),
              title: const Text('Equipment'),
              onTap: () {
                Navigator.pop(context);
                context.go('/equipment');
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Statistics'),
              onTap: () {
                Navigator.pop(context);
                context.go('/statistics');
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Buddies'),
              onTap: () {
                Navigator.pop(context);
                context.go('/buddies');
              },
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('Dive Centers'),
              onTap: () {
                Navigator.pop(context);
                context.go('/dive-centers');
              },
            ),
            ListTile(
              leading: const Icon(Icons.card_membership),
              title: const Text('Certifications'),
              onTap: () {
                Navigator.pop(context);
                context.go('/certifications');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                context.go('/settings');
              },
            ),
            const SizedBox(height: 8),
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
                      icon: Icon(_isCollapsed
                          ? Icons.keyboard_double_arrow_right
                          : Icons.keyboard_double_arrow_left),
                      tooltip: _isCollapsed ? 'Expand menu' : 'Collapse menu',
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
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.scuba_diving_outlined),
                  selectedIcon: Icon(Icons.scuba_diving),
                  label: Text('Dives'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.location_on_outlined),
                  selectedIcon: Icon(Icons.location_on),
                  label: Text('Sites'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.flight_outlined),
                  selectedIcon: Icon(Icons.flight),
                  label: Text('Trips'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.backpack_outlined),
                  selectedIcon: Icon(Icons.backpack),
                  label: Text('Equipment'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: Text('Statistics'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_outlined),
                  selectedIcon: Icon(Icons.people),
                  label: Text('Buddies'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.store_outlined),
                  selectedIcon: Icon(Icons.store),
                  label: Text('Dive Centers'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.card_membership_outlined),
                  selectedIcon: Icon(Icons.card_membership),
                  label: Text('Certifications'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.scuba_diving_outlined),
            selectedIcon: Icon(Icons.scuba_diving),
            label: 'Dives',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            selectedIcon: Icon(Icons.location_on),
            label: 'Sites',
          ),
          NavigationDestination(
            icon: Icon(Icons.flight_outlined),
            selectedIcon: Icon(Icons.flight),
            label: 'Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_outlined),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
