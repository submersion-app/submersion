import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';

/// Dialog for selecting species (multi-select)
class SpeciesPickerDialog extends ConsumerStatefulWidget {
  final Set<String> initialSelection;

  const SpeciesPickerDialog({super.key, this.initialSelection = const {}});

  @override
  ConsumerState<SpeciesPickerDialog> createState() =>
      _SpeciesPickerDialogState();
}

class _SpeciesPickerDialogState extends ConsumerState<SpeciesPickerDialog> {
  late Set<String> _selectedIds;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  SpeciesCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.initialSelection);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final speciesAsync = _searchQuery.isEmpty
        ? ref.watch(allSpeciesProvider)
        : ref.watch(speciesSearchProvider(_searchQuery));

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.pets, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.marineLife_speciesPicker_title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip:
                            context.l10n.marineLife_speciesPicker_closeTooltip,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search field
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText:
                          context.l10n.marineLife_speciesPicker_searchHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              tooltip: context
                                  .l10n
                                  .marineLife_speciesPicker_clearSearchTooltip,
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Category filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: Text(
                            context.l10n.marineLife_speciesPicker_allFilter,
                          ),
                          selected: _selectedCategory == null,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedCategory = null);
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ...SpeciesCategory.values.map((category) {
                          return Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: FilterChip(
                              label: Text(category.displayName),
                              selected: _selectedCategory == category,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedCategory = selected
                                      ? category
                                      : null;
                                });
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Species list
            Expanded(
              child: speciesAsync.when(
                data: (allSpecies) {
                  final filtered = _selectedCategory == null
                      ? allSpecies
                      : allSpecies
                            .where((s) => s.category == _selectedCategory)
                            .toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context
                                .l10n
                                .marineLife_speciesPicker_noSpeciesFound,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    );
                  }

                  // Group by category
                  final grouped = <SpeciesCategory, List<Species>>{};
                  for (final species in filtered) {
                    grouped
                        .putIfAbsent(species.category, () => [])
                        .add(species);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: grouped.length,
                    itemBuilder: (context, index) {
                      final entry = grouped.entries.elementAt(index);
                      return _buildCategorySection(
                        context,
                        entry.key,
                        entry.value,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    context.l10n.marineLife_speciesPicker_error(
                      error.toString(),
                    ),
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
              ),
            ),

            // Footer with selection count and actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    context.l10n.marineLife_speciesPicker_selectedCount(
                      _selectedIds.length,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      context.l10n.marineLife_speciesPicker_cancelButton,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selectedIds),
                    child: Text(
                      context.l10n.marineLife_speciesPicker_doneButton,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    SpeciesCategory category,
    List<Species> species,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            category.displayName,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...species.map((s) => _buildSpeciesTile(context, s)),
      ],
    );
  }

  Widget _buildSpeciesTile(BuildContext context, Species species) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedIds.contains(species.id);

    return CheckboxListTile(
      value: isSelected,
      onChanged: (checked) {
        setState(() {
          if (checked == true) {
            _selectedIds.add(species.id);
          } else {
            _selectedIds.remove(species.id);
          }
        });
      },
      title: Text(species.commonName),
      subtitle: species.scientificName != null
          ? Text(
              species.scientificName!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      secondary: CircleAvatar(
        radius: 16,
        backgroundColor: _getCategoryColor(
          species.category,
        ).withValues(alpha: 0.2),
        child: Icon(
          _getCategoryIcon(species.category),
          size: 18,
          color: _getCategoryColor(species.category),
        ),
      ),
      controlAffinity: ListTileControlAffinity.trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      visualDensity: VisualDensity.compact,
    );
  }

  IconData _getCategoryIcon(SpeciesCategory category) {
    switch (category) {
      case SpeciesCategory.fish:
        return Icons.water;
      case SpeciesCategory.shark:
        return Icons.water;
      case SpeciesCategory.ray:
        return Icons.water;
      case SpeciesCategory.mammal:
        return Icons.water;
      case SpeciesCategory.turtle:
        return Icons.water;
      case SpeciesCategory.invertebrate:
        return Icons.bug_report;
      case SpeciesCategory.coral:
        return Icons.park;
      case SpeciesCategory.plant:
        return Icons.grass;
      case SpeciesCategory.other:
        return Icons.pets;
    }
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
}
