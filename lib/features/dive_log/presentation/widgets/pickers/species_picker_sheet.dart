import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_color.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_lookup_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Species picker bottom sheet with search
class SpeciesPickerSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final void Function(Species species, int count, String notes)
  onSpeciesSelected;

  const SpeciesPickerSheet({
    super.key,
    required this.scrollController,
    required this.onSpeciesSelected,
  });

  @override
  ConsumerState<SpeciesPickerSheet> createState() => _SpeciesPickerSheetState();
}

class _SpeciesPickerSheetState extends ConsumerState<SpeciesPickerSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  SpeciesCategory? _selectedCategory;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The repository search only matches the English columns the database
    // stores. Without the localized fold-in below, a diver searching in their
    // own language sees "No species found" and is offered a duplicate custom
    // species by the empty state.
    final catalog = ref.watch(allSpeciesProvider);
    final speciesAsync = _searchQuery.isEmpty && _selectedCategory == null
        ? catalog
        : _selectedCategory != null
        ? ref.watch(speciesByCategoryProvider(_selectedCategory!))
        : ref
              .watch(speciesSearchProvider(_searchQuery))
              .whenData(
                (results) => withLocalizedSpeciesMatches(
                  results: results,
                  catalog: catalog.value ?? const [],
                  query: _searchQuery,
                  l10n: context.l10n,
                ),
              );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.diveLog_speciesPicker_title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: context.l10n.common_action_close,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: context.l10n.diveLog_speciesPicker_searchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: context
                          .l10n
                          .diveLog_speciesPicker_tooltip_clearSearch,
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                if (value.isNotEmpty) {
                  _selectedCategory = null;
                }
              });
            },
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildCategoryChip(
                null,
                context.l10n.marineLife_speciesPicker_allFilter,
              ),
              ...SpeciesCategory.values.map(
                (category) => _buildCategoryChip(
                  category,
                  category.localizedName(context.l10n),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 16),
        Expanded(
          child: speciesAsync.when(
            data: (speciesList) {
              if (speciesList.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.water,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? context.l10n.diveLog_speciesPicker_noResults
                            : context.l10n.diveLog_speciesPicker_noSpecies,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (_searchQuery.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: () => _addCustomSpecies(_searchQuery),
                          child: Text(
                            context.l10n.diveLog_speciesPicker_addNew(
                              _searchQuery,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: widget.scrollController,
                itemCount: speciesList.length,
                itemBuilder: (context, index) {
                  final species = speciesList[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorForSpeciesCategory(
                        species.category,
                        Theme.of(context).brightness,
                      ),
                      child: Icon(
                        iconForSpeciesCategory(species.category),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(species.localizedCommonName(context.l10n)),
                    subtitle: species.scientificName != null
                        ? Text(
                            species.scientificName!,
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          )
                        : null,
                    trailing: Text(
                      species.category.localizedName(context.l10n),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    onTap: () => _showSightingDetails(species),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                context.l10n.diveLog_speciesPicker_errorLoading(
                  error.toString(),
                ),
              ),
            ),
          ),
        ),
        // The empty state's "Add ..." button only appears when the catalog
        // answers nothing, so a diver whose search has one near-miss hit had
        // no way to reach the online lookup at all. This footer is the door
        // that is always open.
        const Divider(height: 1),
        // Neither host passes useSafeArea, and the sheet is bottom-anchored,
        // so without this the button sits under the home indicator. The list
        // above could be scrolled clear of it; a fixed footer cannot.
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextButton.icon(
              key: const ValueKey('species_picker_lookup_online'),
              icon: const Icon(Icons.travel_explore),
              label: Text(context.l10n.marineLife_lookup_button),
              onPressed: _lookUpOnline,
            ),
          ),
        ),
      ],
    );
  }

  /// The always-available online path. Unlike the empty state, the diver has
  /// not committed to creating anything, so a dismissed sheet must create
  /// nothing; with no query typed there is also no name to fall back on, so
  /// the sheet's "create without lookup" escape is withheld.
  Future<void> _lookUpOnline() async {
    final query = _searchQuery.trim();
    final outcome = await showSpeciesLookupSheet(
      context,
      initialQuery: query,
      allowCreateWithout: query.isNotEmpty,
    );
    if (!mounted || outcome == null) return;
    await _createFromOutcome(outcome, fallbackName: query);
  }

  /// Turns a lookup outcome into a species and opens the sighting dialog.
  /// [fallbackName] is what a "create without lookup" is named.
  Future<void> _createFromOutcome(
    SpeciesLookupOutcome outcome, {
    required String fallbackName,
  }) async {
    final repository = ref.read(speciesRepositoryProvider);
    final species = switch (outcome) {
      SpeciesLookupChosen(:final result) => await _speciesFromLookup(
        repository,
        result,
      ),
      SpeciesLookupCreateWithout() => await repository.getOrCreateSpecies(
        commonName: fallbackName,
        category: SpeciesCategory.other,
      ),
    };
    if (mounted) _showSightingDetails(species);
  }

  Widget _buildCategoryChip(SpeciesCategory? category, String label) {
    final isSelected = _selectedCategory == category && _searchQuery.isEmpty;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = selected ? category : null;
            if (selected) {
              _searchController.clear();
              _searchQuery = '';
            }
          });
        },
      ),
    );
  }

  void _showSightingDetails(Species species) {
    int count = 1;
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(species.localizedCommonName(context.l10n)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: context.l10n.diveLog_sighting_decreaseCount,
                    onPressed: count > 1
                        ? () => setDialogState(() => count--)
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: context.l10n.diveLog_sighting_increaseCount,
                    onPressed: () => setDialogState(() => count++),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  labelText: context.l10n.diveLog_sighting_notesOptional,
                  hintText: context.l10n.diveLog_sighting_notesHint,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.diveLog_sighting_cancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                widget.onSpeciesSelected(species, count, notesController.text);
              },
              child: Text(context.l10n.diveLog_sighting_add),
            ),
          ],
        ),
      ),
    );
  }

  /// The empty state's "add" path: look the name up first so a custom
  /// species gets its scientific name, category and class; "Create without
  /// lookup" (or a dismissed sheet) keeps the old name-only creation, so an
  /// offline diver loses nothing.
  Future<void> _addCustomSpecies(String name) async {
    final outcome = await showSpeciesLookupSheet(context, initialQuery: name);
    if (!mounted) return;
    // The diver already tapped "Add <name>", so dismissing the lookup is not
    // a reason to abandon the species they asked for.
    await _createFromOutcome(
      outcome ?? const SpeciesLookupCreateWithout(),
      fallbackName: name,
    );
  }

  Future<Species> _speciesFromLookup(
    SpeciesRepository repository,
    SpeciesLookupResult result,
  ) async {
    final existing = await repository.findSpeciesByScientificName(
      result.scientificName,
    );
    if (existing != null) return existing;
    return repository.createSpecies(
      commonName: result.commonName,
      scientificName: result.scientificName,
      category: result.category,
      taxonomyClass: result.taxonomyClass,
    );
  }
}
