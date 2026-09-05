import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/back_navigation.dart';
import 'package:submersion/core/theme/feature_accent_colors.dart';
import 'package:submersion/features/auto_update/presentation/widgets/update_banner.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/download_exit_dialog.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_recording_strip.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/global_drop_target.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';
import 'package:submersion/shared/widgets/nav/nav_order_provider.dart';

/// Fraction of the screen height the phone overflow ("More") sheet may fill.
///
/// The remainder is scrim the user can tap to dismiss the sheet.
const double _moreSheetMaxHeight = 0.85;

class MainScaffold extends ConsumerStatefulWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  /// When true, the user has manually collapsed the rail (overrides auto-extend)
  bool _isCollapsed = false;

  /// Builds a per-destination accent color lookup for the navigation surfaces.
  ///
  /// Returns null for every id while the toggle is off, and for ids with no
  /// palette entry -- which is how the `more` sentinel stays uncolored. A null
  /// result leaves the icon on its Material 3 default.
  ///
  /// Pass `watch: false` from transient surfaces (the overflow sheet) that are
  /// built outside the scaffold's own build phase.
  Color? Function(String) _navAccentLookup(
    BuildContext context, {
    bool watch = true,
  }) {
    final enabled = watch
        ? ref.watch(accentNavIconsProvider)
        : ref.read(accentNavIconsProvider);
    if (!enabled) return (_) => null;
    final accents = Theme.of(context).extension<FeatureAccentColors>();
    return (id) => accents?.of(id);
  }

  /// [railDestinations] is only read when [isWideScreen] is true, so phone
  /// builds may pass an empty list rather than subscribing to the rail order.
  int _calculateSelectedIndex(
    BuildContext context, {
    required bool isWideScreen,
    required List<NavDestination> railDestinations,
  }) {
    final location = GoRouterState.of(context).uri.path;

    if (isWideScreen) {
      // Wide-screen rail: pinned Home, then the user's saved rail order.
      for (var i = 0; i < railDestinations.length; i++) {
        if (location.startsWith(railDestinations[i].route)) return i;
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
      final rail = ref.read(navRailDestinationsProvider);
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
    final navAccent = _navAccentLookup(context, watch: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // Scroll-controlled means the sheet has no height ceiling, and a dozen
      // overflow destinations are taller than a phone screen. Left alone the
      // sheet grew to y=0, putting its title and close button under the
      // Android status bar (issue #1480). The safe area keeps it clear of the
      // status bar and cutouts; the height cap leaves a strip of scrim above
      // it so tapping outside stays an obvious way out.
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * _moreSheetMaxHeight,
      ),
      // Not redundant with useSafeArea: that inserts SafeArea(bottom: false),
      // so the sheet deliberately runs to the bottom edge of the screen. This
      // one supplies the bottom inset the outer one skips, keeping the last
      // tile clear of the home indicator. Nothing is applied twice -- a
      // SafeArea strips the padding it consumes out of the MediaQuery, so the
      // horizontal insets are already zero by the time this one reads them.
      builder: (sheetContext) => SafeArea(
        child: Column(
          key: const ValueKey('navOverflowSheetBody'),
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
                      leading: Icon(
                        destination.icon,
                        color: navAccent(destination.id),
                      ),
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
    // Last-resort handler for the Android system back button.
    //
    // go_router's popRoute() tries navigators innermost-first: its
    // _findCurrentNavigators() collects [root, ...shells] and returns them
    // reversed. So the shell's inner Navigator -- and any PopScope on the
    // page it currently shows, such as EditFormScaffold's unsaved-changes
    // guard -- gets to pop or decline before this ever runs.
    //
    // This PopScope is registered on the ROOT navigator's shell page, which
    // makes it the LAST candidate. It therefore only fires when nothing can
    // pop, the normal state after any context.go() because go() replaces the
    // stack instead of pushing onto it. Without this fallback the press falls
    // through to SystemNavigator.pop() and closes the app (#647).
    final upLocation = resolveUpLocation(GoRouterState.of(context).uri);
    return PopScope(
      // Only the dashboard resolves to null, so only the dashboard exits.
      canPop: upLocation == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || upLocation == null) return;
        context.go(upLocation);
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth >= 800;
    final isDesktopExtended = screenWidth >= 1200;
    final navAccent = _navAccentLookup(context);
    // Watched only on wide screens: building this provider kicks off a
    // settings read for the rail order, and a phone never renders a rail.
    // Riverpod rebuilds subscriptions each build, so a resize into rail
    // width picks it up on that build.
    final railDestinations = isWideScreen
        ? ref.watch(navRailDestinationsProvider)
        : const <NavDestination>[];
    final selectedIndex = _calculateSelectedIndex(
      context,
      isWideScreen: isWideScreen,
      railDestinations: railDestinations,
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
                              for (final destination in railDestinations)
                                NavigationRailDestination(
                                  icon: Icon(
                                    destination.icon,
                                    color: navAccent(destination.id),
                                  ),
                                  selectedIcon: Icon(
                                    destination.selectedIcon,
                                    color: navAccent(destination.id),
                                  ),
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
    final navAccent = _navAccentLookup(context);
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) =>
          _onDestinationSelected(index, isWideScreen: false),
      destinations: [
        for (final destination in primary)
          NavigationDestination(
            icon: Icon(destination.icon, color: navAccent(destination.id)),
            selectedIcon: Icon(
              destination.selectedIcon,
              color: navAccent(destination.id),
            ),
            label: destination.label(context.l10n),
          ),
      ],
    );
  }
}
