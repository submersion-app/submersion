import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/domain/seen_species_filter.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/widgets/seen_species_tile.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_category_chips.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The species the diver has seen across every dive, searchable and sortable.
///
/// Reached at `/species` from the Statistics > Marine Life tab. Housekeeping
/// (edit, delete, reset the catalog) stays on the manager at
/// `/species/manage`, behind the app-bar action. Query, category and sort are
/// per-visit state, so they live here rather than in a provider.
class SpeciesPage extends ConsumerStatefulWidget {
  const SpeciesPage({super.key});

  @override
  ConsumerState<SpeciesPage> createState() => _SpeciesPageState();
}

class _SpeciesPageState extends ConsumerState<SpeciesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  SpeciesCategory? _category;
  SeenSpeciesSort _sort = SeenSpeciesSort.mostSightings;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entriesAsync = ref.watch(seenSpeciesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.marineLife_speciesPage_title),
        actions: [
          PopupMenuButton<SeenSpeciesSort>(
            key: const ValueKey('species_sort_menu'),
            icon: const Icon(Icons.sort),
            tooltip: l10n.marineLife_speciesPage_sortTooltip,
            onSelected: (sort) => setState(() => _sort = sort),
            itemBuilder: (context) => [
              for (final sort in SeenSpeciesSort.values)
                CheckedPopupMenuItem(
                  value: sort,
                  checked: sort == _sort,
                  child: Text(_sortLabel(l10n, sort)),
                ),
            ],
          ),
          IconButton(
            key: const ValueKey('manage_catalog'),
            icon: const Icon(Icons.library_books_outlined),
            tooltip: l10n.marineLife_speciesPage_manageCatalogTooltip,
            onPressed: () => context.push('/species/manage'),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(l10n),
          SpeciesCategoryChips(
            selected: _category,
            onSelected: (category) => setState(() => _category = category),
          ),
          Expanded(
            child: entriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorState(
                message: l10n.marineLife_speciesPage_error(error.toString()),
                retryLabel: l10n.marineLife_speciesPage_retry,
                onRetry: () => ref.invalidate(seenSpeciesProvider),
              ),
              data: _buildList,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: l10n.marineLife_speciesPage_searchHint,
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true,
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: l10n.marineLife_speciesPage_clearSearchTooltip,
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                )
              : null,
        ),
        onChanged: (value) => setState(() => _query = value),
      ),
    );
  }

  Widget _buildList(List<SeenSpecies> entries) {
    final l10n = context.l10n;
    if (entries.isEmpty) {
      return _EmptyState(
        title: l10n.marineLife_speciesPage_emptyTitle,
        hint: l10n.marineLife_speciesPage_emptyHint,
      );
    }

    final visible = filterSeenSpecies(
      entries,
      query: _query,
      category: _category,
      sort: _sort,
      nameOf: (species) => species.localizedCommonName(l10n),
    );
    if (visible.isEmpty) {
      return Center(child: Text(l10n.marineLife_speciesPage_noMatch));
    }

    final sightings = visible.fold<int>(0, (sum, e) => sum + e.totalSightings);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              '${l10n.marineLife_speciesPage_speciesCount(visible.length)} · '
              '${l10n.marineLife_speciesPage_sightingsCount(sightings)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final entry = visible[index];
              return SeenSpeciesTile(
                entry: entry,
                onTap: () => context.push('/species/${entry.species.id}'),
              );
            },
          ),
        ),
      ],
    );
  }

  String _sortLabel(AppLocalizations l10n, SeenSpeciesSort sort) =>
      switch (sort) {
        SeenSpeciesSort.mostSightings =>
          l10n.marineLife_speciesPage_sort_mostSightings,
        SeenSpeciesSort.recentlySeen =>
          l10n.marineLife_speciesPage_sort_recentlySeen,
        SeenSpeciesSort.firstSeen => l10n.marineLife_speciesPage_sort_firstSeen,
        SeenSpeciesSort.name => l10n.marineLife_speciesPage_sort_name,
      };
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String hint;

  const _EmptyState({required this.title, required this.hint});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.visibility_off_outlined,
                size: 48,
                color: theme.colorScheme.onSurface.withAlpha(77),
              ),
            ),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(128),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}
