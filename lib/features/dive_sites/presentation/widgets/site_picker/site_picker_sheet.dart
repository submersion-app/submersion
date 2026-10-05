import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/core/text/fuzzy_match.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/utils/site_grouping.dart';
import 'package:submersion/features/dive_sites/domain/utils/site_search.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/similar_value_hint.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/grouped_site_list_view.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_site_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Identifies the picker's scrolling list, for tests.
const sitePickerListKey = Key('site-picker-list');

/// Sites closer than this to the dive (or the device) are listed under
/// Nearby, in meters.
const _nearbyRadiusMeters = 50000.0;

/// What the site picker resolved to. Dismissing the sheet resolves to null.
sealed class SitePickerResult {
  const SitePickerResult();
}

/// The diver picked [site].
final class SitePicked extends SitePickerResult {
  const SitePicked(this.site);

  final DiveSite site;
}

/// The diver chose "All sites" (filter use only).
final class SitePickerCleared extends SitePickerResult {
  const SitePickerCleared();
}

/// The diver tapped "New Dive Site".
final class SitePickerCreateRequested extends SitePickerResult {
  const SitePickerCreateRequested();
}

/// Opens [SitePickerSheet] in a draggable bottom sheet.
///
/// [allowCreate] adds the "New Dive Site" button, [allowClear] the leading
/// "All sites" row a filter needs. [useDeviceLocation] lets the sheet ask for
/// a GPS fix when the caller gave no location; a filter or a media review
/// passes false so opening it never prompts for location.
Future<SitePickerResult?> showSitePicker(
  BuildContext context, {
  String? selectedSiteId,
  LocationResult? currentLocation,
  GeoPoint? diveLocation,
  bool allowCreate = false,
  bool allowClear = false,
  bool useDeviceLocation = true,
}) {
  return showModalBottomSheet<SitePickerResult>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (sheetContext, scrollController) => SitePickerSheet(
        scrollController: scrollController,
        selectedSiteId: selectedSiteId,
        currentLocation: currentLocation,
        diveLocation: diveLocation,
        useDeviceLocation: useDeviceLocation,
        onSiteSelected: (site) =>
            Navigator.of(sheetContext).pop(SitePicked(site)),
        onCreateNewSite: allowCreate
            ? () => Navigator.of(
                sheetContext,
              ).pop(const SitePickerCreateRequested())
            : null,
        onClear: allowClear
            ? () => Navigator.of(sheetContext).pop(const SitePickerCleared())
            : null,
      ),
    ),
  );
}

/// Opens the site picker and, on "New Dive Site", pushes the new-site form
/// seeded with [newSiteSeedLocation] and resolves once the site is saved.
///
/// Returns the picked or newly created [DiveSite], or null if the sheet was
/// dismissed or the new-site form was cancelled.
///
/// With [allowCreate] false the sheet offers no "New Dive Site" button, for
/// callers that cannot open the new-site form mid-flow.
Future<DiveSite?> pickOrCreateSite(
  BuildContext context,
  WidgetRef ref, {
  required String? selectedSiteId,
  LocationResult? currentLocation,
  GeoPoint? diveLocation,
  GeoPoint? newSiteSeedLocation,
  bool allowCreate = true,
}) async {
  final result = await showSitePicker(
    context,
    selectedSiteId: selectedSiteId,
    currentLocation: currentLocation,
    diveLocation: diveLocation,
    allowCreate: allowCreate,
  );
  switch (result) {
    case SitePicked(:final site):
      return site;
    case SitePickerCreateRequested():
      if (!context.mounted) return null;
      final newSiteId = await context.push<String>(
        '/sites/new',
        extra: newSiteSeedLocation,
      );
      if (newSiteId == null || !context.mounted) return null;
      return ref.read(siteProvider(newSiteId).future);
    case SitePickerCleared() || null:
      return null;
  }
}

/// The site picker: a search field over every location field, a Nearby
/// section when a location is known, and the sites grouped by country and
/// region in collapsible sections (#1080).
class SitePickerSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final String? selectedSiteId;
  final LocationResult? currentLocation;
  final GeoPoint? diveLocation;
  final void Function(DiveSite) onSiteSelected;

  /// Shows the "New Dive Site" button when set.
  final VoidCallback? onCreateNewSite;

  /// Shows a leading "All sites" row when set, for filters.
  final VoidCallback? onClear;

  /// Whether the sheet may ask for a device fix when the caller supplied
  /// neither a dive nor a device location.
  final bool useDeviceLocation;

  const SitePickerSheet({
    super.key,
    required this.scrollController,
    required this.selectedSiteId,
    this.currentLocation,
    this.diveLocation,
    required this.onSiteSelected,
    this.onCreateNewSite,
    this.onClear,
    this.useDeviceLocation = true,
  });

  @override
  ConsumerState<SitePickerSheet> createState() => _SitePickerSheetState();
}

