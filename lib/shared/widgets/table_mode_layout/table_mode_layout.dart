import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/providers/table_details_pane_provider.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// A shared layout widget that manages the table mode state machine for all
/// entity sections (Dives, Sites, Buddies, etc.).
///
/// Encapsulates the layout decisions for toggling between:
/// - Full-width table only
/// - Table + detail pane (via MasterDetailScaffold)
/// - Table + map side-by-side
/// - Table + map + detail pane
/// - Table + profile panel (Dives only)
///
/// The state machine is driven by three boolean flags:
/// - Details ON/OFF (persisted via [tableDetailsPaneProvider])
/// - Map ON/OFF (managed externally via [isMapViewActive])
/// - Profile ON/OFF (managed externally via [showProfilePanel])
///
/// Profile and Details are mutually exclusive: toggling one disables the other.
/// The caller is responsible for wiring [showProfilePanel] and
/// [onProfileToggled] to the appropriate provider.
class TableModeLayout extends ConsumerWidget {
  /// Section identifier used for provider keys and URL state (e.g., 'dives').
  final String sectionKey;

  /// Title shown in the app bar.
  final String appBarTitle;

  /// The table content widget (EntityTableView or similar).
  final Widget tableContent;

  /// Builder for the detail pane when an item is selected.
  final Widget Function(BuildContext, String) detailBuilder;

  /// Builder for the summary view when no item is selected.
  final Widget Function(BuildContext) summaryBuilder;

  /// Builder for the edit pane when editing an existing item.
  final Widget Function(
    BuildContext,
    String,
    void Function(String),
    VoidCallback,
  )?
  editBuilder;

  /// Builder for creating a new item.
  final Widget Function(BuildContext, void Function(String), VoidCallback)?
  createBuilder;

  /// Pre-built map widget. When non-null, the map toggle button appears.
  final Widget? mapContent;

  /// Pre-built profile panel widget (Dives only). When non-null, the profile
  /// toggle button appears.
  final Widget? profilePanelContent;

  /// Column settings action rendered with the view toggles (left of divider).
  final Widget? columnSettingsAction;

  /// Additional app bar actions (search, sort, overflow menu, etc.).
  final List<Widget>? appBarActions;

  /// Currently selected entity ID for the detail pane.
  final String? selectedId;

  /// Callback when an entity row is tapped.
  final void Function(String) onEntitySelected;

  /// Callback when an entity row is double-tapped.
  final void Function(String)? onEntityDoubleTap;

  /// Whether multi-selection mode is active.
  final bool isSelectionMode;

  /// Set of currently selected entity IDs in multi-selection mode.
  final Set<String> selectedIds;

  /// Callback when selection changes in multi-selection mode.
  final void Function(String)? onSelectionChanged;

  /// Custom app bar to show during selection mode.
  final PreferredSizeWidget? selectionAppBar;

  /// Floating action button.
  final Widget? floatingActionButton;

  /// Whether the map view is currently active.
  final bool isMapViewActive;

  /// Callback when the map toggle is pressed. If null and [mapContent] is null,
  /// the map toggle button is hidden.
  final VoidCallback? onMapViewToggle;

  /// Whether the profile panel is currently visible (Dives only).
  ///
  /// The caller reads the appropriate provider and passes the value here.
  /// Defaults to false (profile panel hidden).
  final bool showProfilePanel;

  /// Called when the user taps the profile toggle button.
  ///
  /// The caller is responsible for updating the provider and handling mutual
  /// exclusion with other panels. When non-null and [profilePanelContent] is
  /// provided, the profile toggle button is interactive.
  final VoidCallback? onProfileToggled;

