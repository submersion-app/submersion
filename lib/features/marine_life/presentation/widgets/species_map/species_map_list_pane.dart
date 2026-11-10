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
import 'package:submersion/l10n/arb/app_localizations.dart';
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

  /// Folded names per species id, refolded only when the catalog or the
  /// language changes rather than on every keystroke and rebuild.
  List<Species>? _foldedCatalog;
  Locale? _foldedLocale;
  Map<String, ({String common, String scientific})> _folded = const {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Map<String, ({String common, String scientific})> _foldedNames(
    List<Species> catalog,
    AppLocalizations l10n,
    Locale locale,
  ) {
    if (!identical(catalog, _foldedCatalog) || locale != _foldedLocale) {
      _foldedCatalog = catalog;
      _foldedLocale = locale;
      _folded = {
        for (final s in catalog)
          s.id: (
            common: normalize(s.localizedCommonName(l10n)),
            scientific: normalize(s.scientificName ?? ''),
          ),
      };
    }
    return _folded;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final seenAsync = ref.watch(seenSpeciesProvider);
    final catalogAsync = ref.watch(allSpeciesProvider);
    final needle = normalize(_query);
    // A failed read says so: an empty list would read as "nothing logged".
    // Only the read the list on screen needs: the seen list carries its own
    // species, and the search runs over the catalog (losing only the
    // seen-first order if the seen read failed).
    final failed = needle.isEmpty ? seenAsync.hasError : catalogAsync.hasError;
    final seen = seenAsync.value ?? const <SeenSpecies>[];
    final catalog = catalogAsync.value ?? const <Species>[];
    final seenById = {for (final s in seen) s.species.id: s};

    final List<Species> rows;
    if (failed) {
      rows = const [];
    } else if (needle.isEmpty) {
      final names = {
        for (final s in seen) s.species.id: s.species.localizedCommonName(l10n),
      };
      final sorted = [...seen]
        ..sort((a, b) {
          // Most seen first, then by name, so equal counts keep one order.
          final byCount = b.totalSightings.compareTo(a.totalSightings);
          return byCount != 0
              ? byCount
              : names[a.species.id]!.compareTo(names[b.species.id]!);
        });
      rows = [for (final s in sorted) s.species];
    } else {
      final folded = _foldedNames(
        catalog,
        l10n,
        Localizations.localeOf(context),
      );
      bool matches(Species s) {
        final names = folded[s.id]!;
        return names.common.contains(needle) ||
            names.scientific.contains(needle);
      }

      int seenRank(Species s) => seenById.containsKey(s.id) ? 0 : 1;
      rows = catalog.where(matches).toList()
        ..sort((a, b) {
          // Seen species first, then by name.
          final bySeen = seenRank(a).compareTo(seenRank(b));
          return bySeen != 0
              ? bySeen
              : folded[a.id]!.common.compareTo(folded[b.id]!.common);
        });
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
            itemCount: rows.length + (failed ? 2 : 1),
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
              if (failed) {
                return ListTile(
                  leading: Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(l10n.speciesMap_error_loading),
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
