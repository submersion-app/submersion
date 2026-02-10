import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_picker_dialog.dart';

/// Section widget displaying marine life at a dive site
class SiteMarineLifeSection extends ConsumerWidget {
  final String siteId;
  final bool readOnly;

  const SiteMarineLifeSection({
    super.key,
    required this.siteId,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spottedAsync = ref.watch(siteSpottedSpeciesProvider(siteId));
    final expectedAsync = ref.watch(siteExpectedSpeciesProvider(siteId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            _buildSpottedSection(context, ref, spottedAsync),
            const SizedBox(height: 16),
            _buildExpectedSection(context, ref, expectedAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(Icons.water, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text('Marine Life', style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }

  Widget _buildSpottedSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<SiteSpeciesSummary>> spottedAsync,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.visibility,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              'Spotted Here',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        spottedAsync.when(
          data: (spotted) {
            if (spotted.isEmpty) {
              return Text(
                'No marine life spotted yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              );
            }
            return _buildSpeciesChips(
              context,
              spotted
                  .map(
                    (s) => _SpeciesChipData(
                      id: s.speciesId,
                      name: s.speciesName,
                      category: s.category,
                      count: s.sightingCount,
                    ),
                  )
                  .toList(),
              showCount: true,
            );
          },
          loading: () => const SizedBox(
            height: 32,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (error, stack) => Text(
            'Error loading sightings',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colorScheme.error),
          ),
        ),
      ],
    );
  }

  Widget _buildExpectedSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<SiteSpeciesEntry>> expectedAsync,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_awesome,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Expected Species',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (!readOnly)
              IconButton(
                icon: Icon(Icons.edit, size: 18, color: colorScheme.primary),
                visualDensity: VisualDensity.compact,
                tooltip: 'Edit expected species',
                onPressed: () => _showSpeciesPicker(context, ref),
              ),
          ],
        ),
        const SizedBox(height: 8),
        expectedAsync.when(
          data: (expected) {
            if (expected.isEmpty) {
              return Text(
                'No expected species added',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              );
            }
            return _buildSpeciesChips(
              context,
              expected
                  .map(
                    (s) => _SpeciesChipData(
                      id: s.speciesId,
                      name: s.speciesName,
                      category: s.category,
                    ),
                  )
                  .toList(),
              showCount: false,
            );
          },
          loading: () => const SizedBox(
            height: 32,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (error, stack) => Text(
            'Error loading expected species',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colorScheme.error),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeciesChips(
    BuildContext context,
    List<_SpeciesChipData> species, {
    required bool showCount,
  }) {
    // Group by category
    final grouped = <SpeciesCategory, List<_SpeciesChipData>>{};
    for (final s in species) {
      grouped.putIfAbsent(s.category, () => []).add(s);
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.key.displayName,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: entry.value.map((s) {
                  final chipLabel = showCount && s.count != null
                      ? '${s.name}, spotted ${s.count} times'
                      : s.name;
                  return Semantics(
                    label: chipLabel,
                    child: Chip(
                      avatar: ExcludeSemantics(
                        child: Icon(
                          _getCategoryIcon(s.category),
                          size: 16,
                          color: _getCategoryColor(s.category),
                        ),
                      ),
                      label: Text(
                        showCount && s.count != null
                            ? '${s.name} (${s.count})'
                            : s.name,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _showSpeciesPicker(BuildContext context, WidgetRef ref) async {
    final expected = ref.read(siteExpectedSpeciesProvider(siteId)).valueOrNull;
    final selectedIds = expected?.map((e) => e.speciesId).toSet() ?? {};

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => SpeciesPickerDialog(initialSelection: selectedIds),
    );

    if (result != null) {
      final notifier = ref.read(
        siteExpectedSpeciesNotifierProvider(siteId).notifier,
      );
      await notifier.setSpecies(result.toList());
      ref.invalidate(siteExpectedSpeciesProvider(siteId));
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

class _SpeciesChipData {
  final String id;
  final String name;
  final SpeciesCategory category;
  final int? count;

  _SpeciesChipData({
    required this.id,
    required this.name,
    required this.category,
    this.count,
  });
}
