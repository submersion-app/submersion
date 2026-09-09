import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Summary widget shown when no site is selected.
class SiteSummaryWidget extends ConsumerWidget {
  const SiteSummaryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sitesAsync = ref.watch(sitesWithCountsProvider);
    final units = UnitFormatter(ref.watch(settingsProvider));

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            sitesAsync.when(
              data: (sites) => _buildOverview(context, sites, units),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('${context.l10n.common_label_error}: $e')),
            ),
            const SizedBox(height: 24),
            _buildQuickActions(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.location_on,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              context.l10n.diveSites_summary_header_title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.diveSites_summary_header_subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildOverview(
    BuildContext context,
    List<SiteWithDiveCount> sites,
    UnitFormatter units,
  ) {
    // Calculate stats
    int totalDives = 0;
    int sitesWithGps = 0;
    int ratedSites = 0;
    double totalRating = 0;
    final Map<String, int> countryCounts = {};

    for (final siteData in sites) {
      final site = siteData.site;
      totalDives += siteData.diveCount;
      if (site.hasCoordinates) sitesWithGps++;
      if (site.rating != null && site.rating! > 0) {
        ratedSites++;
        totalRating += site.rating!;
      }
      // Trim before testing and before keying, the same rule DiveSite's own
      // locationString applies: imported and synced rows carry whitespace-only
      // countries, and untrimmed keys would also split "Malta" from "Malta ".
      final country = site.country?.trim() ?? '';
      if (country.isNotEmpty) {
        countryCounts[country] = (countryCounts[country] ?? 0) + 1;
      }
    }

    final avgRating = ratedSites > 0 ? totalRating / ratedSites : 0.0;

    // Sort countries by count
    final sortedCountries = countryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final neverDived = sites.where((s) => s.diveCount == 0).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.diveSites_summary_section_overview,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard(
              context,
              icon: Icons.location_on,
              value: '${sites.length}',
              label: context.l10n.diveSites_summary_stat_totalSites,
              color: Colors.blue,
            ),
            _buildStatCard(
              context,
              icon: Icons.scuba_diving,
              value: '$totalDives',
              label: context.l10n.diveSites_summary_stat_totalDives,
              color: Colors.teal,
            ),
            _buildStatCard(
              context,
              icon: Icons.gps_fixed,
              value: '$sitesWithGps',
              label: context.l10n.diveSites_summary_stat_withGps,
              color: Colors.green,
            ),
            if (ratedSites > 0)
              _buildStatCard(
                context,
                icon: Icons.star,
                value: avgRating.toStringAsFixed(1),
                label: context.l10n.diveSites_summary_stat_avgRating,
                color: Colors.amber,
              ),
            _buildStatCard(
              context,
              icon: Icons.flag,
              value: '${countryCounts.length}',
              label: context.l10n.diveSites_summary_stat_countries,
              color: Colors.indigo,
            ),
            // The gap between sites saved and sites actually dived. Nothing
            // else in the app answers "what have I been meaning to dive?".
            if (neverDived > 0)
              _buildStatCard(
                context,
                icon: Icons.bookmark_border,
                value: '$neverDived',
                label: context.l10n.diveSites_summary_stat_notDived,
                color: Colors.deepOrange,
              ),
          ],
        ),
        if (sortedCountries.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildCountriesSection(context, sortedCountries),
        ],
        if (sites.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildTopSitesSection(context, sites, units),
        ],
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return SizedBox(
      width: 120,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountriesSection(
    BuildContext context,
    List<MapEntry<String, int>> countries,
  ) {
    final previewCountries = countries.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.flag,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n.diveSites_summary_section_countriesRegions,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: previewCountries.map((entry) {
            return Chip(
              avatar: const Icon(Icons.place, size: 16),
              label: Text('${entry.key} (${entry.value})'),
            );
          }).toList(),
        ),
        if (countries.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              context.l10n.diveSites_summary_countriesMore(
                countries.length - 5,
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  /// One row in the top-sites lists.
  ///
  /// [trailingText] is always the value its list ranks by, so the reader can
  /// see why a site placed where it did: the rating in Top Rated, the dive
  /// count in Most Dived, the date in Recently Dived.
  ///
  /// [secondaryFact] is the other figure, shown after the location on the
  /// second line. It is passed in rather than fixed because whichever figure
  /// a list ranks by is already the trailing value, and printing it twice in
  /// one row reads as a mistake.
  Widget _buildSiteTile(
    BuildContext context,
    SiteWithDiveCount siteData, {
    required IconData icon,
    required String trailingText,
    required String secondaryFact,
    Color? iconColor,
  }) {
    final site = siteData.site;
    final colorScheme = Theme.of(context).colorScheme;
    final details = <String>[
      if (site.locationString.isNotEmpty) site.locationString,
      secondaryFact,
    ];

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: (iconColor ?? colorScheme.primary).withValues(
          alpha: 0.15,
        ),
        child: Icon(icon, color: iconColor ?? colorScheme.primary),
      ),
      title: Text(site.name),
      subtitle: Text(details.join(' - ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(trailingText),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () {
        final state = GoRouterState.of(context);
        final currentPath = state.uri.path;
        context.go('$currentPath?selected=${site.id}');
      },
    );
  }

  Widget _buildTopSitesSection(
    BuildContext context,
    List<SiteWithDiveCount> sites,
    UnitFormatter units,
  ) {
    // Get top-rated sites
    final ratedSites =
        sites.where((s) => s.site.rating != null && s.site.rating! > 0).toList()
          ..sort((a, b) => (b.site.rating ?? 0).compareTo(a.site.rating ?? 0));
    final topRated = ratedSites.take(3).toList();

    // Get most dived sites
    final mostDived = sites.toList()
      ..sort((a, b) => b.diveCount.compareTo(a.diveCount));
    final topDived = mostDived.where((s) => s.diveCount > 0).take(3).toList();

    // Get most recently dived sites. A site with no dives has no date to rank
    // by and is excluded rather than sorted to one end.
    final recentlyDived = sites.where((s) => s.lastDivedAt != null).toList()
      ..sort((a, b) => b.lastDivedAt!.compareTo(a.lastDivedAt!));
    final topRecent = recentlyDived.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (topRated.isNotEmpty) ...[
          Text(
            context.l10n.diveSites_summary_section_topRated,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Card(
            key: const ValueKey('summaryTopRatedList'),
            child: Column(
              children: topRated
                  .map(
                    (siteData) => _buildSiteTile(
                      context,
                      siteData,
                      icon: Icons.star,
                      iconColor: Colors.amber,
                      trailingText: siteData.site.rating!.toStringAsFixed(1),
                      secondaryFact: context.l10n.diveSites_list_tile_diveCount(
                        siteData.diveCount,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (topRecent.isNotEmpty) ...[
          Text(
            context.l10n.diveSites_summary_section_recentlyDived,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Card(
            key: const ValueKey('summaryRecentlyDivedList'),
            child: Column(
              children: topRecent
                  .map(
                    (siteData) => _buildSiteTile(
                      context,
                      siteData,
                      icon: Icons.history,
                      trailingText: units.formatDate(siteData.lastDivedAt),
                      secondaryFact: context.l10n.diveSites_list_tile_diveCount(
                        siteData.diveCount,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (topDived.isNotEmpty) ...[
          Text(
            context.l10n.diveSites_summary_section_mostDived,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Card(
            key: const ValueKey('summaryMostDivedList'),
            child: Column(
              children: topDived
                  .map(
                    (siteData) => _buildSiteTile(
                      context,
                      siteData,
                      icon: Icons.scuba_diving,
                      trailingText: context.l10n.diveSites_list_tile_diveCount(
                        siteData.diveCount,
                      ),
                      secondaryFact: context.l10n
                          .diveSites_summary_tile_lastDived(
                            units.formatDate(siteData.lastDivedAt),
                          ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.diveSites_summary_section_quickActions,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () {
                final state = GoRouterState.of(context);
                final currentPath = state.uri.path;
                context.go('$currentPath?mode=new');
              },
              icon: const Icon(Icons.add_location),
              label: Text(context.l10n.diveSites_summary_action_addSite),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/sites/map'),
              icon: const Icon(Icons.map),
              label: Text(context.l10n.diveSites_summary_action_viewMap),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/sites/import'),
              icon: const Icon(Icons.travel_explore),
              label: Text(context.l10n.diveSites_summary_action_import),
            ),
          ],
        ),
      ],
    );
  }
}
