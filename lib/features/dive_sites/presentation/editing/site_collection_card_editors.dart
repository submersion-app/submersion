import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_classification_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_species_sitting.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_picker_dialog.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_form_block.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

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

class _SiteTagsCardEditorState extends State<SiteTagsCardEditor> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SiteTagsCardEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) _load();
  }

  void _load() {
    siteTagsList.load(widget.session).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => TagFormBlock(
        label: context.l10n.diveSites_edit_typeTags_tagsLabel,
        selectedTags: siteTagsList.current(session) ?? const <Tag>[],
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
  });

  final EditSession<DiveSite> session;
  final SiteSpeciesPicker pickSpecies;

  @override
  State<SiteSpeciesCardEditor> createState() => _SiteSpeciesCardEditorState();
}

class _SiteSpeciesCardEditorState extends State<SiteSpeciesCardEditor> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SiteSpeciesCardEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) _load();
  }

  void _load() {
    siteSpeciesList.load(widget.session).then((_) {
      if (mounted) setState(() {});
    });
  }

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
    final found = added.isEmpty
        ? const <Species>[]
        : await SpeciesRepository().getAllSpecies(ids: added);
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
        final current = siteSpeciesList.current(session);
        if (current == null) return const SizedBox.shrink();
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
