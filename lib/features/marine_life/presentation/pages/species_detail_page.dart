import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/change_log/presentation/widgets/change_log_history_menu_item.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/widgets/open_in_connections.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/core/utils/app_version.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/domain/services/species_suggestion_url.dart';
import 'package:submersion/features/marine_life/presentation/helpers/species_suggestion_launcher.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_sightings_section.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_where_seen_section.dart';
import 'package:submersion/features/media/presentation/pages/species_tag_picker_page.dart';
import 'package:submersion/features/media/presentation/helpers/species_photo_import_helper.dart';
import 'package:submersion/features/media/presentation/widgets/species_photos_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/insights/domain/entities/species_insights.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_view.dart';
import 'package:submersion/features/marine_life/data/services/species_edit_save_service.dart';
import 'package:submersion/features/marine_life/presentation/editing/species_card_ids.dart';
import 'package:submersion/features/marine_life/presentation/editing/species_edit_cards.dart';
import 'package:submersion/features/marine_life/presentation/editing/species_new_sitting.dart';
import 'package:submersion/features/marine_life/presentation/editing/species_photos_sitting.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_enqueue_provider.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_fade.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_creating.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';
import 'package:submersion/shared/widgets/record_editing/record_open_unlocked.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';

part 'species_detail_page_creating.dart';
part 'species_detail_page_editing.dart';

/// A species' page. It opens locked and edits in place (issue #4527): its names
/// and description are held in one sitting and written by one Save.
class SpeciesDetailPage extends ConsumerStatefulWidget {
  final String speciesId;

  /// Opens unlocked, as the old edit address asks (`?mode=edit`).
  final bool openUnlocked;

  /// A new species (issue #4527, phase 3, plan 11): the page opened
  /// unlocked on a species not yet created.
  final bool newSpecies;

  const SpeciesDetailPage({
    super.key,
    required this.speciesId,
    this.openUnlocked = false,
  }) : newSpecies = false;

  /// A new species' page.
  const SpeciesDetailPage.newSpecies({super.key})
    : speciesId = '',
      openUnlocked = false,
      newSpecies = true;

  @override
  ConsumerState<SpeciesDetailPage> createState() => _SpeciesDetailPageState();
}

