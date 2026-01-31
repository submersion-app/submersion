import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/data/services/dive_center_api_service.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';

/// Page for searching and importing dive centers from online sources.
class DiveCenterImportPage extends ConsumerStatefulWidget {
  const DiveCenterImportPage({super.key});

  @override
  ConsumerState<DiveCenterImportPage> createState() =>
      _DiveCenterImportPageState();
}

class _DiveCenterImportPageState extends ConsumerState<DiveCenterImportPage> {
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
      ref.read(externalCenterSearchProvider.notifier).search(query);
    }
  }

  Future<void> _importCenter(ExternalDiveCenter center) async {
    final notifier = ref.read(externalCenterSearchProvider.notifier);
    final importedCenter = await notifier.importCenter(center);

    if (!mounted) return;

    if (importedCenter != null) {
      setState(() {
        _importedIds.add(center.externalId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported "${center.name}"'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              context.push('/centers/${importedCenter.id}');
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to import dive center'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(externalCenterSearchProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Import Dive Center')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Search dive centers (e.g., "PADI", "Thailand")',
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
                              .read(externalCenterSearchProvider.notifier)
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
                    label: 'PADI',
                    onTap: () {
                      _searchController.text = 'PADI';
                      _onSearch();
                    },
                  ),
                  _QuickSearchChip(
                    label: 'SSI',
                    onTap: () {
                      _searchController.text = 'SSI';
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
                    label: 'Egypt',
                    onTap: () {
                      _searchController.text = 'Egypt';
                      _onSearch();
                    },
                  ),
                  _QuickSearchChip(
                    label: 'Mexico',
                    onTap: () {
                      _searchController.text = 'Mexico';
                      _onSearch();
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Results or placeholder
          Expanded(child: _buildContent(searchState, theme, colorScheme)),
        ],
      ),
    );
  }

  Widget _buildContent(
    ExternalCenterSearchState state,
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
              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              Text('Search Error', style: theme.textTheme.titleLarge),
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
      return const Center(child: CircularProgressIndicator());
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
                Icons.store,
                size: 80,
                color: colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              Text('Search Dive Centers', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Search for dive centers, shops, and clubs from our\n'
                'database of operators around the world.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Try searching by name, country, or certification agency.',
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
              Text('No Results', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'No dive centers found for "${state.query}".\n'
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

    // Results list with local centers first, then external centers
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Local centers section (from user's database)
        if (state.hasLocalResults) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Row(
              children: [
                Icon(Icons.folder, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'My Centers (${state.localCenters.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          ...state.localCenters.map(
            (center) => _LocalCenterCard(center: center),
          ),
          const SizedBox(height: 16),
        ],

        // External centers section (from bundled database)
        if (state.hasExternalResults) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Row(
              children: [
                Icon(Icons.public, size: 20, color: colorScheme.secondary),
                const SizedBox(width: 8),
                Text(
                  'Import from Database (${state.centers.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
          ...state.centers.map((center) {
            final isImported = _importedIds.contains(center.externalId);
            return _DiveCenterCard(
              center: center,
              isImported: isImported,
              onImport: () => _importCenter(center),
            );
          }),
        ],
      ],
    );
  }
}

class _QuickSearchChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickSearchChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(label: Text(label), onPressed: onTap),
    );
  }
}

/// Card for displaying a local center from the user's database.
class _LocalCenterCard extends StatelessWidget {
  final DiveCenter center;

  const _LocalCenterCard({required this.center});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: InkWell(
        onTap: () => context.push('/centers/${center.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.store, color: colorScheme.onPrimary),
              ),
              const SizedBox(width: 12),

              // Center info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      center.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      center.fullLocationString ?? 'Location not set',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (center.affiliations.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: center.affiliations.take(3).map((aff) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              aff,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),

              // Already saved indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, size: 16, color: colorScheme.onPrimary),
                    const SizedBox(width: 4),
                    Text(
                      'Saved',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiveCenterCard extends StatelessWidget {
  final ExternalDiveCenter center;
  final bool isImported;
  final VoidCallback onImport;

  const _DiveCenterCard({
    required this.center,
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
                  // Icon based on type
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _iconForType(center.type),
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Center info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          center.name,
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

              // Affiliations and type
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  // Type chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      center.typeDisplay,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                  // Affiliation chips
                  ...center.affiliations.take(4).map((aff) {
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
                        aff,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }),
                ],
              ),

              // Coordinates indicator
              if (center.hasCoordinates) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
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
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'shop':
        return Icons.shopping_bag;
      case 'club':
        return Icons.groups;
      default:
        return Icons.store;
    }
  }

  String _buildLocationText() {
    final parts = <String>[];
    if (center.location != null && center.location!.isNotEmpty) {
      parts.add(center.location!);
    }
    if (center.country != null && center.country!.isNotEmpty) {
      parts.add(center.country!);
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
                    center.name,
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

                  // Info chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: Icon(_iconForType(center.type), size: 18),
                        label: Text(center.typeDisplay),
                      ),
                      if (center.hasCoordinates)
                        Chip(
                          avatar: const Icon(Icons.location_on, size: 18),
                          label: Text(
                            '${center.latitude!.toStringAsFixed(4)}, '
                            '${center.longitude!.toStringAsFixed(4)}',
                          ),
                        ),
                      ...center.affiliations.map((a) => Chip(label: Text(a))),
                    ],
                  ),

                  // Contact info
                  if (center.phone != null ||
                      center.email != null ||
                      center.website != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Contact',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (center.phone != null)
                      ListTile(
                        leading: const Icon(Icons.phone),
                        title: Text(center.phone!),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    if (center.email != null)
                      ListTile(
                        leading: const Icon(Icons.email),
                        title: Text(center.email!),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    if (center.website != null)
                      ListTile(
                        leading: const Icon(Icons.language),
                        title: Text(center.website!),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],

                  const SizedBox(height: 16),

                  // Source
                  Text(
                    'Source: ${center.source}',
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
                        label: const Text('Import to My Centers'),
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
