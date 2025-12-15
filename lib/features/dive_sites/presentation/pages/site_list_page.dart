import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/site_repository_impl.dart';
import '../../domain/entities/dive_site.dart';
import '../providers/site_providers.dart';

class SiteListPage extends ConsumerWidget {
  const SiteListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sitesAsync = ref.watch(sitesWithCountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dive Sites'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: SiteSearchDelegate(ref),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: 'Map View',
            onPressed: () => context.push('/sites/map'),
          ),
        ],
      ),
      body: sitesAsync.when(
        data: (sites) => sites.isEmpty
            ? _buildEmptyState(context)
            : _buildSiteList(context, ref, sites),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading sites: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(sitesWithCountsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/sites/new'),
        icon: const Icon(Icons.add_location),
        label: const Text('Add Site'),
      ),
    );
  }

  Widget _buildSiteList(BuildContext context, WidgetRef ref, List<SiteWithDiveCount> sites) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sitesWithCountsProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: sites.length,
        itemBuilder: (context, index) {
          final siteData = sites[index];
          final site = siteData.site;
          return SiteListTile(
            name: site.name,
            location: site.locationString.isNotEmpty ? site.locationString : null,
            maxDepth: site.maxDepth,
            diveCount: siteData.diveCount,
            rating: site.rating,
            onTap: () => context.push('/sites/${site.id}'),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_on,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No dive sites yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Add dive sites to track your favorite locations',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/sites/new'),
            icon: const Icon(Icons.add_location),
            label: const Text('Add Your First Site'),
          ),
        ],
      ),
    );
  }
}

/// Search delegate for dive sites
class SiteSearchDelegate extends SearchDelegate<DiveSite?> {
  final WidgetRef ref;

  SiteSearchDelegate(this.ref);

  @override
  String get searchFieldLabel => 'Search sites...';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
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
            Icon(
              Icons.search,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Search by site name, country, or region',
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
    final searchAsync = ref.watch(siteSearchProvider(query));

    return searchAsync.when(
      data: (sites) {
        if (sites.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No sites found for "$query"',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: sites.length,
          itemBuilder: (context, index) {
            final site = sites[index];
            return SiteListTile(
              name: site.name,
              location: site.locationString.isNotEmpty ? site.locationString : null,
              maxDepth: site.maxDepth,
              rating: site.rating,
              onTap: () {
                close(context, site);
                context.push('/sites/${site.id}');
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('Error: $error'),
      ),
    );
  }
}

/// List item widget for displaying a dive site summary
class SiteListTile extends StatelessWidget {
  final String name;
  final String? location;
  final double? maxDepth;
  final int diveCount;
  final double? rating;
  final VoidCallback? onTap;

  const SiteListTile({
    super.key,
    required this.name,
    this.location,
    this.maxDepth,
    this.diveCount = 0,
    this.rating,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(
            Icons.location_on,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(name),
        subtitle: location != null ? Text(location!) : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (diveCount > 0)
              Text(
                '$diveCount dives',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (rating != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  Text(rating!.toStringAsFixed(1)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