class _SpeciesDetailPageState extends ConsumerState<SpeciesDetailPage>
    with
        RecordEditHost<SpeciesDetailPage, Species>,
        RecordOpenUnlocked<SpeciesDetailPage, Species>,
        _SpeciesDetailPageEditing,
        RecordCreating<SpeciesDetailPage, Species>,
        _SpeciesDetailPageCreating {
  String get speciesId => widget.speciesId;

  @override
  void dispose() {
    disposeEditing();
    super.dispose();
  }

  /// Today's top bar, with the lock beside Edit when the page edits in
  /// place and the record has been read.
  PreferredSizeWidget _lockedBar(Species? species) => AppBar(
    leading: IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: context.l10n.marineLife_speciesDetail_backTooltip,
      onPressed: () => context.pop(),
    ),
    actions: [
      if (species != null) lockButton(species),
      if (species != null) _menu(species),
    ],
  );

  /// The page's menu: History, Open in Connections, Suggest for catalog,
  /// and its whole-record operations. Shown in the locked bar and, while
  /// unlocked, in the edit bar.
  Widget _menu(Species species) => PopupMenuButton<String>(
    key: const ValueKey('species_detail_menu'),
    onSelected: (value) {
      if (value == kOpenInConnectionsAction) {
        openInConnections(context, NodeRef(ConnectionKind.species, species.id));
      } else if (value == 'suggest') {
        _suggestForCatalog(context, ref, species);
      } else if (value == 'delete') {
        _runSpeciesOperation(() => _deleteSpecies(species));
      }
    },
    itemBuilder: (context) => [
      changeLogHistoryMenuItem(
        context,
        rootTable: 'species',
        rootId: species.id,
      ),
      openInConnectionsMenuItem(context),
      // Only a custom species can be suggested: built-ins
      // already are the catalog.
      if (!species.isBuiltIn)
        PopupMenuItem(
          value: 'suggest',
          child: Text(context.l10n.marineLife_speciesDetail_suggestForCatalog),
        ),
      // Delete, where the manage page allows it (a custom species): a
      // whole-record operation, under the lock.
      ..._speciesRecordMenuItems(species),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (isCreating) return newRecordWaiting(context) ?? _buildNewSpecies();
    final speciesAsync = ref.watch(speciesProvider(speciesId));
    followStored(speciesProvider(speciesId));
    final stored = speciesAsync.value;
    if (stored == null) {
      return Scaffold(
        appBar: _lockedBar(null),
        body: speciesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(
            child: Text(
              context.l10n.marineLife_speciesDetail_errorPrefix(e.toString()),
            ),
          ),
          data: (_) => Center(
            child: Text(context.l10n.marineLife_speciesDetail_notFound),
          ),
        ),
      );
    }
    openUnlockedOnce(stored);
    final shown = shownRecord(stored);
    return editScaffold(
      record: stored,
      shown: shown,
      lockedBar: _lockedBar(shown),
      unlockedActions: [_menu(shown)],
      content: _body(shown),
    );
  }

  /// A new species' page on its seed: its header and description, with no
  /// menu and none of what a species not yet created cannot have (its
  /// statistics, photos, places and sightings).
  Widget _buildNewSpecies() {
    final seed = newRecordSeed!;
    final shown = shownRecord(seed);
    return editScaffold(
      record: seed,
      shown: shown,
      // Never shown: a new species' page leaves once its sitting ends.
      lockedBar: AppBar(title: Text(newRecordTitle(context))),
      content: _body(shown),
    );
  }

  /// The page's sections for [species], framed for editing in place while
  /// the page offers it.
  Widget _body(Species species) {
    final l10n = context.l10n;
    final description = species.localizedDescription(l10n);
    final showDescription =
        (description != null && description.isNotEmpty) ||
        _showsWhileEmpty(SpeciesCardId.description);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _framed(
            SpeciesCardId.header,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(
                  context,
                  species.localizedCommonName(l10n),
                  species.scientificName,
                  species.category,
                  pencil: RecordCardPencil(
                    cardTitle: SpeciesCardId.header.localizedDisplayName(l10n),
                  ),
                ),
                if (species.taxonomyClass != null) ...[
                  const SizedBox(height: 8),
                  _buildTaxonomyBadge(context, species.taxonomyClass!),
                ],
              ],
            ),
          ),
          if (showDescription) ...[
            const SizedBox(height: 16),
            _framed(
              SpeciesCardId.description,
              _buildDescription(
                context,
                description ?? '',
                pencil: RecordCardPencil(
                  cardTitle: SpeciesCardId.description.localizedDisplayName(
                    l10n,
                  ),
                ),
              ),
            ),
          ],
          // A species not yet created has none of these (plan 11,
          // Question 9).
          if (!isCreating) ...[
            const SizedBox(height: 24),
            _calculated(_buildStatisticsSection(context, ref)),
            _photosInSitting(),
            _calculated(SpeciesWhereSeenSection(speciesId: speciesId)),
            _calculated(SpeciesSightingsSection(speciesId: speciesId)),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String commonName,
    String? scientificName,
    SpeciesCategory category, {
    Widget? pencil,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              iconForSpeciesCategory(category),
              color: _getCategoryColor(category),
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    commonName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (scientificName != null && scientificName.isNotEmpty)
                    Text(
                      scientificName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(178),
                      ),
                    ),
                ],
              ),
            ),
            ?pencil,
          ],
        ),
        const SizedBox(height: 8),
        Chip(
          label: Text(category.localizedName(context.l10n)),
          backgroundColor: _getCategoryColor(category).withAlpha(30),
          side: BorderSide(color: _getCategoryColor(category).withAlpha(77)),
        ),
      ],
    );
  }

  Widget _buildTaxonomyBadge(BuildContext context, String taxonomyClass) {
    return Row(
      children: [
        Icon(
          Icons.science_outlined,
          size: 16,
          color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
        ),
        const SizedBox(width: 4),
        Text(
          context.l10n.marineLife_speciesDetail_taxonomyClassLabel(
            taxonomyClass,
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
          ),
        ),
      ],
    );
  }

  Widget _buildDescription(
    BuildContext context,
    String description, {
    Widget? pencil,
  }) {
    final title = Text(
      context.l10n.marineLife_speciesDetail_descriptionTitle,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pencil == null)
              title
            else
              Row(
                children: [
                  Expanded(child: title),
                  pencil,
                ],
              ),
            const SizedBox(height: 8),
            MarkdownNotesView(description),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsSection(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(speciesInsightsProvider(speciesId));

    return statsAsync.when(
      loading: () => const Card(
        child: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      // Says so rather than dropping the section: a failed query is not a
      // species with nothing to show (issue #1930).
      error: (_, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.marineLife_speciesDetail_statsError,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
      data: (stats) {
        if (stats.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.visibility_off_outlined,
                        size: 48,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(77),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.marineLife_speciesDetail_noSightings,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(128),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return _buildStatsCards(context, ref, stats);
      },
    );
  }

  Widget _buildStatsCards(
    BuildContext context,
    WidgetRef ref,
    SpeciesInsights stats,
  ) {
    final units = ref.watch(unitFormatterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.marineLife_speciesDetail_sightingStatsTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        // Summary row. No "total sightings" card: with one sighting per dive
        // it always equalled Dives, and a sum of counts stopped meaning
        // animals once a sighting can be Seen or a REEF group (issue #4337).
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.scuba_diving,
                label: context.l10n.marineLife_speciesDetail_divesLabel,
                value: stats.diveCount.toString(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.place,
                label: context.l10n.marineLife_speciesDetail_sitesLabel,
                value: stats.siteCount.toString(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Depth range
        if (stats.minDepthMeters != null && stats.maxDepthMeters != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.arrow_downward),
              title: Text(
                context.l10n.marineLife_speciesDetail_depthRangeTitle,
              ),
              subtitle: Text(
                '${units.formatDepth(stats.minDepthMeters)} - '
                '${units.formatDepth(stats.maxDepthMeters)}',
              ),
            ),
          ),
        // Date range
        if (stats.firstSeen != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(
                context.l10n.marineLife_speciesDetail_sightingPeriodTitle,
              ),
              subtitle: Text(
                stats.lastSeen != null && stats.firstSeen != stats.lastSeen
                    ? '${units.formatDate(stats.firstSeen)} - '
                          '${units.formatDate(stats.lastSeen)}'
                    : units.formatDate(stats.firstSeen),
              ),
            ),
          ),
        // Top sites
        if (stats.topSites.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            context.l10n.marineLife_speciesDetail_topSitesTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          ...stats.topSites.map(
            (site) => Card(
              child: ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(site.name),
                trailing: Text(
                  context.l10n.marineLife_speciesDetail_sightingCount(
                    site.count,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onTap: () => context.push('/sites/${site.id}'),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(SpeciesCategory category) {
    switch (category) {
      case SpeciesCategory.fish:
        return Colors.blue;
      case SpeciesCategory.shark:
        return Colors.blueGrey;
      case SpeciesCategory.ray:
        return Colors.indigo;
      case SpeciesCategory.mammal:
        return Colors.teal;
      case SpeciesCategory.turtle:
        return Colors.green;
      case SpeciesCategory.invertebrate:
        return Colors.orange;
      case SpeciesCategory.coral:
        return Colors.pink;
      case SpeciesCategory.plant:
        return Colors.lightGreen;
      case SpeciesCategory.other:
        return Colors.grey;
    }
  }

  Future<void> _suggestForCatalog(
    BuildContext context,
    WidgetRef ref,
    Species species,
  ) async {
    final info = await ref.read(packageInfoProvider.future);
    if (!context.mounted) return;
    final uri = buildSpeciesSuggestionUrl(
      species: species,
      locale: ref.read(localeProvider),
      appVersion: formatAppVersion(info),
    );
    await launchSpeciesSuggestion(
      context,
      uri,
      launch: ref.read(speciesSuggestionLaunchProvider),
    );
  }
}
