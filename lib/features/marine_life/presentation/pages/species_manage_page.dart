import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selectable_list_scope.dart';
import 'package:submersion/shared/selection/selection_app_bar.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_leading.dart';
import 'package:submersion/shared/selection/selection_state.dart';

class SpeciesManagePage extends ConsumerStatefulWidget {
  const SpeciesManagePage({super.key});

  @override
  ConsumerState<SpeciesManagePage> createState() => _SpeciesManagePageState();
}

class _SpeciesManagePageState extends ConsumerState<SpeciesManagePage> {
  String _searchQuery = '';
  SpeciesCategory? _selectedCategory;

  /// Owns the bulk-selection state machine for this page.
  final SelectionController _selection = SelectionController();

  /// Convenience mirrors of the controller, so the widget tree reads clearly.
  bool get _isSelectionMode => _selection.value.isActive;
  Set<String> get _selectedIds => _selection.value.checkedIds;

  /// Sighting counts, prefetched once for the whole list.
  ///
  /// "Has sightings" is a database count, so it cannot be a synchronous
  /// predicate the way isBuiltIn can. Prefetching lets an in-use species
  /// render without a checkbox instead of failing at delete time.
  Map<String, int> _sightingCounts = const {};

  /// A species is selectable only if it is custom and unreferenced -- exactly
  /// the two conditions SpeciesRepository.deleteSpecies enforces.
  bool _isSelectable(Species s) =>
      !s.isBuiltIn && (_sightingCounts[s.id] ?? 0) == 0;

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speciesAsync = ref.watch(speciesListNotifierProvider);
    _sightingCounts =
        ref.watch(speciesSightingCountsProvider).value ?? const {};

