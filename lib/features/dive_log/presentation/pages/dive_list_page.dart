import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/map_tile_config.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/add_dive_bottom_sheet.dart';
import 'package:submersion/shared/widgets/debounced_search_results.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_map_content.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_panel.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_summary_widget.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_numbering_dialog.dart';
import 'package:submersion/features/dive_log/presentation/widgets/table_column_picker.dart';
import 'package:submersion/shared/widgets/list_view_mode_toggle.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/shared/widgets/table_mode_layout/table_mode_layout.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Compute a single map tile URL for the given lat/lng at [zoom].
///
/// Converts WGS-84 coordinates to slippy map tile x/y using the standard
/// Web Mercator projection formula, then returns the tile URL for the
/// requested [style] (Street, Topo, or Satellite).
String _tileUrl(double lat, double lng, int zoom, MapStyle style) {
  final n = 1 << zoom; // 2^zoom
  final x = ((lng + 180.0) / 360.0 * n).floor();
  final latRad = lat * math.pi / 180.0;
  final y =
      ((1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
              2.0 *
              n)
          .floor();
  return MapTileConfig.tileUrl(style, zoom, x, y);
}

/// Main dive list page with master-detail layout on desktop.
///
/// On desktop (>=800px): Shows a split view with list on left, detail/summary on right.
/// On narrower screens (<800px): Shows the list with navigation to detail pages.
class DiveListPage extends ConsumerStatefulWidget {
  const DiveListPage({super.key});

  @override
  ConsumerState<DiveListPage> createState() => _DiveListPageState();
}

class _DiveListPageState extends ConsumerState<DiveListPage> {
  /// Tracks the selected dive ID for mobile map view info card
  String? _mobileMapSelectedDiveId;

  bool get _isMapView {
    final state = GoRouterState.of(context);
    return state.uri.queryParameters['view'] == 'map';
  }

  void _showAddDiveSheet(BuildContext context) {
    final isDesktop = ResponsiveBreakpoints.isMasterDetail(context);
    final viewMode = ref.read(diveListViewModeProvider);
    showAddDiveBottomSheet(
      context: context,
      onLogManually: () {
        // Table mode uses full-width layout (no detail pane), so always push
        if (isDesktop && viewMode != ListViewMode.table) {
          final state = GoRouterState.of(context);
          final currentPath = state.uri.path;
          context.go('$currentPath?mode=new');
        } else {
          context.push('/dives/new');
        }
      },
    );
  }

  void _toggleMapView() {
    final router = GoRouter.of(context);
    final state = GoRouterState.of(context);
    final currentPath = state.uri.path;
    final selectedId = state.uri.queryParameters['selected'];

    if (_isMapView) {
      // Switch back to detail view
      if (selectedId != null) {
        router.go('$currentPath?selected=$selectedId');
      } else {
        router.go(currentPath);
      }
    } else {
      // Switch to map view
      if (selectedId != null) {
        router.go('$currentPath?selected=$selectedId&view=map');
      } else {
        router.go('$currentPath?view=map');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Clear mobile map selection when filters change to avoid stale state
    ref.listen<DiveFilterState>(diveFilterProvider, (previous, next) {
      if (_mobileMapSelectedDiveId != null) {
        setState(() => _mobileMapSelectedDiveId = null);
      }
    });

    // Use desktop breakpoint (800px) to show master-detail when NavigationRail appears
    final showMasterDetail = ResponsiveBreakpoints.isMasterDetail(context);

    final fab = FloatingActionButton.extended(
      onPressed: () => _showAddDiveSheet(context),
      tooltip: context.l10n.diveLog_listPage_fab_logDive,
      icon: const Icon(Icons.add),
      label: Text(context.l10n.diveLog_listPage_fab_logDive),
    );

    // Table mode: use shared TableModeLayout for full-width table with
    // optional detail pane, map, and profile panel.
    final viewMode = ref.watch(diveListViewModeProvider);
    if (viewMode == ListViewMode.table) {
      final showProfile = ref.watch(showProfilePanelProvider);

      return TableModeLayout(
        sectionKey: 'dives',
        appBarTitle: context.l10n.nav_dives,
        tableContent: const DiveListContent(showAppBar: false),
        detailBuilder: (context, id) => DiveDetailPage(
          diveId: id,
          embedded: true,
          onDeleted: () {
            final state = GoRouterState.of(context);
            context.go(state.uri.path);
          },
        ),
        summaryBuilder: (context) => const DiveSummaryWidget(),
        editBuilder: (context, id, onSaved, onCancel) => DiveEditPage(
          diveId: id,
          embedded: true,
          onSaved: onSaved,
          onCancel: onCancel,
        ),
        createBuilder: (context, onSaved, onCancel) =>
            DiveEditPage(embedded: true, onSaved: onSaved, onCancel: onCancel),
        mapContent: DiveMapContent(
          selectedId: ref.watch(highlightedDiveIdProvider),
          onItemSelected: (diveId) {
            ref.read(highlightedDiveIdProvider.notifier).state = diveId;
          },
          onDetailsTap: (diveId) => context.push('/dives/$diveId'),
        ),
        profilePanelContent: const DiveProfilePanel(),
        showProfilePanel: showProfile,
        onProfileToggled: () {
          final newValue = !ref.read(showProfilePanelProvider);
          ref.read(showProfilePanelProvider.notifier).state = newValue;
          ref
              .read(settingsProvider.notifier)
              .setShowProfilePanelInTableView(newValue);
        },
        selectedId: ref.watch(highlightedDiveIdProvider),
        onEntitySelected: (id) {
          ref.read(highlightedDiveIdProvider.notifier).state = id;
        },
        isMapViewActive: _isMapView,
        onMapViewToggle: _toggleMapView,
        columnSettingsAction: IconButton(
          icon: const Icon(Icons.view_column_outlined),
          tooltip: 'Column settings',
          onPressed: () => showTableColumnPicker(context),
        ),
        appBarActions: [
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            tooltip: 'Search dives',
            onPressed: () {
              showSearch(context: context, delegate: DiveSearchDelegate(ref));
            },
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: ref.watch(diveFilterProvider).hasActiveFilters,
              child: const Icon(Icons.filter_list, size: 20),
            ),
            tooltip: 'Filter dives',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => DiveFilterSheet(ref: ref),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) {
              if (value == 'advanced_search') {
                context.push('/dives/search');
              } else if (value == 'match_sites') {
                context.push('/dives/match-sites');
              } else if (value == 'numbering') {
                showDiveNumberingDialog(context);
              } else if (value.startsWith('view_')) {
                final mode = ListViewMode.fromName(
                  value.replaceFirst('view_', ''),
                );
                ref.read(diveListViewModeProvider.notifier).state = mode;
              }
            },
            itemBuilder: (context) {
              final currentMode = ref.read(diveListViewModeProvider);
              return [
                ...ListViewModeToggle.menuItems(
                  context,
                  currentMode: currentMode,
                  modes: const [
                    ListViewMode.detailed,
                    ListViewMode.compact,
                    ListViewMode.table,
                  ],
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'advanced_search',
                  child: Row(
                    children: [
                      const Icon(Icons.manage_search, size: 20),
                      const SizedBox(width: 12),
                      Text(context.l10n.diveLog_listPage_menuAdvancedSearch),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'numbering',
                  child: Row(
                    children: [
                      const Icon(Icons.format_list_numbered, size: 20),
                      const SizedBox(width: 12),
                      Text(context.l10n.diveLog_listPage_menuDiveNumbering),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'match_sites',
                  child: Row(
                    children: [
                      const Icon(Icons.add_location_alt_outlined, size: 20),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          context.l10n.diveLog_listPage_menuMatchSites,
                        ),
                      ),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
        floatingActionButton: fab,
      );
    }

    if (showMasterDetail) {
      // Desktop: Use master-detail layout
      return MasterDetailScaffold(
        sectionId: 'dives',
        masterBuilder: (context, onItemSelected, selectedId) => DiveListContent(
          onItemSelected: onItemSelected,
          selectedId: selectedId,
          showAppBar: false,
          isMapViewActive: _isMapView,
          onMapViewToggle: _toggleMapView,
        ),
        detailBuilder: (context, diveId) => DiveDetailPage(
          diveId: diveId,
          embedded: true,
          onDeleted: () {
            // Clear selection when dive is deleted
            final router = GoRouter.of(context);
            final state = GoRouterState.of(context);
            router.go(state.uri.path);
          },
        ),
        summaryBuilder: (context) => const DiveSummaryWidget(),
        mapBuilder: (context, selectedId, onItemSelected) => DiveMapContent(
          selectedId: selectedId,
          onItemSelected: onItemSelected,
          onDetailsTap: (diveId) {
            // Exit map view and show detail pane for the selected dive
            final state = GoRouterState.of(context);
            final currentPath = state.uri.path;
            context.go('$currentPath?selected=$diveId');
          },
        ),
        editBuilder: (context, diveId, onSaved, onCancel) => DiveEditPage(
          diveId: diveId,
          embedded: true,
          onSaved: onSaved,
          onCancel: onCancel,
        ),
        createBuilder: (context, onSaved, onCancel) =>
            DiveEditPage(embedded: true, onSaved: onSaved, onCancel: onCancel),
        floatingActionButton: fab,
        onFabPressed: () => _showAddDiveSheet(context),
      );
    }

    // Mobile: Check if map view is requested
    if (_isMapView) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.diveLog_listPage_appBar_diveMap),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: context.l10n.diveLog_listPage_tooltip_backToDiveList,
            onPressed: () => context.go('/dives'),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.list),
              tooltip: context.l10n.diveLog_listPage_tooltip_listView,
              onPressed: _toggleMapView,
            ),
          ],
        ),
        body: DiveMapContent(
          selectedId: _mobileMapSelectedDiveId,
          onItemSelected: (diveId) {
            setState(() => _mobileMapSelectedDiveId = diveId);
          },
          onDetailsTap: (diveId) => context.push('/dives/$diveId'),
        ),
        floatingActionButton: fab,
      );
    }

    // Mobile: Use standalone list content with full scaffold and FAB
    return DiveListContent(showAppBar: true, floatingActionButton: fab);
  }
}

/// Search delegate for diving through dive logs
class DiveSearchDelegate extends SearchDelegate<Dive?> {
  final WidgetRef ref;

  DiveSearchDelegate(this.ref);

  // TODO: l10n - needs context (SearchDelegate.searchFieldLabel has no BuildContext)
  @override
  String get searchFieldLabel => 'Search dives...';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: context.l10n.diveLog_listPage_tooltip_clearSearch,
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: context.l10n.diveLog_listPage_tooltip_back,
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.search,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.diveLog_listPage_searchSuggestion,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    return DebouncedSearchResults<Dive>(
      query: query,
      watchProvider: (ref, q) => ref.watch(diveSearchProvider(q)),
      emptyBuilder: (context, q) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.search_off,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.diveLog_listPage_searchNoResults(q),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      dataBuilder: (context, dives) {
        final colorAttribute = ref.read(settingsProvider).cardColorAttribute;
        final colorValues = dives
            .map((d) => getCardColorValueFromDive(d, colorAttribute))
            .whereType<double>();
        final minValue = colorValues.isNotEmpty
            ? colorValues.reduce((a, b) => a < b ? a : b)
            : null;
        final maxValue = colorValues.isNotEmpty
            ? colorValues.reduce((a, b) => a > b ? a : b)
            : null;

        return ListView.builder(
          itemCount: dives.length,
          itemBuilder: (context, index) {
            final dive = dives[index];
            return DiveListTile(
              diveId: dive.id,
              diveNumber: dive.diveNumber ?? index + 1,
              dateTime: dive.dateTime,
              siteName: dive.site?.name,
              siteLocation: dive.site?.locationString,
              maxDepth: dive.maxDepth,
              duration: dive.bottomTime,
              waterTemp: dive.waterTemp,
              rating: dive.rating,
              isFavorite: dive.isFavorite,
              tags: dive.tags,
              colorValue: getCardColorValueFromDive(dive, colorAttribute),
              minValueInList: minValue,
              maxValueInList: maxValue,
              siteLatitude: dive.site?.location?.latitude,
              siteLongitude: dive.site?.location?.longitude,
              onTap: () {
                close(context, dive);
                context.go('/dives/${dive.id}');
              },
            );
          },
        );
      },
      errorBuilder: (context, error) => Center(
        child: Text(
          context.l10n.diveLog_listPage_errorLoading(error.toString()),
        ),
      ),
    );
  }
}

/// List item widget for displaying a dive summary
class DiveListTile extends ConsumerWidget {
  final String diveId;
  final int diveNumber;
  final DateTime dateTime;
  final String? siteName;
  final String? siteLocation;
  final double? maxDepth;
  final Duration? duration;
  final double? waterTemp;
  final int? rating;
  final bool isFavorite;
  final List<Tag> tags;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final bool isHighlighted;
  final bool isSelectionMode;
  final bool isSelected;

  /// The dive's value for the active color attribute
  final double? colorValue;

  /// Min value in the current list for normalization
  final double? minValueInList;

  /// Max value in the current list for normalization
  final double? maxValueInList;

  /// Gradient start color (low value)
  final Color? gradientStartColor;

  /// Gradient end color (high value)
  final Color? gradientEndColor;

  /// Site location for map background
  final double? siteLatitude;
  final double? siteLongitude;

  /// Card margin override (defaults to horizontal: 16, vertical: 4)
  final EdgeInsetsGeometry? margin;

  /// Full dive summary used to render configurable extra fields.
  ///
  /// When provided and [detailedCardConfigProvider] has extra fields configured,
  /// an additional row of label:value pairs is rendered below the tags section.
  final DiveSummary? summary;

  /// Full Dive object for fields not available on DiveSummary (tanks, buddy,
  /// weights, SAC, etc.). When provided, extractFromDive is used for stat
  /// slots and extra fields, giving access to all fields.
  final Dive? fullDive;

  const DiveListTile({
    super.key,
    required this.diveId,
    required this.diveNumber,
    required this.dateTime,
    this.siteName,
    this.siteLocation,
    this.maxDepth,
    this.duration,
    this.waterTemp,
    this.rating,
    this.isFavorite = false,
    this.tags = const [],
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
    this.isHighlighted = false,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.colorValue,
    this.minValueInList,
    this.maxValueInList,
    this.gradientStartColor,
    this.gradientEndColor,
    this.siteLatitude,
    this.siteLongitude,
    this.margin,
    this.summary,
    this.fullDive,
  });

  /// Calculate background color based on the active color attribute
  Color? _getAttributeBackgroundColor() {
    return normalizeAndLerp(
      value: colorValue,
      min: minValueInList,
      max: maxValueInList,
      startColor: gradientStartColor ?? const Color(0xFF4DD0E1),
      endColor: gradientEndColor ?? const Color(0xFF0D1B2A),
    );
  }

  /// Determine if text should be light or dark based on background color
  bool _shouldUseLightText(Color backgroundColor) {
    // Use luminance to determine if background is dark
    // Luminance < 0.5 means dark background, needs light text
    return backgroundColor.computeLuminance() < 0.5;
  }

  /// Check if map background should be shown
  bool get _hasLocation => siteLatitude != null && siteLongitude != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final profileCache = ref.watch(batchProfileCacheProvider);
    final profile = profileCache[diveId] ?? const [];

    // Check if attribute-colored cards are enabled
    final colorAttribute = ref.watch(cardColorAttributeProvider);
    final showCardColors = colorAttribute != CardColorAttribute.none;
    // Check if map background is enabled
    final showMapBackground = ref.watch(showMapBackgroundOnDiveCardsProvider);

    // Determine if we should show the map (setting enabled + location available)
    final shouldShowMap = showMapBackground && _hasLocation && !isSelected;

    // Determine card background: selection takes priority, then attribute coloring
    // When map is shown, we don't use attribute coloring on the card itself
    final attributeColor = (showCardColors && !shouldShowMap)
        ? _getAttributeBackgroundColor()
        : null;
    final cardColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.5)
        : isHighlighted
        ? colorScheme.primaryContainer.withValues(alpha: 0.15)
        : attributeColor;

    // Determine text colors based on background luminance
    // When map is shown, use light text since the gradient overlay makes the background dark
    final effectiveBackground = shouldShowMap
        ? const Color(0xFF1A1A2E) // Dark background for map overlay
        : (cardColor ?? colorScheme.surfaceContainerHighest);
    final useLightText = _shouldUseLightText(effectiveBackground);
    final primaryTextColor = useLightText ? Colors.white : Colors.black87;
    final secondaryTextColor = useLightText ? Colors.white70 : Colors.black54;
    // Use contrasting accent colors: light cyan on dark backgrounds, dark teal on light backgrounds
    final accentColor = useLightText
        ? Colors.cyan.shade200
        : Colors.teal.shade800;

    // Detailed card config: slots + extra fields
    final detailedConfig = ref.watch(detailedCardConfigProvider);
    final extraFields = detailedConfig.extraFields;

    // Resolve slot fields (fallback to defaults if no slots configured)
    DiveField slotField(String slotId, DiveField fallback) {
      for (final slot in detailedConfig.slots) {
        if (slot.slotId == slotId) return slot.field;
      }
      return fallback;
    }

    final stat1Field = slotField('stat1', DiveField.maxDepth);
    final stat2Field = slotField('stat2', DiveField.runtime);
    final titleField = slotField('title', DiveField.siteName);
    final dateField = slotField('date', DiveField.dateTime);

    // Resolve the title and date lines from their slot assignments, keeping
    // the legacy rendering when the slot holds its default field (mirrors
    // CompactDiveListTile).
    String buildTitleText() {
      if (summary != null && titleField != DiveField.siteName) {
        final value = titleField.extractFromSummary(summary!);
        return titleField.formatValue(value, units);
      }
      return siteName ?? context.l10n.diveLog_listPage_unknownSite;
    }

    String buildDateText() {
      if (summary != null && dateField != DiveField.dateTime) {
        final value = dateField.extractFromSummary(summary!);
        return dateField.formatValue(value, units);
      }
      return units.formatDateTime(dateTime, l10n: context.l10n);
    }

    // Build the content widget (used in both map and non-map variants)
    Widget buildContent() {
      return LayoutBuilder(
        builder: (context, constraints) {
          // Calculate chart width based on available space
          // On narrow screens (< 400), use ~25% of width
          // On wider screens, cap at 120px
          final availableWidth = constraints.maxWidth;
          final chartWidth = availableWidth < 400
              ? (availableWidth * 0.25).clamp(60.0, 120.0)
              : (availableWidth * 0.20).clamp(80.0, 120.0);

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: avatar/checkbox, text info, chart, chevron
                Row(
                  children: [
                    // Selection checkbox or dive number badge
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: isSelectionMode
                          ? Center(
                              child: Checkbox(
                                value: isSelected,
                                onChanged: (_) => onTap?.call(),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                            )
                          : CircleAvatar(
                              backgroundColor: colorScheme.primaryContainer,
                              child: Text(
                                '#$diveNumber',
                                style: TextStyle(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    // Main text content (site, location, date)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Site name with favorite and rating
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  buildTitleText(),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: primaryTextColor,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isFavorite) ...[
                                const SizedBox(width: 4),
                                ExcludeSemantics(
                                  child: Icon(
                                    Icons.favorite,
                                    size: 18,
                                    color: Colors.red.shade400,
                                  ),
                                ),
                              ],
                              if (rating != null) ...[
                                const SizedBox(width: 8),
                                ExcludeSemantics(
                                  child: Icon(
                                    Icons.star,
                                    size: 16,
                                    color: Colors.amber.shade600,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '$rating',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: primaryTextColor,
                                      ),
                                ),
                              ],
                            ],
                          ),
                          // Site location (country/region)
                          if (siteLocation != null &&
                              siteLocation!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              siteLocation!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: secondaryTextColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          // Date/subtitle line (configurable via 'date' slot)
                          Text(
                            buildDateText(),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: secondaryTextColor),
                          ),
                        ],
                      ),
                    ),
                    // Dive profile mini chart (right side)
                    if (profile.isNotEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 8),
                        child: SizedBox(
                          width: chartWidth,
                          height: 50,
                          child: DiveProfileMiniChart(
                            profile: profile,
                            height: 50,
                            color: accentColor,
                          ),
                        ),
                      ),
                    // Chevron
                    ExcludeSemantics(
                      child: Icon(
                        Icons.chevron_right,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Stats row: configurable via slot assignments
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 52),
                  child: Row(
                    children: [
                      _buildStatWidget(
                        stat1Field,
                        summary,
                        units,
                        context,
                        accentColor,
                        secondaryTextColor,
                      ),
                      const SizedBox(width: 16),
                      _buildStatWidget(
                        stat2Field,
                        summary,
                        units,
                        context,
                        accentColor,
                        secondaryTextColor,
                      ),
                    ],
                  ),
                ),
                // Tags
                if (tags.isNotEmpty && detailedConfig.showTags) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 52),
                    child: TagChips(tags: tags, maxTags: 3),
                  ),
                ],
                // Extra configurable fields area
                if (extraFields.isNotEmpty &&
                    (fullDive != null || summary != null)) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 52),
                    child: LayoutBuilder(
                      builder: (context, innerConstraints) {
                        final useOneColumn = innerConstraints.maxWidth < 250;
                        return Wrap(
                          spacing: 16,
                          runSpacing: 4,
                          children: extraFields.map((field) {
                            final value = fullDive != null
                                ? field.extractFromDive(
                                    fullDive!,
                                    sacUnit: units.sacUnit,
                                  )
                                : (field.extractFromSummary(summary!) ??
                                      _fallbackValue(field));
                            final formatted = field.formatValue(value, units);
                            return SizedBox(
                              width: useOneColumn
                                  ? innerConstraints.maxWidth
                                  : (innerConstraints.maxWidth - 16) / 2,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${field.shortLabel}: ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: secondaryTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      formatted,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: primaryTextColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    }

    // Build the card with or without map background
    if (shouldShowMap) {
      final tileUrl = _tileUrl(
        siteLatitude!,
        siteLongitude!,
        13,
        ref.watch(settingsProvider.select((s) => s.mapStyle)),
      );
      return Card(
        margin:
            margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          button: true,
          label: 'Dive $diveNumber at ${siteName ?? 'Unknown Site'}',
          child: InkWell(
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            onLongPress: onLongPress,
            child: Stack(
              children: [
                // Static map tile background (cached)
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: tileUrl,
                    httpHeaders: const {
                      'User-Agent': 'Submersion Dive Log App (app.submersion)',
                    },
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    placeholder: (_, _) =>
                        Container(color: const Color(0xFF1A1A2E)),
                    errorWidget: (_, _, _) =>
                        Container(color: const Color(0xFF1A1A2E)),
                  ),
                ),
                // Gradient overlay for text readability
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.3, 0.7, 1.0],
                        colors: [
                          Colors.black.withValues(alpha: 0.4),
                          Colors.black.withValues(alpha: 0.5),
                          Colors.black.withValues(alpha: 0.7),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ),
                // Content layer
                buildContent(),
              ],
            ),
          ),
        ),
      );
    }

    // Standard card without map
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: isHighlighted
          ? BoxDecoration(
              border: Border(
                left: BorderSide(color: colorScheme.primary, width: 3),
              ),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Card(
        margin: EdgeInsets.zero,
        color: cardColor,
        child: Semantics(
          button: true,
          label: 'Dive $diveNumber at ${siteName ?? 'Unknown Site'}',
          child: InkWell(
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(12),
            child: buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildStatWidget(
    DiveField field,
    DiveSummary? summary,
    UnitFormatter units,
    BuildContext context,
    Color accentColor,
    Color secondaryTextColor,
  ) {
    // Use full Dive when available (has all fields), otherwise try summary
    dynamic value = fullDive != null
        ? field.extractFromDive(fullDive!, sacUnit: units.sacUnit)
        : summary != null
        ? field.extractFromSummary(summary)
        : null;
    value ??= _fallbackValue(field);
    final formatted = field.formatValue(value, units);
    final hasValue = value != null;
    final color = hasValue ? accentColor : secondaryTextColor;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: color);
    final icon = field.icon;

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 14, color: color)),
          const SizedBox(width: 4),
          Text(formatted, style: style),
        ],
      );
    }
    return Text('${field.shortLabel}: $formatted', style: style);
  }

  /// Returns the value from the tile's constructor params for known fields.
  dynamic _fallbackValue(DiveField field) {
    return switch (field) {
      DiveField.maxDepth => maxDepth,
      DiveField.bottomTime => duration,
      DiveField.runtime => duration,
      DiveField.waterTemp => waterTemp,
      DiveField.ratingStars => rating,
      DiveField.isFavorite => isFavorite,
      DiveField.siteName => siteName,
      DiveField.siteLocation => siteLocation,
      DiveField.dateTime => dateTime,
      _ => null,
    };
  }
}