class _SitePickerSheetState extends ConsumerState<SitePickerSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  /// Device fix resolved by the sheet itself, used only when the caller
  /// supplied neither a dive nor a device location.
  LocationResult? _deviceLocation;
  bool _isLocating = false;

  /// Countries the diver opened or closed by hand; null until the first
  /// build with data, which seeds it from [initialExpandedCountries].
  Set<String>? _manualExpanded;

  /// Countries the diver closed while the current query is active. Cleared
  /// whenever the query changes, since a new query opens every match again.
  Set<String> _searchCollapsed = const {};

  /// Each site's normalized search text, rebuilt only when the site list
  /// itself changes, so a keystroke costs one substring test per site.
  List<DiveSite>? _indexedSites;
  Map<String, String> _searchIndex = const {};

  @override
  void initState() {
    super.initState();
    // Callers that already know where the dive is (or where the device is)
    // cost nothing here. The rest (editing an imported dive, bulk edit)
    // would otherwise get no Nearby section at all (#965).
    if (widget.useDeviceLocation &&
        widget.diveLocation == null &&
        widget.currentLocation == null) {
      unawaited(_resolveDeviceLocation());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Resolve a device fix in the background. Runs once, from [initState]:
  /// `build` re-runs on every keystroke in the search field, so resolving
  /// there would fire a GPS request per character.
  Future<void> _resolveDeviceLocation() async {
    setState(() => _isLocating = true);
    try {
      final location = await ref
          .read(locationServiceProvider)
          .getCurrentLocation(
            // Coordinates are all the distance sort needs; skip geocoding.
            includeGeocoding: false,
            timeout: const Duration(seconds: 10),
          );
      if (mounted && location != null) {
        setState(() => _deviceLocation = location);
      }
    } catch (_) {
      // Proximity sorting is a convenience; the list stays usable without it.
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  /// The point distances are measured from: the dive's GPS if present, then a
  /// device location supplied by the caller, then one this sheet resolved.
  GeoPoint? get _anchor {
    if (widget.diveLocation != null) return widget.diveLocation;
    final cl = widget.currentLocation ?? _deviceLocation;
    return cl == null ? null : GeoPoint(cl.latitude, cl.longitude);
  }

  /// Distance from the resolved anchor to a site, in meters.
  double? _distanceToSite(DiveSite site) {
    final anchor = _anchor;
    if (anchor == null || site.location == null) return null;
    return distanceMeters(anchor, site.location!);
  }

  /// Format a site distance (meters) for display, unit-aware.
  String _formatDistance(BuildContext context, UnitFormatter units, double m) {
    return context.l10n.diveLog_sitePicker_distanceAway(
      units.formatGeoDistance(m),
    );
  }

  Map<String, String> _searchIndexFor(List<DiveSite> sites) {
    if (!identical(sites, _indexedSites)) {
      _indexedSites = sites;
      _searchIndex = {
        for (final site in sites) site.id: normalizedSiteSearchText(site),
      };
    }
    return _searchIndex;
  }

  void _onQueryChanged(String value) => setState(() {
    _searchQuery = value;
    _searchCollapsed = const {};
  });

  void _toggleCountry(String key, {required bool searching}) {
    setState(() {
      if (searching) {
        _searchCollapsed = _searchCollapsed.contains(key)
            ? (_searchCollapsed.toSet()..remove(key))
            : {..._searchCollapsed, key};
      } else {
        final current = _manualExpanded ?? const <String>{};
        _manualExpanded = current.contains(key)
            ? (current.toSet()..remove(key))
            : {...current, key};
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sitesAsync = ref.watch(sitesProvider);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final colorScheme = Theme.of(context).colorScheme;
    final query = SiteQuery(_searchQuery);
    // Only the Nearby section is ordered by distance, so the caption that
    // says so shows only when that section has sites in it.
    final hasNearby = (sitesAsync.value ?? const <DiveSite>[]).any(
      (site) =>
          (_distanceToSite(site) ?? double.infinity) < _nearbyRadiusMeters,
    );

    return Column(
      children: [
        _buildHeader(context, colorScheme, hasNearby: hasNearby),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: context.l10n.diveSites_list_search_placeholder,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip:
                          context.l10n.diveLog_listPage_tooltip_clearSearch,
                      onPressed: () {
                        _searchController.clear();
                        _onQueryChanged('');
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: _onQueryChanged,
          ),
        ),
        if (!query.isEmpty)
          Builder(
            builder: (context) {
              final sites = sitesAsync.value ?? const <DiveSite>[];
              final hidden = sites.where((s) => !query.matchesSite(s)).toList();
              final match = findSimilar(
                _searchQuery,
                hidden.map((s) => s.name),
              );
              if (match == null) return const SizedBox.shrink();
              final site = hidden.firstWhere((s) => s.name == match);
              return SimilarValueHint(
                query: _searchQuery,
                candidates: [match],
                onAccept: (_) => widget.onSiteSelected(site),
              );
            },
          ),
        const Divider(height: 1),
        Expanded(
          child: sitesAsync.when(
            data: (sites) => sites.isEmpty
                ? _buildEmptyState(context, colorScheme)
                : _buildList(context, sites, query, units, colorScheme),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                context.l10n.diveLog_sitePicker_errorLoading(error.toString()),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme colorScheme, {
    required bool hasNearby,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.diveLog_sitePicker_title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (hasNearby)
                  Row(
                    children: [
                      Icon(
                        widget.diveLocation != null
                            ? Icons.place
                            : Icons.my_location,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          widget.diveLocation != null
                              ? context
                                    .l10n
                                    .diveLog_sitePicker_sortedByDiveDistance
                              : context
                                    .l10n
                                    .diveLog_sitePicker_sortedByDistance,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.primary),
                        ),
                      ),
                    ],
                  )
                else if (_isLocating)
                  Row(
                    children: [
                      // Deliberately a static icon, not a spinner: an
                      // indeterminate indicator schedules frames forever,
                      // so it hangs pumpAndSettle in every consumer test
                      // that opens this sheet. Reusing the resolved-state
                      // icon also avoids a swap when the fix lands.
                      Icon(
                        Icons.my_location,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          context.l10n.diveLog_edit_gettingLocation,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (widget.onCreateNewSite != null)
            TextButton.icon(
              onPressed: widget.onCreateNewSite,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.diveLog_sitePicker_newDiveSite),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off,
            size: 48,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.diveLog_sitePicker_noSites,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (widget.onCreateNewSite != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: widget.onCreateNewSite,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.diveLog_sitePicker_addDiveSite),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<DiveSite> sites,
    SiteQuery query,
    UnitFormatter units,
    ColorScheme colorScheme,
  ) {
    final index = _searchIndexFor(sites);
    final searching = !query.isEmpty;
    final visible = searching
        ? sites.where((site) => query.matches(index[site.id]!)).toList()
        : sites;
    if (visible.isEmpty) {
      return Center(
        child: Text(
          context.l10n.diveSites_list_search_noResults(_searchQuery.trim()),
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    final groups = groupSitesByLocation(visible, (site) => site);
    final manual = _manualExpanded ??= initialExpandedCountries(
      searching ? groupSitesByLocation(sites, (site) => site) : groups,
      selected: sites
          .where((site) => site.id == widget.selectedSiteId)
          .firstOrNull,
    );
    final expanded = searching
        ? allCountryKeys(groups).difference(_searchCollapsed)
        : manual;

    final nearby = [
      for (final site in visible)
        if (_distanceToSite(site) case final distance?
            when distance < _nearbyRadiusMeters)
          (site: site, distance: distance),
    ]..sort((a, b) => a.distance.compareTo(b.distance));

    final rows = <Widget Function()>[
      if (widget.onClear != null)
        () => ListTile(
          leading: const CircleAvatar(child: Icon(Icons.public)),
          title: Text(context.l10n.diveLog_filter_allSites),
          trailing: widget.selectedSiteId == null
              ? Icon(Icons.check_circle, color: colorScheme.primary)
              : null,
          onTap: widget.onClear,
        ),
      if (nearby.isNotEmpty) ...[
        () => SiteSectionLabel(context.l10n.diveSites_picker_nearby),
        for (final entry in nearby)
          () => SitePickerSiteTile(
            site: entry.site,
            isSelected: entry.site.id == widget.selectedSiteId,
            isNearby: true,
            subtitle: entry.site.locationString.isEmpty
                ? null
                : entry.site.locationString,
            distanceText: _formatDistance(context, units, entry.distance),
            onTap: () => widget.onSiteSelected(entry.site),
          ),
      ],
      for (final row in flattenSiteGroups(groups, expanded: expanded))
        switch (row) {
          CountryHeaderRow(:final group, :final isExpanded) =>
            () => SiteCountryHeader(
              label: countryGroupLabel(context.l10n, group),
              siteCount: group.siteCount,
              isExpanded: isExpanded,
              onTap: () => _toggleCountry(group.key, searching: searching),
            ),
          RegionHeaderRow(:final label) => () => SiteSectionLabel(
            label,
            indent: 56,
          ),
          SiteRow(:final item) => () => SitePickerSiteTile(
            site: item,
            isSelected: item.id == widget.selectedSiteId,
            isNearby: false,
            subtitle: siteGroupedSubtitle(item),
            onTap: () => widget.onSiteSelected(item),
          ),
        },
    ];

    return ListView.builder(
      key: sitePickerListKey,
      controller: widget.scrollController,
      itemCount: rows.length,
      itemBuilder: (context, i) => rows[i](),
    );
  }
}
