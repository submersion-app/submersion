import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/card_color.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_map_content.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_summary_widget.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Compute a single OSM tile URL for the given lat/lng at [zoom].
///
/// Converts WGS-84 coordinates to slippy map tile x/y using the standard
/// Web Mercator projection formula, then returns the OSM raster tile URL.
String _osmTileUrl(double lat, double lng, int zoom) {
  final n = 1 << zoom; // 2^zoom
  final x = ((lng + 180.0) / 360.0 * n).floor();
  final latRad = lat * math.pi / 180.0;
  final y =
      ((1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
              2.0 *
              n)
          .floor();
  return 'https://tile.openstreetmap.org/$zoom/$x/$y.png';
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
      onPressed: () {
        if (showMasterDetail) {
          final state = GoRouterState.of(context);
          final currentPath = state.uri.path;
          context.go('$currentPath?mode=new');
        } else {
          context.push('/dives/new');
        }
      },
      icon: const Icon(Icons.add),
      label: Text(context.l10n.diveLog_listPage_fab_logDive),
    );

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
    final searchAsync = ref.watch(diveSearchProvider(query));

    return searchAsync.when(
      data: (dives) {
        if (dives.isEmpty) {
          return Center(
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
                  context.l10n.diveLog_listPage_searchNoResults(query),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        // Calculate depth range for relative depth coloring
        final depthsWithValues = dives
            .where((d) => d.maxDepth != null)
            .map((d) => d.maxDepth!);
        final minDepth = depthsWithValues.isNotEmpty
            ? depthsWithValues.reduce((a, b) => a < b ? a : b)
            : null;
        final maxDepth = depthsWithValues.isNotEmpty
            ? depthsWithValues.reduce((a, b) => a > b ? a : b)
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
              duration: dive.duration,
              waterTemp: dive.waterTemp,
              rating: dive.rating,
              isFavorite: dive.isFavorite,
              tags: dive.tags,
              colorValue: dive.maxDepth,
              minValueInList: minDepth,
              maxValueInList: maxDepth,
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
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
    this.isSelectionMode = false,
    this.isSelected = false,
    this.colorValue,
    this.minValueInList,
    this.maxValueInList,
    this.gradientStartColor,
    this.gradientEndColor,
    this.siteLatitude,
    this.siteLongitude,
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
        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
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
            child: Row(
              children: [
                // Selection checkbox or dive number badge
                if (isSelectionMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => onTap?.call(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  )
                else
                  CircleAvatar(
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
                const SizedBox(width: 12),
                // Main content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Site name with favorite and rating
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              siteName ??
                                  context.l10n.diveLog_listPage_unknownSite,
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
                      if (siteLocation != null && siteLocation!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          siteLocation!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: secondaryTextColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      // Date and time
                      Text(
                        units.formatDateTime(dateTime, l10n: context.l10n),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Depth and duration stats (always shown)
                      Row(
                        children: [
                          ExcludeSemantics(
                            child: Icon(
                              Icons.arrow_downward,
                              size: 14,
                              color: maxDepth != null
                                  ? accentColor
                                  : secondaryTextColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              units.formatDepth(maxDepth),
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: maxDepth != null
                                        ? accentColor
                                        : secondaryTextColor,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ExcludeSemantics(
                            child: Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: duration != null
                                  ? accentColor
                                  : secondaryTextColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              duration != null
                                  ? _formatDuration(duration!)
                                  : '--',
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: duration != null
                                        ? accentColor
                                        : secondaryTextColor,
                                  ),
                            ),
                          ),
                          if (waterTemp != null) ...[
                            const SizedBox(width: 16),
                            ExcludeSemantics(
                              child: Icon(
                                Icons.thermostat_outlined,
                                size: 14,
                                color: accentColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                units.formatTemperature(waterTemp),
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: accentColor,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Tags
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        TagChips(tags: tags, maxTags: 3),
                      ],
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
                  child: Icon(Icons.chevron_right, color: secondaryTextColor),
                ),
              ],
            ),
          );
        },
      );
    }

    // Build the card with or without map background
    if (shouldShowMap) {
      final tileUrl = _osmTileUrl(siteLatitude!, siteLongitude!, 13);
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          button: true,
          label: 'Dive $diveNumber at ${siteName ?? 'Unknown Site'}',
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Stack(
              children: [
                // Static map tile background (cached)
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: tileUrl,
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: cardColor,
      child: Semantics(
        button: true,
        label: 'Dive $diveNumber at ${siteName ?? 'Unknown Site'}',
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: buildContent(),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    return '$minutes min';
  }
}

/// Filter sheet for dive list
class DiveFilterSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const DiveFilterSheet({super.key, required this.ref});

  @override
  ConsumerState<DiveFilterSheet> createState() => _DiveFilterSheetState();
}

class _DiveFilterSheetState extends ConsumerState<DiveFilterSheet> {
  late DateTime? _startDate;
  late DateTime? _endDate;
  late String? _diveTypeId;
  late String? _siteId;
  late double? _minDepth;
  late double? _maxDepth;
  late bool _favoritesOnly;
  late List<String> _selectedTagIds;

  // v1.5 filters
  late String? _buddyNameFilter;
  late double? _minO2Percent;
  late double? _maxO2Percent;
  late int? _minRating;
  late int? _minDurationMinutes;
  late int? _maxDurationMinutes;

  final _minDepthController = TextEditingController();
  final _maxDepthController = TextEditingController();
  final _buddyNameController = TextEditingController();
  final _minDurationController = TextEditingController();
  final _maxDurationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final filter = widget.ref.read(diveFilterProvider);
    _startDate = filter.startDate;
    _endDate = filter.endDate;
    _diveTypeId = filter.diveTypeId;
    _siteId = filter.siteId;
    _minDepth = filter.minDepth;
    _maxDepth = filter.maxDepth;
    _favoritesOnly = filter.favoritesOnly ?? false;
    _selectedTagIds = List.from(filter.tagIds);
    _minDepthController.text = _minDepth?.toStringAsFixed(0) ?? '';
    _maxDepthController.text = _maxDepth?.toStringAsFixed(0) ?? '';

    // v1.5 filters
    _buddyNameFilter = filter.buddyNameFilter;
    _buddyNameController.text = _buddyNameFilter ?? '';
    _minO2Percent = filter.minO2Percent;
    _maxO2Percent = filter.maxO2Percent;
    _minRating = filter.minRating;
    _minDurationMinutes = filter.minDurationMinutes;
    _maxDurationMinutes = filter.maxDurationMinutes;
    _minDurationController.text = _minDurationMinutes?.toString() ?? '';
    _maxDurationController.text = _maxDurationMinutes?.toString() ?? '';
  }

  @override
  void dispose() {
    _minDepthController.dispose();
    _maxDepthController.dispose();
    _buddyNameController.dispose();
    _minDurationController.dispose();
    _maxDurationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sites = ref.watch(sitesProvider);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter Dives',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close filter',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Link to advanced search
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/dives/search');
                  },
                  icon: const Icon(Icons.manage_search, size: 18),
                  label: const Text('Advanced Search'),
                ),
              ),
              const SizedBox(height: 16),

              // Date Range Section
              Text(
                'Date Range',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDate(context, isStart: true),
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        _startDate != null
                            ? units.formatDate(_startDate)
                            : 'Start Date',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('to'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDate(context, isStart: false),
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        _endDate != null
                            ? units.formatDate(_endDate)
                            : 'End Date',
                      ),
                    ),
                  ),
                ],
              ),
              if (_startDate != null || _endDate != null)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                      });
                    },
                    child: const Text('Clear dates'),
                  ),
                ),
              const SizedBox(height: 24),

              // Dive Type Section
              Text('Dive Type', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Consumer(
                builder: (context, ref, child) {
                  final diveTypesAsync = ref.watch(diveTypesProvider);
                  return diveTypesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, st) => Text('Error: $e'),
                    data: (diveTypes) => DropdownButtonFormField<String?>(
                      initialValue: _diveTypeId,
                      decoration: const InputDecoration(
                        hintText: 'All types',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All types'),
                        ),
                        ...diveTypes.map((type) {
                          return DropdownMenuItem(
                            value: type.id,
                            child: Text(type.name),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() => _diveTypeId = value);
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Site Section
              Text('Dive Site', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              sites.when(
                data: (siteList) => DropdownButtonFormField<String?>(
                  initialValue: _siteId,
                  decoration: const InputDecoration(
                    hintText: 'All sites',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All sites'),
                    ),
                    ...siteList.map((site) {
                      return DropdownMenuItem(
                        value: site.id,
                        child: Text(site.name),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() => _siteId = value);
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('Error loading sites'),
              ),
              const SizedBox(height: 24),

              // Depth Range Section
              Text(
                'Depth Range (meters)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minDepthController,
                      decoration: const InputDecoration(
                        labelText: 'Min',
                        prefixIcon: Icon(Icons.arrow_downward),
                        suffixText: 'm',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _minDepth = double.tryParse(value);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _maxDepthController,
                      decoration: const InputDecoration(
                        labelText: 'Max',
                        prefixIcon: Icon(Icons.arrow_downward),
                        suffixText: 'm',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _maxDepth = double.tryParse(value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Favorites Section
              SwitchListTile(
                title: const Text('Favorites Only'),
                subtitle: const Text('Show only favorite dives'),
                secondary: Icon(
                  Icons.favorite,
                  color: _favoritesOnly ? Colors.red : null,
                ),
                value: _favoritesOnly,
                onChanged: (value) {
                  setState(() => _favoritesOnly = value);
                },
              ),
              const SizedBox(height: 24),

              // Tags Section
              Text('Tags', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ref
                  .watch(tagListNotifierProvider)
                  .when(
                    data: (allTags) {
                      if (allTags.isEmpty) {
                        return const Text(
                          'No tags created yet',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        );
                      }
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: allTags.map((tag) {
                          final isSelected = _selectedTagIds.contains(tag.id);
                          return FilterChip(
                            label: Text(tag.name),
                            selected: isSelected,
                            selectedColor: tag.color.withValues(alpha: 0.3),
                            checkmarkColor: tag.color,
                            side: BorderSide(
                              color: isSelected
                                  ? tag.color
                                  : Colors.grey.shade300,
                            ),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedTagIds.add(tag.id);
                                } else {
                                  _selectedTagIds.remove(tag.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (_, _) => const Text('Error loading tags'),
                  ),
              const SizedBox(height: 24),

              // Buddy Name Filter Section
              Text('Buddy', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _buddyNameController,
                decoration: const InputDecoration(
                  labelText: 'Buddy Name',
                  hintText: 'Search by buddy name',
                  prefixIcon: Icon(Icons.person),
                ),
                onChanged: (value) {
                  _buddyNameFilter = value.isEmpty ? null : value;
                },
              ),
              const SizedBox(height: 24),

              // Gas Mix (O2%) Filter Section
              Text(
                'Gas Mix (O₂%)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _minO2Percent == null && _maxO2Percent == null,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _minO2Percent = null;
                          _maxO2Percent = null;
                        });
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Air (21%)'),
                    selected: _minO2Percent == 20 && _maxO2Percent == 22,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _minO2Percent = 20;
                          _maxO2Percent = 22;
                        });
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Nitrox (>21%)'),
                    selected: _minO2Percent == 22 && _maxO2Percent == null,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _minO2Percent = 22;
                          _maxO2Percent = null;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Rating Filter Section
              Text(
                'Minimum Rating',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (index) {
                  final rating = index + 1;
                  final isSelected =
                      _minRating != null && rating <= _minRating!;
                  return IconButton(
                    icon: Icon(
                      isSelected ? Icons.star : Icons.star_border,
                      color: isSelected ? Colors.amber : null,
                      size: 32,
                    ),
                    tooltip: '$rating star${rating > 1 ? 's' : ''}',
                    onPressed: () {
                      setState(() {
                        if (_minRating == rating) {
                          _minRating = null; // Tap same star to clear
                        } else {
                          _minRating = rating;
                        }
                      });
                    },
                  );
                }),
              ),
              if (_minRating != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () => setState(() => _minRating = null),
                    child: const Text('Clear rating filter'),
                  ),
                ),
              const SizedBox(height: 24),

              // Duration Range Filter Section
              Text(
                'Duration (minutes)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minDurationController,
                      decoration: const InputDecoration(
                        labelText: 'Min',
                        prefixIcon: Icon(Icons.timer),
                        suffixText: 'min',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _minDurationMinutes = int.tryParse(value);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _maxDurationController,
                      decoration: const InputDecoration(
                        labelText: 'Max',
                        prefixIcon: Icon(Icons.timer),
                        suffixText: 'min',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _maxDurationMinutes = int.tryParse(value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        widget.ref.read(diveFilterProvider.notifier).state =
                            const DiveFilterState();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Clear All'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _applyFilters,
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectDate(
    BuildContext context, {
    required bool isStart,
  }) async {
    final initialDate = isStart ? _startDate : _endDate;
    final firstDate = DateTime(2000);
    final lastDate = DateTime.now().add(const Duration(days: 365));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _applyFilters() {
    widget.ref.read(diveFilterProvider.notifier).state = DiveFilterState(
      startDate: _startDate,
      endDate: _endDate,
      diveTypeId: _diveTypeId,
      siteId: _siteId,
      minDepth: _minDepth,
      maxDepth: _maxDepth,
      favoritesOnly: _favoritesOnly ? true : null,
      tagIds: _selectedTagIds,
      // v1.5 filters
      buddyNameFilter: _buddyNameFilter,
      minO2Percent: _minO2Percent,
      maxO2Percent: _maxO2Percent,
      minRating: _minRating,
      minDurationMinutes: _minDurationMinutes,
      maxDurationMinutes: _maxDurationMinutes,
    );
    Navigator.of(context).pop();
  }
}
