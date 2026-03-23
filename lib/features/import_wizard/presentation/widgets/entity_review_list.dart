import 'package:flutter/material.dart';

import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/duplicate_action_card.dart';

/// A scrollable review list for a single entity type.
///
/// Displays non-duplicate items as selectable checkboxes and duplicate items
/// as [DuplicateActionCard] widgets for per-item action selection.
///
/// Order: non-duplicates first, then likely duplicates (score >= 0.7),
/// then possible duplicates (score >= 0.5).
class EntityReviewList extends StatelessWidget {
  /// The entity group containing items, duplicate indices, and match results.
  final EntityGroup group;

  /// Indices of non-duplicate items that are currently selected.
  final Set<int> selectedIndices;

  /// User-chosen action per duplicate item index.
  final Map<int, DuplicateAction> duplicateActions;

  /// Which action buttons to show inside each [DuplicateActionCard].
  final Set<DuplicateAction> availableActions;

  /// Called when the user toggles a non-duplicate item's checkbox.
  final ValueChanged<int> onToggleSelection;

  /// Called when the user changes the action for a duplicate item.
  final void Function(int index, DuplicateAction action)
  onDuplicateActionChanged;

  /// Called when the user taps "Select All".
  final VoidCallback onSelectAll;

  /// Called when the user taps "Deselect All".
  final VoidCallback onDeselectAll;

  /// Returns the matched existing dive ID for a duplicate item at [index].
  final String Function(int index) existingDiveIdForIndex;

  const EntityReviewList({
    super.key,
    required this.group,
    required this.selectedIndices,
    required this.duplicateActions,
    required this.availableActions,
    required this.onToggleSelection,
    required this.onDuplicateActionChanged,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.existingDiveIdForIndex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final nonDuplicateIndices = _nonDuplicateIndices();
    final likelyDuplicateIndices = _sortedDuplicateIndices(minScore: 0.7);
    final possibleDuplicateIndices = _sortedDuplicateIndices(
      minScore: 0.5,
      maxScore: 0.7,
    );

    final totalItems = group.items.length;
    final duplicateCount = group.duplicateIndices.length;
    final nonDuplicateCount = totalItems - duplicateCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _itemCountText(
                    nonDuplicateCount,
                    duplicateCount,
                    selectedIndices.length,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                onPressed: onSelectAll,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Select All'),
              ),
              TextButton(
                onPressed: onDeselectAll,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Deselect All'),
              ),
            ],
          ),
        ),

        // Non-duplicate items
        if (nonDuplicateIndices.isNotEmpty) ...[
          for (final index in nonDuplicateIndices)
            _NonDuplicateRow(
              item: group.items[index],
              index: index,
              isSelected: selectedIndices.contains(index),
              onToggle: () => onToggleSelection(index),
            ),
        ],

        // Likely duplicates section
        if (likelyDuplicateIndices.isNotEmpty) ...[
          _SectionLabel(label: 'Likely Duplicates', color: colorScheme.error),
          for (final index in likelyDuplicateIndices)
            _buildDuplicateCard(index),
        ],

        // Possible duplicates section
        if (possibleDuplicateIndices.isNotEmpty) ...[
          const _SectionLabel(
            label: 'Possible Duplicates',
            color: Colors.orange,
          ),
          for (final index in possibleDuplicateIndices)
            _buildDuplicateCard(index),
        ],
      ],
    );
  }

  Widget _buildDuplicateCard(int index) {
    final item = group.items[index];
    final matchResult = group.matchResults![index]!;
    final action =
        duplicateActions[index] ??
        (matchResult.isProbable
            ? DuplicateAction.skip
            : DuplicateAction.importAsNew);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DuplicateActionCard(
        item: item,
        matchResult: matchResult,
        selectedAction: action,
        availableActions: availableActions,
        onActionChanged: (a) => onDuplicateActionChanged(index, a),
        existingDiveId: existingDiveIdForIndex(index),
      ),
    );
  }

  List<int> _nonDuplicateIndices() {
    return [
      for (int i = 0; i < group.items.length; i++)
        if (!group.duplicateIndices.contains(i)) i,
    ];
  }

  /// Returns duplicate indices filtered by score range, sorted descending by
  /// score.
  List<int> _sortedDuplicateIndices({
    required double minScore,
    double maxScore = double.infinity,
  }) {
    final matchResults = group.matchResults;
    if (matchResults == null) return [];

    final indices = <int>[];
    for (final index in group.duplicateIndices) {
      final result = matchResults[index];
      if (result == null) continue;
      if (result.score >= minScore && result.score < maxScore) {
        indices.add(index);
      }
    }

    indices.sort((a, b) {
      final scoreA = matchResults[a]?.score ?? 0;
      final scoreB = matchResults[b]?.score ?? 0;
      return scoreB.compareTo(scoreA);
    });

    return indices;
  }

  String _itemCountText(int nonDuplicates, int duplicates, int selectedCount) {
    final parts = <String>[];
    if (nonDuplicates > 0) {
      parts.add('$selectedCount / $nonDuplicates selected');
    }
    if (duplicates > 0) {
      parts.add('$duplicates duplicate${duplicates == 1 ? '' : 's'}');
    }
    return parts.join(' \u00b7 ');
  }
}

class _NonDuplicateRow extends StatelessWidget {
  final EntityItem item;
  final int index;
  final bool isSelected;
  final VoidCallback onToggle;

  const _NonDuplicateRow({
    required this.item,
    required this.index,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: isSelected,
      onChanged: (_) => onToggle(),
      title: Text(item.title),
      subtitle: Text(item.subtitle),
      secondary: item.icon != null ? Icon(item.icon) : null,
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
