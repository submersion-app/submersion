import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart' as enums;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/features/universal_import/presentation/widgets/batch_tag_field.dart';
import 'package:submersion/features/universal_import/presentation/widgets/import_dive_card.dart';
import 'package:submersion/features/universal_import/presentation/widgets/import_entity_card.dart';

/// Step 3: Tabbed entity selection with duplicate detection.
///
/// Dynamically creates tabs based on which entity types the parser produced.
/// Each tab shows a list of items with selection checkboxes and duplicate
/// badges. Includes batch tag field and import button.
class ImportReviewStep extends ConsumerWidget {
  const ImportReviewStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(universalImportNotifierProvider);
    final theme = Theme.of(context);
    final payload = state.payload;

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (payload == null) return const SizedBox.shrink();

    final types = state.availableTypes;
    if (types.isEmpty) return const SizedBox.shrink();

    return DefaultTabController(
      length: types.length,
      child: Column(
        children: [
          // Duplicate summary banner
          if (state.duplicateResult?.hasDuplicates == true)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: theme.colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${state.duplicateResult!.totalDuplicates} '
                          'duplicates found and auto-deselected.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Batch tag field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: BatchTagField(
              initialValue: state.options?.batchTag,
              onChanged: (tag) => ref
                  .read(universalImportNotifierProvider.notifier)
                  .updateBatchTag(tag),
            ),
          ),

          // Entity type tabs
          TabBar(
            isScrollable: types.length > 4,
            tabs: types.map((type) {
              final count = state.totalCountFor(type);
              return Tab(text: '${type.shortName} ($count)');
            }).toList(),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              children: types.map((type) {
                return _EntityTypeList(type: type);
              }).toList(),
            ),
          ),

          // Bottom bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    '${state.totalSelected} selected',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: state.totalSelected > 0
                        ? () => ref
                              .read(universalImportNotifierProvider.notifier)
                              .performImport()
                        : null,
                    child: const Text('Import'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Entity list for a single tab in the review step.
class _EntityTypeList extends ConsumerWidget {
  const _EntityTypeList({required this.type});

  final ImportEntityType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(universalImportNotifierProvider);
    final theme = Theme.of(context);
    final items = state.payload?.entitiesOf(type) ?? [];
    final selection = state.selectionFor(type);
    final notifier = ref.read(universalImportNotifierProvider.notifier);

    return Column(
      children: [
        // Select/deselect all
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${selection.length} of ${items.length} selected',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: selection.length == items.length
                    ? () => notifier.deselectAll(type)
                    : () => notifier.selectAll(type),
                child: Text(
                  selection.length == items.length
                      ? 'Deselect All'
                      : 'Select All',
                ),
              ),
            ],
          ),
        ),
        // Item list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isSelected = selection.contains(index);
              final dupResult = state.duplicateResult;

              if (type == ImportEntityType.dives) {
                return ImportDiveCard(
                  diveData: item,
                  index: index,
                  isSelected: isSelected,
                  onToggle: () => notifier.toggleSelection(type, index),
                  matchResult: dupResult?.diveMatchFor(index),
                );
              }

              final isDuplicate = dupResult?.isDuplicate(type, index) ?? false;

              return ImportEntityCard(
                name: _getName(item),
                subtitle: _getSubtitle(item),
                icon: _iconFor(type),
                isSelected: isSelected,
                onToggle: () => notifier.toggleSelection(type, index),
                isDuplicate: isDuplicate,
              );
            },
          ),
        ),
      ],
    );
  }

  String _getName(Map<String, dynamic> item) {
    return (item['name'] as String?) ?? 'Unnamed';
  }

  String? _getSubtitle(Map<String, dynamic> item) {
    return switch (type) {
      ImportEntityType.sites => _formatLocation(
        item['latitude'] as double?,
        item['longitude'] as double?,
      ),
      ImportEntityType.equipment =>
        (item['type'] as enums.EquipmentType?)?.displayName,
      ImportEntityType.certifications =>
        (item['agency'] as enums.CertificationAgency?)?.displayName,
      ImportEntityType.courses => item['agency'] as String?,
      ImportEntityType.diveCenters =>
        item['country'] as String? ?? item['city'] as String?,
      _ => null,
    };
  }

  String? _formatLocation(double? lat, double? lon) {
    if (lat == null || lon == null) return null;
    return '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';
  }

  static IconData _iconFor(ImportEntityType type) {
    return switch (type) {
      ImportEntityType.dives => Icons.scuba_diving,
      ImportEntityType.sites => Icons.location_on_outlined,
      ImportEntityType.trips => Icons.card_travel,
      ImportEntityType.equipment => Icons.build_outlined,
      ImportEntityType.equipmentSets => Icons.inventory_2_outlined,
      ImportEntityType.buddies => Icons.person_outline,
      ImportEntityType.diveCenters => Icons.store_outlined,
      ImportEntityType.certifications => Icons.workspace_premium_outlined,
      ImportEntityType.courses => Icons.school_outlined,
      ImportEntityType.tags => Icons.label_outline,
      ImportEntityType.diveTypes => Icons.category_outlined,
    };
  }
}
