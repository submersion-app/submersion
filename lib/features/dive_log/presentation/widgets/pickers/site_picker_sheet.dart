import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/core/text/fuzzy_match.dart';
import 'package:submersion/features/dive_log/presentation/utils/site_picker_search.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/similar_value_hint.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Site picker bottom sheet with nearby site suggestions
class SitePickerSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final String? selectedSiteId;
  final LocationResult? currentLocation;
  final void Function(DiveSite) onSiteSelected;
  final VoidCallback onCreateNewSite;

  const SitePickerSheet({
    super.key,
    required this.scrollController,
    required this.selectedSiteId,
    this.currentLocation,
    required this.onSiteSelected,
    required this.onCreateNewSite,
  });

  @override
  ConsumerState<SitePickerSheet> createState() => _SitePickerSheetState();
}

class _SitePickerSheetState extends ConsumerState<SitePickerSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Calculate distance from current location to a site in km
  double? _distanceToSite(DiveSite site) {
    if (widget.currentLocation == null || site.location == null) return null;
    final distanceMeters = LocationService.instance.distanceBetween(
      widget.currentLocation!.latitude,
      widget.currentLocation!.longitude,
      site.location!.latitude,
      site.location!.longitude,
    );
    return distanceMeters / 1000; // Convert to km
  }

  /// Format distance for display
  String _formatDistance(BuildContext context, double km) {
    if (km < 1) {
      return context.l10n.diveLog_sitePicker_distanceMeters(
        (km * 1000).round().toString(),
      );
    }
    final text = km < 10 ? km.toStringAsFixed(1) : km.round().toString();
    return context.l10n.diveLog_sitePicker_distanceKm(text);
  }

  @override
  Widget build(BuildContext context) {
    final sitesAsync = ref.watch(sitesProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final normalizedQuery = _searchQuery.trim().toLowerCase();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.diveLog_sitePicker_title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (widget.currentLocation != null)
                    Row(
                      children: [
                        Icon(
                          Icons.my_location,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.l10n.diveLog_sitePicker_sortedByDistance,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.primary),
                        ),
                      ],
                    ),
                ],
              ),
              TextButton.icon(
                onPressed: widget.onCreateNewSite,
                icon: const Icon(Icons.add),
                label: Text(context.l10n.diveLog_sitePicker_newDiveSite),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: context.l10n.diveSites_list_search_placeholder,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: normalizedQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip:
                          context.l10n.diveLog_listPage_tooltip_clearSearch,
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        if (_searchQuery.trim().isNotEmpty)
          Builder(
            builder: (context) {
              final sites = sitesAsync.value ?? const <DiveSite>[];
              final hidden = sites
                  .where((s) => !siteMatchesPickerQuery(s, normalizedQuery))
                  .toList();
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
            data: (sites) {
              if (sites.isEmpty) {
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
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: widget.onCreateNewSite,
                        icon: const Icon(Icons.add),
                        label: Text(
                          context.l10n.diveLog_sitePicker_addDiveSite,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Sort sites by distance if we have current location
              List<_SiteWithDistance> sortedSites;
              if (widget.currentLocation != null) {
                sortedSites = sites.map((site) {
                  return _SiteWithDistance(site, _distanceToSite(site));
                }).toList();
                // Sort: sites with distance first (by distance), then sites without GPS
                sortedSites.sort((a, b) {
                  if (a.distance == null && b.distance == null) return 0;
                  if (a.distance == null) return 1;
                  if (b.distance == null) return -1;
                  return a.distance!.compareTo(b.distance!);
                });
              } else {
                sortedSites = sites
                    .map((site) => _SiteWithDistance(site, null))
                    .toList();
              }

              final visibleSites = normalizedQuery.isEmpty
                  ? sortedSites
                  : sortedSites.where((siteWithDistance) {
                      return siteMatchesPickerQuery(
                        siteWithDistance.site,
                        normalizedQuery,
                      );
                    }).toList();

              if (visibleSites.isEmpty) {
                return Center(
                  child: Text(
                    context.l10n.diveSites_list_search_noResults(
                      _searchQuery.trim(),
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.builder(
                controller: widget.scrollController,
                itemCount: visibleSites.length,
                itemBuilder: (context, index) {
                  final siteWithDist = visibleSites[index];
                  final site = siteWithDist.site;
                  final distance = siteWithDist.distance;
                  final isSelected = site.id == widget.selectedSiteId;
                  final isNearby =
                      distance != null && distance < 50; // Within 50km

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? colorScheme.primaryContainer
                          : isNearby
                          ? colorScheme.tertiaryContainer
                          : colorScheme.surfaceContainerHighest,
                      child: Icon(
                        isNearby ? Icons.near_me : Icons.location_on,
                        color: isSelected
                            ? colorScheme.onPrimaryContainer
                            : isNearby
                            ? colorScheme.onTertiaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(site.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (site.locationString.isNotEmpty)
                          Text(site.locationString),
                        if (distance != null)
                          Text(
                            _formatDistance(context, distance),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isNearby
                                      ? colorScheme.tertiary
                                      : colorScheme.onSurfaceVariant,
                                  fontWeight: isNearby ? FontWeight.w600 : null,
                                ),
                          ),
                      ],
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: colorScheme.primary)
                        : null,
                    onTap: () => widget.onSiteSelected(site),
                  );
                },
              );
            },
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
}

/// Helper class to hold a site with its calculated distance
class _SiteWithDistance {
  final DiveSite site;
  final double? distance;

  _SiteWithDistance(this.site, this.distance);
}
