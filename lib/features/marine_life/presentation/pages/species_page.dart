import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/domain/seen_species_filter.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/domain/entities/species_crop.dart';
import 'package:submersion/features/marine_life/domain/life_list_summary.dart';
import 'package:submersion/features/marine_life/domain/species_grouping.dart';
import 'package:submersion/features/marine_life/domain/species_rarity.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_browse_prefs_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_gallery_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/life_list_header.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_browse_controls.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_grouped_view.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_category_chips.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_query_providers.dart';
import 'package:submersion/features/marine_life/query/species_query_entity.dart';
import 'package:submersion/features/query/presentation/widgets/entity_search_header.dart';
import 'package:submersion/features/query/presentation/widgets/query_chips_frame.dart';
import 'package:submersion/features/query/presentation/providers/query_id_set_providers.dart';
import 'package:submersion/features/query/presentation/widgets/query_filter_sheet.dart';
import 'package:submersion/features/species_id/presentation/widgets/species_download_prompt.dart';
import 'package:submersion/features/species_id/presentation/widgets/species_review_banner.dart';

/// The species the diver has seen across every dive, searchable and sortable,
/// as a photo-first life list (issue #5027): a header with the totals, cards
/// with each species' best picture and rarity, and Group by.
///
/// Reached at `/species` from the nav and from the Insights > Species
/// tab. Housekeeping
/// (edit, delete, reset the catalog) stays on the manager at
/// `/species/manage`, behind the app-bar action. Query, category and sort are
/// per-visit state, so they live here rather than in a provider.
class SpeciesPage extends ConsumerStatefulWidget {
  const SpeciesPage({super.key});

  @override
  ConsumerState<SpeciesPage> createState() => _SpeciesPageState();
}

