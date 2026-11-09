import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/text/fuzzy_match.dart';
import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_color.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Picks the species the map shows: the diver's seen species, most seen
/// first, and a search over the whole catalog so a diver planning a trip
/// can pick one they have never seen (issue #4358).
///
/// The search folds case and accents ([normalize]) over the name on screen
/// and the scientific name.
class SpeciesMapListPane extends ConsumerStatefulWidget {
  final String? selectedSpeciesId;
  final ValueChanged<String?> onSelected;

  const SpeciesMapListPane({
    super.key,
    required this.selectedSpeciesId,
    required this.onSelected,
  });

  @override
  ConsumerState<SpeciesMapListPane> createState() => _SpeciesMapListPaneState();
}

class _SpeciesMapListPaneState extends ConsumerState<SpeciesMapListPane> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final seen = ref.watch(seenSpeciesProvider).value ?? const <SeenSpecies>[];
    final catalog = ref.watch(allSpeciesProvider).value ?? const <Species>[];
    final seenById = {for (final s in seen) s.species.id: s};
    final needle = normalize(_query);

    final List<Species> rows;
    if (needle.isEmpty) {
      final sorted = [...seen]
        ..sort((a, b) => b.totalSightings.compareTo(a.totalSightings));
      rows = [for (final s in sorted) s.species];
    } else {
      bool matches(Species s) =>
          normalize(s.localizedCommonName(l10n)).contains(needle) ||
          normalize(s.scientificName ?? '').contains(needle);
      final found = catalog.where(matches).toList()
        ..sort((a, b) {
          // Seen species first, then by name.
          final seenOrder = (seenById.containsKey(a.id) ? 0 : 1).compareTo(
            seenById.containsKey(b.id) ? 0 : 1,
          );
          if (seenOrder != 0) return seenOrder;
          return normalize(
            a.localizedCommonName(l10n),
          ).compareTo(normalize(b.localizedCommonName(l10n)));
        });
      rows = found;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.speciesMap_list_searchHint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: rows.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  selected: widget.selectedSpeciesId == null,
                  leading: const Icon(Icons.public),
                  title: Text(l10n.speciesMap_list_allSites),
                  subtitle: Text(l10n.speciesMap_list_allSitesSubtitle),
                  onTap: () => widget.onSelected(null),
                );
              }
              final species = rows[index - 1];
              final entry = seenById[species.id];
              final theme = Theme.of(context);
              return ListTile(
                selected: widget.selectedSpeciesId == species.id,
                leading: Icon(
                  iconForSpeciesCategory(species.category),
                  color: colorForSpeciesCategory(
                    species.category,
                    theme.brightness,
                  ),
                ),
                title: Text(species.localizedCommonName(l10n)),
                subtitle: Text(
                  entry == null
                      ? l10n.speciesMap_list_notSeen
                      : l10n.speciesMap_list_counts(
                          entry.totalSightings,
                          entry.siteCount,
                        ),
                ),
                onTap: () => widget.onSelected(species.id),
              );
            },
          ),
        ),
      ],
    );
  }
}
