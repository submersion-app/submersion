import 'dart:math' as math;

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
import 'package:submersion/shared/widgets/nav/nav_slot_count.dart';

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
  /// Manual override for the rail's expanded/collapsed state, set by tapping
  /// the collapse arrow. `null` means "no manual override yet, follow
  /// [navAlwaysHideLabelsProvider]'s default"; a non-null value means the
  /// user overrode it for this session (#1424), same as before this setting
  /// existed -- it is not persisted, so it resets on restart.
  bool? _isCollapsedOverride;

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

  /// [railDestinations] is only read when [isWideScreen] is true and
  /// [primaryDestinations] only when it is false, so the caller may pass an
  /// empty list for the surface it is not rendering rather than subscribing
  /// to that surface's order.
  int _calculateSelectedIndex(
    BuildContext context, {
    required bool isWideScreen,
    required List<NavDestination> railDestinations,
    required List<NavDestination> primaryDestinations,
  }) {
    final location = GoRouterState.of(context).uri.path;

    if (isWideScreen) {
      // Wide-screen rail: pinned Home, then the user's saved rail order.
      for (var i = 0; i < railDestinations.length; i++) {
        if (location.startsWith(railDestinations[i].route)) return i;
      }
      return 0;
    }

    // Mobile: [dashboard, ...middle slots, more]; the slot count is dynamic
    // (#1424), so the More sentinel is always the last entry, not a fixed
    // index.
    for (var i = 0; i < primaryDestinations.length - 1; i++) {
      final route = primaryDestinations[i].route;
      if (route.isNotEmpty && location.startsWith(route)) return i;
    }
    return primaryDestinations.length - 1; // fall through to More
  }

  /// Handles a tap on the rail or the bottom bar.
  ///
  /// [destinations] is the list that rendered the tapped control, captured in
  /// the same build. Re-reading the provider here instead would let the order
  /// change between render and tap and resolve [index] against a different
  /// list, routing somewhere the user did not tap. The window is real: the
  /// download confirmation below suspends this method for as long as the user
  /// takes to answer, and a sync applying a remote settings change or a
  /// cold-start load landing in that gap would swap the list out.
  Future<void> _onDestinationSelected(
    int index, {
    required List<NavDestination> destinations,
    List<NavDestination> overflow = const [],
  }) async {
    if (index < 0 || index >= destinations.length) return;
    final destination = destinations[index];

    // Guard: if a download is in progress, confirm before navigating away
    final isDownloading = ref.read(downloadNotifierProvider).isDownloading;
    if (isDownloading) {
      final shouldLeave = await showDownloadExitConfirmation(context);
      if (!shouldLeave || !mounted) return;
      await ref.read(downloadNotifierProvider.notifier).cancelDownload();
      if (!mounted) return;
    }

    // The bottom bar's last entry is the `more` sentinel, which opens the
    // overflow sheet rather than routing. The rail never contains it.
    if (destination.id == 'more') {
      _showMoreMenu(context, overflow);
      return;
    }
    if (destination.route.isEmpty) return;
    context.go(destination.route);
  }

  /// [overflow] is captured by the caller in the same build that rendered the
  /// tapped bottom bar, matching [destinations] in [_onDestinationSelected]:
  /// reading the provider fresh here could resolve against a slot count that
  /// changed (e.g. a rotation) while the sheet was opening.
  void _showMoreMenu(BuildContext context, List<NavDestination> overflow) {
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
    final viewSize = MediaQuery.sizeOf(context);
    final screenWidth = viewSize.width;
    final isWideScreen = screenWidth >= 800;
    final isDesktopExtended = screenWidth >= 1200;
    final navAccent = _navAccentLookup(context);
    final alwaysHideLabels =
        ref.watch(navAlwaysHideLabelsProvider).value ?? false;
    // Watched only on wide screens: building this provider kicks off a
    // settings read for the rail order, and a phone never renders a rail.
    // Riverpod rebuilds subscriptions each build, so a resize into rail
    // width picks it up on that build.
    final railDestinations = isWideScreen
        ? ref.watch(navRailDestinationsProvider)
        : const <NavDestination>[];
    // Only computed on narrow screens, mirroring railDestinations above: a
    // rail never renders the primary/overflow split, so a wide build has no
    // reason to subscribe to the phone order or the slot-count inputs.
    final primarySlotCount = isWideScreen
        ? kMinPhonePrimarySlotCount
        : currentPhonePrimarySlotCount(ref, viewSize);
    final primaryDestinations = isWideScreen
        ? const <NavDestination>[]
        : ref.watch(navPrimaryDestinationsProvider(primarySlotCount));
    final overflowDestinations = isWideScreen
        ? const <NavDestination>[]
        : ref.watch(navOverflowDestinationsProvider(primarySlotCount));
    final selectedIndex = _calculateSelectedIndex(
      context,
      isWideScreen: isWideScreen,
      railDestinations: railDestinations,
      primaryDestinations: primaryDestinations,
    );

    if (isWideScreen) {
      // Desktop/Tablet layout with NavigationRail
      // Only allow collapse toggle when screen is wide enough for extended mode.
      // With no manual override yet, the always-hide-labels setting decides
      // whether the rail starts extended (#1424); the arrow below can always
      // override that for the rest of this session.
      final isCollapsed = _isCollapsedOverride ?? alwaysHideLabels;
      final showExtended = isDesktopExtended && !isCollapsed;

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
                                      isCollapsed
                                          ? Icons.keyboard_double_arrow_right
                                          : Icons.keyboard_double_arrow_left,
                                    ),
                                    tooltip: isCollapsed
                                        ? context.l10n.nav_tooltip_expandMenu
                                        : context.l10n.nav_tooltip_collapseMenu,
                                    onPressed: () {
                                      setState(() {
                                        _isCollapsedOverride = !isCollapsed;
                                      });
                                    },
                                  )
                                : null,
                            selectedIndex: selectedIndex,
                            onDestinationSelected: (index) =>
                                _onDestinationSelected(
                                  index,
                                  destinations: railDestinations,
                                ),
                            destinations: [
                              for (final destination in railDestinations)
                                NavigationRailDestination(
                                  icon: _railIcon(
                                    Icon(
                                      destination.icon,
                                      color: navAccent(destination.id),
                                    ),
                                    label: destination.label(context.l10n),
                                    labelsHidden: !showExtended,
                                  ),
                                  selectedIcon: _railIcon(
                                    Icon(
                                      destination.selectedIcon,
                                      color: navAccent(destination.id),
                                    ),
                                    label: destination.label(context.l10n),
                                    labelsHidden: !showExtended,
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
      bottomNavigationBar: _buildMobileNavBar(
        context,
        selectedIndex,
        primary: primaryDestinations,
        overflow: overflowDestinations,
        alwaysHideLabels: alwaysHideLabels,
      ),
    );
  }

  /// Names a rail icon on hover or long-press while the rail hides its labels.
  ///
  /// NavigationRailDestination has no tooltip of its own (NavigationBar
  /// does), so a collapsed rail would otherwise leave its icons unnamed. The
  /// tooltip skips semantics because the rail already announces the label.
  Widget _railIcon(
    Icon icon, {
    required String label,
    required bool labelsHidden,
  }) {
    if (!labelsHidden) return icon;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      positionDelegate: (position) => _besideRail(position, towardsLeft: isRtl),
      child: icon,
    );
  }

  /// Places a rail tooltip beside the rail, vertically centred on its icon,
  /// so it never covers the neighbouring destinations above or below.
  static Offset _besideRail(
    TooltipPositionContext position, {
    required bool towardsLeft,
  }) {
    // Clears the rail's selection indicator, which is wider than the icon.
    const gap = 36.0;
    final tooltip = position.tooltipSize;
    final x = towardsLeft
        ? position.target.dx - gap - tooltip.width
        : position.target.dx + gap;
    final y = position.target.dy - tooltip.height / 2;
    return Offset(
      x.clamp(0.0, math.max(0.0, position.overlaySize.width - tooltip.width)),
      y.clamp(0.0, math.max(0.0, position.overlaySize.height - tooltip.height)),
    );
  }

  Widget _buildMobileNavBar(
    BuildContext context,
    int selectedIndex, {
    required List<NavDestination> primary,
    required List<NavDestination> overflow,
    required bool alwaysHideLabels,
  }) {
    final navAccent = _navAccentLookup(context);
    return NavigationBar(
      selectedIndex: selectedIndex,
      labelBehavior: alwaysHideLabels
          ? NavigationDestinationLabelBehavior.alwaysHide
          : NavigationDestinationLabelBehavior.alwaysShow,
      onDestinationSelected: (index) => _onDestinationSelected(
        index,
        destinations: primary,
        overflow: overflow,
      ),
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
