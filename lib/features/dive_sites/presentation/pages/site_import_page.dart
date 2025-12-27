import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/dive_site_api_service.dart';
import '../providers/site_providers.dart';

/// Page for searching and importing dive sites from online sources.
class SiteImportPage extends ConsumerStatefulWidget {
  const SiteImportPage({super.key});

  @override
  ConsumerState<SiteImportPage> createState() => _SiteImportPageState();
}

class _SiteImportPageState extends ConsumerState<SiteImportPage> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final Set<String> _importedIds = {};

  @override
  void initState() {
    super.initState();
    // Auto-focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      ref.read(externalSiteSearchProvider.notifier).search(query);
    }
  }

  Future<void> _importSite(ExternalDiveSite site) async {
    final notifier = ref.read(externalSiteSearchProvider.notifier);
    final importedSite = await notifier.importSite(site);

    if (!mounted) return;

    if (importedSite != null) {
      setState(() {
        _importedIds.add(site.externalId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported "${site.name}"'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              context.push('/sites/${importedSite.id}');
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to import site'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(externalSiteSearchProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Dive Site'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Search dive sites (e.g., "Blue Hole", "Thailand")',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchState.isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(externalSiteSearchProvider.notifier)
                                  .clear();
                            },
                          )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _onSearch(),
            ),
          ),

          // Quick search chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _QuickSearchChip(
                    label: 'Caribbean',
                    onTap: () {
                      _searchController.text = 'Caribbean';
                      _onSearch();
                    },
                  ),
                  _QuickSearchChip(
                    label: 'Red Sea',
                    onTap: () {
                      _searchController.text = 'Red Sea';
                      _onSearch();
                    },
                  ),
                  _QuickSearchChip(
                    label: 'Thailand',
                    onTap: () {
                      _searchController.text = 'Thailand';
                      _onSearch();
                    },
                  ),
                  _QuickSearchChip(
                    label: 'Indonesia',
                    onTap: () {
                      _searchController.text = 'Indonesia';
                      _onSearch();
                    },
                  ),
                  _QuickSearchChip(
                    label: 'Maldives',
                    onTap: () {
                      _searchController.text = 'Maldives';
                      _onSearch();
                    },
                  ),
                  _QuickSearchChip(
                    label: 'Philippines',
                    onTap: () {
                      _searchController.text = 'Philippines';
                      _onSearch();
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Results or placeholder
          Expanded(
            child: _buildContent(searchState, theme, colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    ExternalSiteSearchState state,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    // Error state
    if (state.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Search Error',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                state.errorMessage ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _onSearch,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Loading state
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Empty state (no search yet)
    if (state.query.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.travel_explore,
                size: 80,
                color: colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              Text(
                'Search Dive Sites',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Search for dive sites from our database of popular\n'
                'dive destinations around the world.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Try searching by site name, country, or region.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // No results
    if (!state.hasResults) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No Results',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'No dive sites found for "${state.query}".\n'
                'Try a different search term.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Results list
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: state.sites.length,
      itemBuilder: (context, index) {
        final site = state.sites[index];
        final isImported = _importedIds.contains(site.externalId);

        return _DiveSiteCard(
          site: site,
          isImported: isImported,
          onImport: () => _importSite(site),
        );
      },
    );
  }
}

class _QuickSearchChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickSearchChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        onPressed: onTap,
      ),
    );
  }
}

class _DiveSiteCard extends StatelessWidget {
  final ExternalDiveSite site;
  final bool isImported;
  final VoidCallback onImport;

  const _DiveSiteCard({
    required this.site,
    required this.isImported,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showDetails(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.scuba_diving,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Site info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          site.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _buildLocationText(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Import button
                  if (isImported)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Imported',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    FilledButton.tonal(
                      onPressed: onImport,
                      child: const Text('Import'),
                    ),
                ],
              ),

              // Features
              if (site.features.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: site.features.take(4).map((feature) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        feature,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              // Depth and coordinates
              if (site.maxDepth != null || site.hasCoordinates) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (site.maxDepth != null) ...[
                      Icon(
                        Icons.arrow_downward,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${site.maxDepth!.toStringAsFixed(0)}m',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    if (site.hasCoordinates) ...[
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'GPS',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _buildLocationText() {
    final parts = <String>[];
    if (site.region != null && site.region!.isNotEmpty) {
      parts.add(site.region!);
    }
    if (site.country != null && site.country!.isNotEmpty) {
      parts.add(site.country!);
    }
    if (site.ocean != null &&
        site.ocean!.isNotEmpty &&
        !parts.contains(site.ocean)) {
      parts.add(site.ocean!);
    }
    return parts.isNotEmpty ? parts.join(', ') : 'Location unknown';
  }

  void _showDetails(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    site.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _buildLocationText(),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  if (site.description != null &&
                      site.description!.isNotEmpty) ...[
                    Text(
                      site.description!,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Info chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (site.maxDepth != null)
                        Chip(
                          avatar: const Icon(Icons.arrow_downward, size: 18),
                          label: Text('Max ${site.maxDepth!.toStringAsFixed(0)}m'),
                        ),
                      if (site.hasCoordinates)
                        Chip(
                          avatar: const Icon(Icons.location_on, size: 18),
                          label: Text(
                            '${site.latitude!.toStringAsFixed(4)}, '
                            '${site.longitude!.toStringAsFixed(4)}',
                          ),
                        ),
                      ...site.features.map(
                        (f) => Chip(label: Text(f)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Source
                  Text(
                    'Source: ${site.source}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Import button
                  if (!isImported)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onImport();
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Import to My Sites'),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: null,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            const Text('Already Imported'),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
