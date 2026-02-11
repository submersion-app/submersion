import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class SpeciesManagePage extends ConsumerStatefulWidget {
  const SpeciesManagePage({super.key});

  @override
  ConsumerState<SpeciesManagePage> createState() => _SpeciesManagePageState();
}

class _SpeciesManagePageState extends ConsumerState<SpeciesManagePage> {
  String _searchQuery = '';
  SpeciesCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final speciesAsync = ref.watch(speciesListNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.marineLife_speciesManage_appBarTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: context.l10n.marineLife_speciesManage_backTooltip,
          onPressed: () => context.pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'reset') {
                _confirmResetDefaults(context, ref);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'reset',
                child: Text(
                  context.l10n.marineLife_speciesManage_resetToDefaults,
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/species/new'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryFilter(),
          Expanded(
            child: speciesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (allSpecies) => _buildSpeciesList(allSpecies),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        decoration: InputDecoration(
          hintText: context.l10n.marineLife_speciesManage_searchHint,
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true,
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip:
                      context.l10n.marineLife_speciesManage_clearSearchTooltip,
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: const Text('All'),
            selected: _selectedCategory == null,
            onSelected: (_) => setState(() => _selectedCategory = null),
          ),
          const SizedBox(width: 8),
          ...SpeciesCategory.values.map((category) {
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilterChip(
                label: Text(category.displayName),
                selected: _selectedCategory == category,
                onSelected: (_) => setState(
                  () => _selectedCategory = _selectedCategory == category
                      ? null
                      : category,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSpeciesList(List<Species> allSpecies) {
    var filtered = allSpecies;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((s) {
        return s.commonName.toLowerCase().contains(query) ||
            (s.scientificName?.toLowerCase().contains(query) ?? false) ||
            (s.taxonomyClass?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    if (_selectedCategory != null) {
      filtered = filtered
          .where((s) => s.category == _selectedCategory)
          .toList();
    }

    if (filtered.isEmpty) {
      return const Center(child: Text('No species found'));
    }

    final customSpecies = filtered.where((s) => !s.isBuiltIn).toList();
    final builtInSpecies = filtered.where((s) => s.isBuiltIn).toList();

    return ListView(
      children: [
        if (customSpecies.isNotEmpty) ...[
          _buildSectionHeader('Custom Species (${customSpecies.length})'),
          ...customSpecies.map(
            (species) => _buildSpeciesTile(species, isCustom: true),
          ),
          if (builtInSpecies.isNotEmpty) const Divider(),
        ],
        if (builtInSpecies.isNotEmpty) ...[
          _buildSectionHeader('Built-in Species (${builtInSpecies.length})'),
          ...builtInSpecies.map(
            (species) => _buildSpeciesTile(species, isCustom: false),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSpeciesTile(Species species, {required bool isCustom}) {
    return ListTile(
      leading: Icon(
        _getCategoryIcon(species.category),
        color: _getCategoryColor(species.category),
      ),
      title: Text(species.commonName),
      subtitle: species.scientificName != null
          ? Text(
              species.scientificName!,
              style: const TextStyle(fontStyle: FontStyle.italic),
            )
          : Text(species.category.displayName),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit species',
            onPressed: () => context.push('/species/${species.id}/edit'),
          ),
          if (isCustom)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete species',
              onPressed: () => _confirmDelete(species),
            ),
        ],
      ),
      onTap: () => context.push('/species/${species.id}'),
    );
  }

  Future<void> _confirmDelete(Species species) async {
    final notifier = ref.read(speciesListNotifierProvider.notifier);
    final inUse = await notifier.isSpeciesInUse(species.id);

    if (!mounted) return;

    if (inUse) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot delete "${species.commonName}" - it has sightings',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Species?'),
        content: Text(
          'Are you sure you want to delete "${species.commonName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await notifier.deleteSpecies(species.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted "${species.commonName}"')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting species: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmResetDefaults(BuildContext ctx, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Reset to Defaults?'),
        content: const Text(
          'This will restore all built-in species to their original values. '
          'Custom species will not be affected. '
          'Built-in species with existing sightings will be updated but preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final notifier = ref.read(speciesListNotifierProvider.notifier);
        await notifier.resetBuiltInSpecies();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Built-in species restored to defaults'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error resetting species: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
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
