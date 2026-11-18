import 'package:flutter/material.dart';

import 'package:submersion/core/services/logger_service.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_classification_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_features_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sitting_load_on_open.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_species_sitting.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_picker_dialog.dart';
import 'package:submersion/features/site_scape/presentation/site_features_section.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_form_block.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

const _log = LoggerService('SiteCollectionCardEditors');

/// The Tags card's editor: the tag input the form uses, limited to site
/// tags (issue #4527, phase 2).
///
/// A tag the diver creates here exists at once and outlives a cancelled
/// sitting; only which tags the site carries is held until Save.
class SiteTagsCardEditor extends StatefulWidget {
  const SiteTagsCardEditor({super.key, required this.session});

  final EditSession<DiveSite> session;

  @override
  State<SiteTagsCardEditor> createState() => _SiteTagsCardEditorState();
}

class _SiteTagsCardEditorState extends State<SiteTagsCardEditor>
    with SiteSittingLoadOnOpen<SiteTagsCardEditor> {
  @override
  EditSession<DiveSite> sittingOf(SiteTagsCardEditor widget) => widget.session;

  @override
  Future<void> loadSitting(EditSession<DiveSite> session) =>
      siteTagsList.load(session);

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return ListenableBuilder(
      listenable: session,
      // Not before the tags are read: a pick then would have nowhere to go.
      builder: (context, _) =>
          sittingListPending(siteTagsList) ??
          TagFormBlock(
            label: context.l10n.diveSites_edit_typeTags_tagsLabel,
            selectedTags: siteTagsList.current(session)!,
            onTagsChanged: (tags) => siteTagsList.set(session, tags),
            scope: TagScope.sites,
          ),
    );
  }
}

/// Opens the species picker over [selected] and answers the ids chosen, or
/// null when it was dismissed.
typedef SiteSpeciesPicker =
    Future<Set<String>?> Function(BuildContext context, Set<String> selected);

Future<List<Species>> _findSpecies(List<String> ids) =>
    SpeciesRepository().getAllSpecies(ids: ids);

Future<Set<String>?> _pickSpecies(BuildContext context, Set<String> selected) =>
    showDialog<Set<String>>(
      context: context,
      builder: (context) => SpeciesPickerDialog(initialSelection: selected),
    );

/// The Marine Life card's editor: the expected species, each removable, and
/// the species picker the card's own button opened (issue #4527, phase 2).
/// What was spotted on dives here is not the diver's to edit.
class SiteSpeciesCardEditor extends StatefulWidget {
  const SiteSpeciesCardEditor({
    super.key,
    required this.session,
    this.pickSpecies = _pickSpecies,
    this.findSpecies = _findSpecies,
  });

  final EditSession<DiveSite> session;
  final SiteSpeciesPicker pickSpecies;

  /// Reads the species picked that the list does not have yet.
  final Future<List<Species>> Function(List<String> ids) findSpecies;

  @override
  State<SiteSpeciesCardEditor> createState() => _SiteSpeciesCardEditorState();
}

class _SiteSpeciesCardEditorState extends State<SiteSpeciesCardEditor>
    with SiteSittingLoadOnOpen<SiteSpeciesCardEditor> {
  @override
  EditSession<DiveSite> sittingOf(SiteSpeciesCardEditor widget) =>
      widget.session;

  @override
  Future<void> loadSitting(EditSession<DiveSite> session) =>
      siteSpeciesList.load(session);

  Future<void> _pick(List<SiteSpeciesEntry> current) async {
    final session = widget.session;
    final picked = await widget.pickSpecies(context, {
      for (final e in current) e.speciesId,
    });
    if (picked == null || !mounted) return;
    final byId = {for (final e in current) e.speciesId: e};
    final added = [
      for (final id in picked)
        if (!byId.containsKey(id)) id,
    ];
    final List<Species> found;
    try {
      found = added.isEmpty
          ? const <Species>[]
          : await widget.findSpecies(added);
    } catch (error, stackTrace) {
      _log.error(
        'Reading picked species failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.marineLife_siteSection_errorLoadingExpected,
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    final siteId = session.stored.id;
    siteSpeciesList.set(session, [
      for (final e in current)
        if (picked.contains(e.speciesId)) e,
      for (final s in found) newSiteSpeciesEntry(siteId, s),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final pending = sittingListPending(siteSpeciesList);
        if (pending != null) return pending;
        final current = siteSpeciesList.current(session)!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (current.isEmpty)
              Text(l10n.marineLife_siteSection_noExpected)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in current)
                    InputChip(
                      label: Text(
                        localizedSpeciesName(
                          l10n,
                          entry.speciesId,
                          entry.speciesName,
                        ),
                      ),
                      onDeleted: () => siteSpeciesList.set(session, [
                        for (final e in current)
                          if (e.speciesId != entry.speciesId) e,
                      ]),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.marineLife_siteSection_editExpectedTooltip),
              onPressed: () => _pick(current),
            ),
          ],
        );
      },
    );
  }
}

/// The Features card's editor: the features, each opening the sheet whose
/// answer the sitting holds, and "Add feature", which opens the site's map
/// armed to place one in the sitting (issue #4527, phase 2).
class SiteFeaturesCardEditor extends StatefulWidget {
  const SiteFeaturesCardEditor({
    super.key,
    required this.session,
    this.openSheet,
  });

  final EditSession<DiveSite> session;

  /// Opens the feature sheet; null is the app's own.
  final SiteFeatureSheetOpener? openSheet;

  @override
  State<SiteFeaturesCardEditor> createState() => _SiteFeaturesCardEditorState();
}

class _SiteFeaturesCardEditorState extends State<SiteFeaturesCardEditor>
    with SiteSittingLoadOnOpen<SiteFeaturesCardEditor> {
  @override
  EditSession<DiveSite> sittingOf(SiteFeaturesCardEditor widget) =>
      widget.session;

  @override
  Future<void> loadSitting(EditSession<DiveSite> session) =>
      siteFeaturesList.load(session);

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final placeOnMap = SiteFeaturePlacementScope.maybeOf(context);
    final openSheet = widget.openSheet;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final pending = sittingListPending(siteFeaturesList);
        if (pending != null) return pending;
        final current = siteFeaturesList.current(session)!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SiteFeatureRows(
              features: current,
              onTap: (feature) => editFeatureInSitting(
                context,
                session,
                feature,
                openSheet: openSheet,
              ),
            ),
            // Nowhere to place one once the coordinates are cleared.
            if (placeOnMap != null && session.working.hasCoordinates)
              SiteFeatureAddButton(onPressed: () => placeOnMap(session)),
          ],
        );
      },
    );
  }
}