class _SpeciesPageState extends ConsumerState<SpeciesPage> {
  SpeciesCategory? _category;
  SeenSpeciesSort _sort = SeenSpeciesSort.mostDives;
  bool _noPhotoOnly = false;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entriesAsync = ref.watch(filteredSeenSpeciesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.marineLife_speciesPage_title),
        actions: [
          QueryFilterAction(
            provider: seenSpeciesQueryProvider,
            subject: QuerySubject.species,
            root: speciesQueryEntity,
          ),
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
            key: const ValueKey('species_practice'),
            icon: const Icon(Icons.quiz_outlined),
            tooltip: l10n.marineLife_speciesPage_practiceTooltip,
            onPressed: () => context.push('/species/practice'),
          ),
          IconButton(
            key: const ValueKey('species_map'),
            icon: const Icon(Icons.map_outlined),
            tooltip: l10n.speciesMap_openTooltip,
            onPressed: () => context.push('/species/map'),
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
          // What the app tagged on its own, to confirm (issue #4727).
          const SpeciesReviewBanner(),
          // With no model, the offer to download one (issue #4773).
          const SpeciesDownloadPrompt(banner: true),
          EntitySearchHeader(
            subject: QuerySubject.species,
            root: speciesQueryEntity,
            query: ref.watch(seenSpeciesQueryProvider),
            onChanged: (q) =>
                ref.read(seenSpeciesQueryProvider.notifier).state = q,
            hintText: l10n.marineLife_speciesPage_searchHint,
            alwaysShown: true,
          ),
          SpeciesCategoryChips(
            selected: _category,
            onSelected: (category) => setState(() => _category = category),
          ),
          Expanded(
            child: QueryChipsFrame(
              root: speciesQueryEntity,
              query: ref.watch(seenSpeciesQueryProvider),
              onChanged: (q) =>
                  ref.read(seenSpeciesQueryProvider.notifier).state = q,
              child: entriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _ErrorState(
                  message: l10n.marineLife_speciesPage_error(error.toString()),
                  retryLabel: l10n.marineLife_speciesPage_retry,
                  onRetry: () {
                    // An id-set error shows here too: run the query again.
                    ref.invalidate(entityQueryIdsProvider);
                    ref.invalidate(seenSpeciesProvider);
                  },
                ),
                data: _buildList,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<SeenSpecies> entries) {
    // A query that hid every sighted species is not "nothing seen yet".
    if (entries.isEmpty && ref.watch(seenSpeciesQueryProvider) != null) {
      return QueryNoMatchState(
        onClear: () => ref.read(seenSpeciesQueryProvider.notifier).state = null,
      );
    }
    final l10n = context.l10n;
    if (entries.isEmpty) {
      return _EmptyState(
        title: l10n.marineLife_speciesPage_emptyTitle,
        hint: l10n.marineLife_speciesPage_emptyHint,
      );
    }
    // Pictures, covers and practice load beside the cards, not ahead of
    // them: until they arrive a card shows its category tile.
    final picturesAsync = ref.watch(speciesPicturesProvider);
    final pictures = picturesAsync.value ?? const <String, SpeciesPicture>{};
    // Until the pictures arrive nothing is known to lack one: no count, and
    // no filtering on it.
    final picturesKnown = picturesAsync.hasValue;
    final covers =
        ref.watch(speciesCoverMediaProvider).value ??
        const <String, MediaItem>{};
    final practice = ref.watch(speciesPracticeStatesProvider).value ?? const {};
    final groupBy = ref.watch(speciesGroupByProvider);
    final grid = ref.watch(speciesBrowseGridProvider);
    final places =
        groupBy == SpeciesGroupBy.trip || groupBy == SpeciesGroupBy.site
        ? ref.watch(speciesPlacesProvider).value
        : null;
    // The header describes the whole life list, whatever the filters keep.
    final all = ref.watch(seenSpeciesProvider).value ?? entries;
    bool hasPicture(SeenSpecies e) {
      final picture = pictures[e.species.id];
      return picture != null && picture is! NoPicture;
    }

    final now = DateTime.now();
    final visible = [
      for (final e in filterSeenSpecies(
        entries,
        category: _category,
        sort: _sort,
        nameOf: (species) => species.localizedCommonName(l10n),
      ))
        if (!_noPhotoOnly || !picturesKnown || !hasPicture(e)) e,
    ];
    final sightings = visible.fold<int>(0, (sum, e) => sum + e.totalSightings);
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LifeListHeader(
          summary: summarizeLifeList(all, now: now),
          year: now.year,
          withoutPhoto: picturesKnown
              ? all.where((e) => !hasPicture(e)).length
              : 0,
          noPhotoFilterOn: _noPhotoOnly,
          onNoPhotoFilter: (on) => setState(() => _noPhotoOnly = on),
        ),
        SpeciesBrowseControls(
          summary:
              '${l10n.marineLife_speciesPage_speciesCount(visible.length)} · '
              '${l10n.marineLife_speciesPage_sightingsCount(sightings)}',
          groupBy: groupBy,
          grid: grid,
          onGroupBy: (by) => ref.read(speciesGroupByProvider.notifier).set(by),
          onGrid: (on) => ref.read(speciesBrowseGridProvider.notifier).set(on),
        ),
      ],
    );
    if (visible.isEmpty) {
      return ListView(
        children: [
          header,
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: Text(l10n.marineLife_speciesPage_noMatch)),
          ),
        ],
      );
    }
    return SpeciesGroupedView(
      groups: groupSeenSpecies(visible, by: groupBy, places: places),
      by: groupBy,
      grid: grid,
      pictures: pictures,
      covers: covers,
      header: header,
      rarityOf: (e) =>
          rarityFor(e, now: now, practiceBox: practice[e.species.id]?.box),
      onOpen: (e) => context.push('/species/${e.species.id}'),
      onSeeAllCategory: (category) {
        setState(() => _category = category);
        ref.read(speciesGroupByProvider.notifier).set(SpeciesGroupBy.none);
      },
    );
  }

  String _sortLabel(AppLocalizations l10n, SeenSpeciesSort sort) =>
      switch (sort) {
        SeenSpeciesSort.mostDives => l10n.marineLife_speciesPage_sort_mostDives,
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