    final selectableIds = _visibleSpecies(
      speciesAsync.value ?? const [],
    ).where(_isSelectable).map((s) => s.id).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selection.pruneTo(selectableIds);
    });

    return SelectableListScope(
      controller: _selection,
      selectableIds: selectableIds,
      child: ValueListenableBuilder<SelectionState>(
        valueListenable: _selection,
        builder: (context, selection, _) => Scaffold(
          appBar: selection.isActive
              ? SelectionAppBar(
                  controller: _selection,
                  selectableIds: selectableIds,
                  actions: const [],
                  shell: SelectionBarShell.appBar,
                  onDelete: _confirmAndDeleteSelected,
                )
              : AppBar(
                  title: Text(
                    context.l10n.marineLife_speciesManage_appBarTitle,
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: context.l10n.marineLife_speciesManage_backTooltip,
                    onPressed: () => context.pop(),
                  ),
                  actions: [
                    IconButton(
                      key: const ValueKey('enter_selection'),
                      icon: const Icon(Icons.checklist),
                      tooltip: context.l10n.common_selection_enterTooltip,
                      onPressed: _selection.enterExplicit,
                    ),
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
                            context
                                .l10n
                                .marineLife_speciesManage_resetToDefaults,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
          floatingActionButton: selection.isActive
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => context.push('/species/new'),
                  tooltip: context.l10n.marineLife_speciesEdit_addTitle,
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.marineLife_speciesEdit_addTitle),
                ),
          body: Column(
            children: [
              _buildSearchBar(),
              _buildCategoryFilter(),
              Expanded(
                child: speciesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(
                    child: Text(
                      context.l10n.marineLife_speciesManage_errorLoading(
                        e.toString(),
                      ),
                    ),
                  ),
                  data: (allSpecies) => _buildSpeciesList(allSpecies),
                ),
              ),
            ],
          ),
        ),
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
            label: Text(context.l10n.marineLife_speciesManage_allFilter),
            selected: _selectedCategory == null,
            onSelected: (_) => setState(() => _selectedCategory = null),
          ),
          const SizedBox(width: 8),
          ...SpeciesCategory.values.map((category) {
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilterChip(
                label: Text(category.localizedName(context.l10n)),
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

  /// Species matching the active search query and category filter.
  ///
  /// Shared by the list and by the pruning in [build] so the selection can
  /// never hold a species the filter has hidden.
  List<Species> _visibleSpecies(List<Species> allSpecies) {
    var filtered = allSpecies;

    if (_searchQuery.isNotEmpty) {
      final l10n = context.l10n;
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((s) {
        // Built-in rows render their translated name, so the diver's query
        // has to match that as well as the English column the database
        // stores -- otherwise searching in your own language finds nothing.
        return s.commonName.toLowerCase().contains(query) ||
            s.localizedCommonName(l10n).toLowerCase().contains(query) ||
            (s.scientificName?.toLowerCase().contains(query) ?? false) ||
            (s.taxonomyClass?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    if (_selectedCategory != null) {
      filtered = filtered
          .where((s) => s.category == _selectedCategory)
          .toList();
    }
    return filtered;
  }

  Widget _buildSpeciesList(List<Species> allSpecies) {
    final filtered = _visibleSpecies(allSpecies);

    if (filtered.isEmpty) {
      return Center(
        child: Text(context.l10n.marineLife_speciesManage_noSpeciesFound),
      );
    }

    final customSpecies = filtered.where((s) => !s.isBuiltIn).toList();
    final builtInSpecies = filtered.where((s) => s.isBuiltIn).toList();

    return ListView(
      children: [
        if (customSpecies.isNotEmpty) ...[
          _buildSectionHeader(
            context.l10n.marineLife_speciesManage_customSpeciesHeader(
              customSpecies.length,
            ),
          ),
          ...customSpecies.map(
            (species) => _buildSpeciesTile(species, isCustom: true),
          ),
          if (builtInSpecies.isNotEmpty) const Divider(),
        ],
        if (builtInSpecies.isNotEmpty) ...[
          _buildSectionHeader(
            context.l10n.marineLife_speciesManage_builtInSpeciesHeader(
              builtInSpecies.length,
            ),
          ),
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
      leading: SelectionLeading(
        isSelectionMode: _isSelectionMode,
        isChecked: _selectedIds.contains(species.id),
        // Built-in species and species with sightings are exactly what
        // deleteSpecies refuses, so neither gets a checkbox.
        isSelectable: _isSelectable(species),
        onChanged: (_) => _selection.toggle(species.id),
        child: Icon(
          iconForSpeciesCategory(species.category),
          color: _getCategoryColor(species.category),
        ),
      ),
      title: Text(species.localizedCommonName(context.l10n)),
      subtitle: species.scientificName != null
          ? Text(
              species.scientificName!,
              style: const TextStyle(fontStyle: FontStyle.italic),
            )
          : Text(species.category.localizedName(context.l10n)),
      // Per-row actions yield to selection mode. Leaving the trash here would
      // put a one-tap delete beside the checkbox while the bulk delete sits
      // deliberately behind the selection bar's overflow -- two contradictory
      // answers to how destructive an action delete is on this screen.
      trailing: _isSelectionMode
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: context.l10n.marineLife_speciesManage_editTooltip,
                  onPressed: () => context.push('/species/${species.id}/edit'),
                ),
                if (isCustom)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip:
                        context.l10n.marineLife_speciesManage_deleteTooltip,
                    onPressed: () => _confirmDelete(species),
                  ),
              ],
            ),
      onTap: () {
        if (_isSelectionMode) {
          if (_isSelectable(species)) _selection.toggle(species.id);
          return;
        }
        context.push('/species/${species.id}');
      },
    );
  }

  Future<void> _confirmAndDeleteSelected() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.common_bulkDelete_title(ids.length)),
        content: Text(ctx.l10n.common_bulkDelete_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(ctx.l10n.common_action_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(speciesListNotifierProvider.notifier);
    _selection.exit();

    // Selection excludes in-use species, but the counts are a prefetched
    // snapshot: a sighting added since the list loaded makes deleteSpecies
    // throw. Without this guard one such species would abort the whole loop
    // and leave the rest silently undeleted.
    var deleted = 0;
    Object? failure;
    for (final id in ids) {
      try {
        await notifier.deleteSpecies(id);
        deleted++;
      } catch (e) {
        failure ??= e;
      }
    }

    if (!mounted) return;
    ref.invalidate(speciesSightingCountsProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failure == null
              ? context.l10n.common_bulkDelete_snackbar(deleted)
              : context.l10n.marineLife_species_delete_error(
                  failure.toString(),
                ),
        ),
      ),
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
            context.l10n.marineLife_species_delete_inUseError(
              species.localizedCommonName(context.l10n),
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.marineLife_species_delete_confirmTitle),
        content: Text(
          context.l10n.marineLife_species_delete_confirmBody(
            species.localizedCommonName(context.l10n),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.marineLife_speciesManage_cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.marineLife_speciesManage_deleteButton),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await notifier.deleteSpecies(species.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.marineLife_species_delete_snackbar(
                  species.localizedCommonName(context.l10n),
                ),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.marineLife_species_delete_error(e.toString()),
              ),
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
        title: Text(ctx.l10n.marineLife_speciesManage_resetDialogTitle),
        content: Text(ctx.l10n.marineLife_speciesManage_resetDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(ctx.l10n.marineLife_speciesManage_cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(ctx.l10n.marineLife_speciesManage_resetButton),
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
            SnackBar(
              content: Text(context.l10n.marineLife_speciesManage_resetSuccess),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.marineLife_speciesManage_errorResetting(
                  e.toString(),
                ),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
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
