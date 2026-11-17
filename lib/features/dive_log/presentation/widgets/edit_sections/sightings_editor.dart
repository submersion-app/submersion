import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/edit_sighting_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/species_picker_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/site_species_suggestion_chips.dart';
import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/domain/site_species_suggestions.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_color.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/features/marine_life/presentation/widgets/sighting_amount_badge.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _uuid = Uuid();

/// A dive's sightings: a row per species with its amount (tap to edit, or
/// remove), Add (the species picker) and, given [siteId], the species the
/// diver has seen or expects there.
///
/// The dive form, bulk edit and the dive page's Sightings card all use it
/// (issue #4527, plan 6). It holds nothing: every change is handed to
/// [onChanged] as the whole new list. A sighting added here carries a fresh
/// id, which no stored sighting has.
class SightingsEditor extends StatelessWidget {
  const SightingsEditor({
    super.key,
    required this.sightings,
    required this.onChanged,
    this.diveId = '',
    this.siteId,
    this.siteName,
    this.excludeDiveId,
    this.showTitle = true,
  });

  final List<Sighting> sightings;
  final ValueChanged<List<Sighting>> onChanged;

  /// The dive the sightings are for ('' for a dive not yet written).
  final String diveId;

  /// The dive's site, for its suggestions. Null shows none, as for bulk
  /// edit, whose dives may be at different sites.
  final String? siteId;
  final String? siteName;

  /// The dive left out of the site's sightings, so it does not suggest what
  /// it already holds.
  final String? excludeDiveId;

  /// Whether it draws its own title: a card shows the title in its header.
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final addButton = TextButton.icon(
      onPressed: () => _showSpeciesPicker(context),
      icon: const Icon(Icons.add, size: 18),
      label: Text(l10n.diveLog_edit_add),
    );
    final site = siteId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: showTitle
              ? MainAxisAlignment.spaceBetween
              : MainAxisAlignment.end,
          children: [
            if (showTitle)
              Text(
                l10n.diveLog_edit_section_marineLife,
                style: theme.textTheme.titleMedium,
              ),
            addButton,
          ],
        ),
        if (sightings.isEmpty) ...[
          const SizedBox(height: 8),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Icon(
                    Icons.water,
                    size: 48,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.diveLog_edit_noMarineLife,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.diveLog_edit_marineLifeHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          const Divider(),
          for (final (index, sighting) in sightings.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: colorForSpeciesCategory(
                  sighting.speciesCategory,
                  theme.brightness,
                ),
                child: Icon(
                  iconForSpeciesCategory(
                    sighting.speciesCategory ?? SpeciesCategory.other,
                  ),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: Text(
                localizedSpeciesName(
                  l10n,
                  sighting.speciesId,
                  sighting.speciesName,
                ),
              ),
              subtitle: sighting.notes.isNotEmpty
                  ? Text(
                      sighting.notes,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SightingAmountBadge(amount: sighting.amount),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: l10n.diveLog_edit_tooltip_removeSighting,
                    onPressed: () => onChanged([...sightings]..removeAt(index)),
                  ),
                ],
              ),
              onTap: () => _editSighting(context, index),
            ),
        ],
        if (site != null)
          SiteSpeciesSuggestionChips(
            // A new site starts collapsed rather than inheriting "Show all".
            key: ValueKey(site),
            siteId: site,
            siteName: siteName ?? '',
            excludeDiveId: excludeDiveId,
            loggedSpeciesIds: {for (final s in sightings) s.speciesId},
            onAdd: _addSuggested,
          ),
      ],
    );
  }

  /// A suggestion chip's tap (issue #4383): the species goes on as Seen with
  /// no notes, as the picker's default does (#4337), and its row then edits
  /// the amount and notes like any other sighting.
  void _addSuggested(SiteSpeciesSuggestion suggestion) {
    onChanged([
      ...sightings,
      Sighting(
        id: _uuid.v4(),
        diveId: diveId,
        speciesId: suggestion.speciesId,
        speciesName: suggestion.speciesName,
        speciesCategory: suggestion.category,
        abundance: SightingAbundance.seen,
        notes: '',
      ),
    ]);
  }

  void _showSpeciesPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SpeciesPickerSheet(
          scrollController: scrollController,
          onSpeciesSelected: (species, amount, notes) {
            onChanged([
              ...sightings,
              Sighting(
                id: _uuid.v4(),
                diveId: diveId,
                speciesId: species.id,
                speciesName: species.commonName,
                speciesCategory: species.category,
                abundance: amount.abundance,
                count: amount.count,
                notes: notes,
              ),
            ]);
            Navigator.of(sheetContext).pop();
          },
        ),
      ),
    );
  }

  void _editSighting(BuildContext context, int index) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => EditSightingSheet(
        sighting: sightings[index],
        onSave: (updated) {
          onChanged([...sightings]..[index] = updated);
          Navigator.of(sheetContext).pop();
        },
        onDelete: () {
          onChanged([...sightings]..removeAt(index));
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }
}