  const TableModeLayout({
    super.key,
    required this.sectionKey,
    required this.appBarTitle,
    required this.tableContent,
    required this.detailBuilder,
    required this.summaryBuilder,
    required this.onEntitySelected,
    this.editBuilder,
    this.createBuilder,
    this.mapContent,
    this.profilePanelContent,
    this.columnSettingsAction,
    this.appBarActions,
    this.selectedId,
    this.onEntityDoubleTap,
    this.isSelectionMode = false,
    this.selectedIds = const {},
    this.onSelectionChanged,
    this.selectionAppBar,
    this.floatingActionButton,
    this.isMapViewActive = false,
    this.onMapViewToggle,
    this.showProfilePanel = false,
    this.onProfileToggled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = ResponsiveBreakpoints.isMasterDetail(context);
    final showDetails =
        isDesktop && ref.watch(tableDetailsPaneProvider(sectionKey));
    final showMap = isMapViewActive && mapContent != null;
    final showProfile = profilePanelContent != null && showProfilePanel;

    // Pre-compute toggle actions so the closures capture the correct context
    // and ref without relying on closures inside builder callbacks.
    final toggleActions = _buildToggleActions(
      context,
      ref,
      isDesktop: isDesktop,
      showDetails: showDetails,
    );

    if (showDetails) {
      // When details pane is active, profile and map are mutually exclusive.
      return _buildWithDetailPane(
        context,
        ref,
        showMap: showMap && !showProfile,
        showProfile: showProfile && !showMap,
        toggleActions: toggleActions,
      );
    }

    // No detail pane -- full-width layouts
    return _buildFullWidth(context, toggleActions, showMap, showProfile);
  }

  /// Build the layout with the detail pane active via MasterDetailScaffold.
  Widget _buildWithDetailPane(
    BuildContext context,
    WidgetRef ref, {
    required bool showMap,
    required bool showProfile,
    required List<Widget> toggleActions,
  }) {
    return MasterDetailScaffold(
      sectionId: sectionKey,
      masterBuilder: (context, onItemSelected, mdsSelectedId) {
        return _TableModeMaster(
          appBarTitle: appBarTitle,
          tableContent: tableContent,
          mapContent: showMap ? mapContent : null,
          profilePanelContent: showProfile ? profilePanelContent : null,
          toggleActions: toggleActions,
          selectionAppBar: isSelectionMode ? selectionAppBar : null,
          isSelectionMode: isSelectionMode,
          selectedId: selectedId,
          onItemSelected: onItemSelected,
        );
      },
      detailBuilder: detailBuilder,
      summaryBuilder: summaryBuilder,
      editBuilder: editBuilder,
      createBuilder: createBuilder,
      floatingActionButton: floatingActionButton,
    );
  }

  /// Build a full-width layout (no detail pane).
  Widget _buildFullWidth(
    BuildContext context,
    List<Widget> toggleActions,
    bool showMap,
    bool showProfile,
  ) {
    final body = _buildBody(context, showMap, showProfile);

    return Scaffold(
      appBar: isSelectionMode && selectionAppBar != null
          ? selectionAppBar
          : AppBar(title: Text(appBarTitle), actions: toggleActions),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }

  /// Compose the body widget based on map and profile state.
  Widget _buildBody(BuildContext context, bool showMap, bool showProfile) {
    // Map ON: full-page on mobile, side-by-side split on desktop
    if (showMap) {
      if (ResponsiveBreakpoints.isMobile(context)) {
        return mapContent!;
      }

      final leftColumn = showProfile
          ? Column(
              children: [
                profilePanelContent!,
                Expanded(child: tableContent),
              ],
            )
          : tableContent;

      return Row(
        children: [
          Expanded(child: leftColumn),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: mapContent!),
        ],
      );
    }

    // Profile ON, no map: Column with profile panel above table
    if (showProfile) {
      return Column(
        children: [
          profilePanelContent!,
          Expanded(child: tableContent),
        ],
      );
    }

    // Default: full-width table only
    return tableContent;
  }

  /// Build the list of toggle action buttons for the app bar.
  List<Widget> _buildToggleActions(
    BuildContext context,
    WidgetRef ref, {
    required bool isDesktop,
    required bool showDetails,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final actions = <Widget>[];

    // Profile toggle (Dives only, appears when both content and callback exist)
    if (profilePanelContent != null && onProfileToggled != null) {
      actions.add(
        IconButton(
          key: const ValueKey('profile_toggle'),
          icon: Icon(
            Icons.area_chart,
            color: showProfilePanel ? colorScheme.primary : null,
          ),
          tooltip: 'Toggle profile panel',
          onPressed: () {
            onProfileToggled?.call();
            // When details pane is active, profile and map are mutually
            // exclusive: turning profile ON turns map OFF.
            if (!showProfilePanel && showDetails && isMapViewActive) {
              onMapViewToggle?.call();
            }
          },
        ),
      );
    }

    // Details toggle (desktop only)
    if (isDesktop) {
      final isDetailsActive = ref.watch(tableDetailsPaneProvider(sectionKey));
      actions.add(
        IconButton(
          key: const ValueKey('details_toggle'),
          icon: Icon(
            Icons.vertical_split,
            color: isDetailsActive ? colorScheme.primary : null,
          ),
          tooltip: 'Toggle detail pane',
          onPressed: () {
            final newValue = !ref.read(tableDetailsPaneProvider(sectionKey));
            ref.read(tableDetailsPaneProvider(sectionKey).notifier).state =
                newValue;
            ref
                .read(settingsProvider.notifier)
                .setShowDetailsPaneForSection(sectionKey, newValue);
          },
        ),
      );
    }

    // Map toggle (when map support is available)
    if (mapContent != null || onMapViewToggle != null) {
      actions.add(
        IconButton(
          key: const ValueKey('map_toggle'),
          icon: Icon(
            Icons.map,
            color: isMapViewActive ? colorScheme.primary : null,
          ),
          tooltip: isMapViewActive ? 'Hide map' : 'Show map',
          onPressed: () {
            onMapViewToggle?.call();
            // When details pane is active, map and profile are mutually
            // exclusive: turning map ON turns profile OFF.
            if (!isMapViewActive && showDetails && showProfilePanel) {
              onProfileToggled?.call();
            }
          },
        ),
      );
    }

    // Column settings (grouped with view toggles, left of divider)
    if (columnSettingsAction != null) {
      actions.add(columnSettingsAction!);
    }

    // Vertical divider between view toggles and table-specific actions
    if (appBarActions != null &&
        appBarActions!.isNotEmpty &&
        actions.isNotEmpty) {
      actions.add(
        SizedBox(
          height: 24,
          child: VerticalDivider(
            width: 16,
            thickness: 1,
            color: colorScheme.outlineVariant,
          ),
        ),
      );
    }

    // Table-specific actions (search, sort, column settings, overflow, etc.)
    if (appBarActions != null) {
      actions.addAll(appBarActions!);
    }

    return actions;
  }
}

/// The master pane content when used inside MasterDetailScaffold.
///
/// Renders the app bar as a regular widget (not a Scaffold app bar) since
/// MasterDetailScaffold already provides the outer Scaffold.
///
/// Bridges provider-driven [selectedId] changes to MasterDetailScaffold's
/// URL-based selection via [onItemSelected] using a debounced timer. The
/// delay (500ms) is longer than [kDoubleTapTimeout] (~300ms) so that a
/// double-tap's [context.push] fires before the bridge can call
/// [router.go], preventing the pushed page from being clobbered.
class _TableModeMaster extends StatefulWidget {
  final String appBarTitle;
  final Widget tableContent;
  final Widget? mapContent;
  final Widget? profilePanelContent;
  final List<Widget> toggleActions;
  final PreferredSizeWidget? selectionAppBar;
  final bool isSelectionMode;
  final String? selectedId;
  final void Function(String?)? onItemSelected;

  const _TableModeMaster({
    required this.appBarTitle,
    required this.tableContent,
    required this.toggleActions,
    this.mapContent,
    this.profilePanelContent,
    this.selectionAppBar,
    this.isSelectionMode = false,
    this.selectedId,
    this.onItemSelected,
  });

  @override
  State<_TableModeMaster> createState() => _TableModeMasterState();
}

class _TableModeMasterState extends State<_TableModeMaster> {
  Timer? _syncTimer;

  @override
  void didUpdateWidget(_TableModeMaster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedId != oldWidget.selectedId) {
      // Debounce: wait longer than kDoubleTapTimeout so that a double-tap's
      // context.push fires first. If the widget is disposed (e.g. by the
      // push navigation), the timer is cancelled in dispose().
      _syncTimer?.cancel();
      _syncTimer = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        widget.onItemSelected?.call(widget.selectedId);
      });
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasOverlay =
        widget.mapContent != null || widget.profilePanelContent != null;
    return Column(
      children: [
        if (widget.isSelectionMode && widget.selectionAppBar != null)
          widget.selectionAppBar!
        else
          AppBar(
            title: Text(widget.appBarTitle),
            actions: widget.toggleActions,
          ),
        if (widget.profilePanelContent != null) widget.profilePanelContent!,
        if (widget.mapContent != null) Expanded(child: widget.mapContent!),
        Expanded(flex: hasOverlay ? 2 : 1, child: widget.tableContent),
      ],
    );
  }
}
