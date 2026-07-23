import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/auto_update/presentation/widgets/update_banner.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/download_exit_dialog.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_recording_strip.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/global_drop_target.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';
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

  /// Wide-screen rail destinations: every routable destination in canonical
  /// order. The `more` sentinel is a phone-only overflow control.
  List<NavDestination> get _railDestinations =>
      kNavDestinations.where((d) => d.id != 'more').toList(growable: false);

  int _calculateSelectedIndex(
    BuildContext context, {
    required bool isWideScreen,
  }) {
    final location = GoRouterState.of(context).uri.path;

    if (isWideScreen) {
      // Wide-screen rail: ordered by kNavDestinations.
      final rail = _railDestinations;
      for (var i = 0; i < rail.length; i++) {
        if (location.startsWith(rail[i].route)) return i;
      }
      return 0;
    }

    // Mobile: iterate the dynamic primary list (length 5: [dashboard, 3 middle, more]).
    final primary = ref.watch(navPrimaryDestinationsProvider);
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
      final rail = _railDestinations;
      if (index >= 0 && index < rail.length) {
        context.go(rail[index].route);
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
                              for (final destination in _railDestinations)
                                NavigationRailDestination(
                                  icon: Icon(destination.icon),
                                  selectedIcon: Icon(destination.selectedIcon),
                                  label: Text(destination.label(context.l10n)),
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
                      const GpsRecordingStrip(),
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
            const GpsRecordingStrip(),
          ],
        ),
      ),
      bottomNavigationBar: _buildMobileNavBar(context, selectedIndex),
    );
  }

  Widget _buildMobileNavBar(BuildContext context, int selectedIndex) {
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
  }
}
