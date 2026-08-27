import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_color.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
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
      ],
    );
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

  void _addCustomSpecies(String name) async {
    final repository = ref.read(speciesRepositoryProvider);
    final species = await repository.getOrCreateSpecies(
      commonName: name,
      category: SpeciesCategory.other,
    );
    if (mounted) {
      _showSightingDetails(species);
    }
  }
}
