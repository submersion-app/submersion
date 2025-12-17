import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({
    super.key,
    required this.child,
  });

  // Routes that appear in the "More" menu on mobile
  static const _moreRoutes = [
    '/statistics',
    '/buddies',
    '/dive-centers',
    '/certifications',
    '/tools/weight-calculator',
    '/settings',
  ];

  int _calculateSelectedIndex(BuildContext context, {required bool isWideScreen}) {
    final location = GoRouterState.of(context).uri.path;
    
    if (isWideScreen) {
      // Wide screen has all items in the rail
      if (location.startsWith('/dives')) return 0;
      if (location.startsWith('/trips')) return 1;
      if (location.startsWith('/sites')) return 2;
      if (location.startsWith('/equipment')) return 3;
      if (location.startsWith('/statistics')) return 4;
      if (location.startsWith('/buddies')) return 5;
      if (location.startsWith('/dive-centers')) return 6;
      if (location.startsWith('/certifications')) return 7;
      if (location.startsWith('/tools')) return 8;
      if (location.startsWith('/settings')) return 9;
      return 0;
    } else {
      // Mobile: Dives, Trips, Sites, Equipment, More
      if (location.startsWith('/dives')) return 0;
      if (location.startsWith('/trips')) return 1;
      if (location.startsWith('/sites')) return 2;
      if (location.startsWith('/equipment')) return 3;
      // Check if current route is in "More" menu
      for (final route in _moreRoutes) {
        if (location.startsWith(route)) return 4;
      }
      return 0;
    }
  }

  void _onDestinationSelected(BuildContext context, int index, {required bool isWideScreen}) {
    if (isWideScreen) {
      switch (index) {
        case 0:
          context.go('/dives');
          break;
        case 1:
          context.go('/trips');
          break;
        case 2:
          context.go('/sites');
          break;
        case 3:
          context.go('/equipment');
          break;
        case 4:
          context.go('/statistics');
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
          context.go('/tools/weight-calculator');
          break;
        case 9:
          context.go('/settings');
          break;
      }
    } else {
      // Mobile navigation
      switch (index) {
        case 0:
          context.go('/dives');
          break;
        case 1:
          context.go('/trips');
          break;
        case 2:
          context.go('/sites');
          break;
        case 3:
          context.go('/equipment');
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
                  Text(
                    'More',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
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
              leading: const Icon(Icons.fitness_center),
              title: const Text('Weight Calculator'),
              onTap: () {
                Navigator.pop(context);
                context.go('/tools/weight-calculator');
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
    final isWideScreen = MediaQuery.of(context).size.width >= 800;
    final selectedIndex = _calculateSelectedIndex(context, isWideScreen: isWideScreen);

    if (isWideScreen) {
      // Desktop/Tablet layout with NavigationRail
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: MediaQuery.of(context).size.width >= 1200,
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) =>
                  _onDestinationSelected(context, index, isWideScreen: true),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Icon(
                  Icons.scuba_diving,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.waves_outlined),
                  selectedIcon: Icon(Icons.waves),
                  label: Text('Dives'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.card_travel_outlined),
                  selectedIcon: Icon(Icons.card_travel),
                  label: Text('Trips'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.location_on_outlined),
                  selectedIcon: Icon(Icons.location_on),
                  label: Text('Sites'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
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
                  icon: Icon(Icons.fitness_center_outlined),
                  selectedIcon: Icon(Icons.fitness_center),
                  label: Text('Weight Calc'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    // Mobile layout with BottomNavigationBar
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) =>
            _onDestinationSelected(context, index, isWideScreen: false),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.waves_outlined),
            selectedIcon: Icon(Icons.waves),
            label: 'Dives',
          ),
          NavigationDestination(
            icon: Icon(Icons.card_travel_outlined),
            selectedIcon: Icon(Icons.card_travel),
            label: 'Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            selectedIcon: Icon(Icons.location_on),
            label: 'Sites',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Equipment',
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
