import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/change_log/presentation/widgets/change_log_history_menu_item.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/widgets/open_in_connections.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/marine_life/presentation/species_display.dart';
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

import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/domain/entities/species_crop.dart';
import 'package:submersion/features/marine_life/domain/species_rarity.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_gallery_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_crop_strip.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_depth_season_section.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_facts_row.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_hero.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_sightings_timeline.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_write_feedback.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

part 'species_detail_page_creating.dart';
part 'species_detail_page_editing.dart';
part 'species_detail_page_layout.dart';

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
        _SpeciesDetailPageCreating,
        _SpeciesDetailPageLayout {
  @override
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
  /// the page offers it; laid out by [_layout] (issue #5027).
  Widget _body(Species species) => _layout(species);

  @override
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

  @override
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
