import 'package:flutter/material.dart';

import 'package:submersion/core/presentation/widgets/dive_sparkline.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/entity_match_result.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/duplicate_action_card.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/needs_decision_pill.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A scrollable review list for a single entity type.
///
/// Displays non-duplicate items as selectable checkboxes and duplicate items
/// as [DuplicateActionCard] widgets for per-item action selection.
///
/// Order: likely duplicates (score >= 0.7), then possible duplicates
/// (score >= 0.5), then non-duplicates. Duplicates appear first so rows
/// needing a user decision aren't buried beneath clean imports.
class EntityReviewList extends StatelessWidget {
  /// The entity group containing items, duplicate indices, and match results.
  final EntityGroup group;

  /// Indices of non-duplicate items that are currently selected.
  final Set<int> selectedIndices;

  /// User-chosen action per duplicate item index.
  final Map<int, DuplicateAction> duplicateActions;

  /// Which action buttons to show inside each [DuplicateActionCard].
  final Set<DuplicateAction> availableActions;

  /// Indices of duplicate items still awaiting an explicit user decision.
  ///
  /// Drives pending-first sorting inside each duplicate section, visual
  /// pending state on the duplicate cards, and the visibility of the bulk
  /// action row.
  final Set<int> pendingIndices;

  /// Called when the user toggles a non-duplicate item's checkbox.
  final ValueChanged<int> onToggleSelection;

  /// Called when the user changes the action for a duplicate item.
  final void Function(int index, DuplicateAction action)
  onDuplicateActionChanged;

  /// Called when the user taps a bulk action button.
  final void Function(DuplicateAction action) onBulkAction;

  /// Called when the user taps "Select All".
  final VoidCallback onSelectAll;

  /// Called when the user taps "Deselect All".
  final VoidCallback onDeselectAll;

  /// Returns the matched existing dive ID for a duplicate item at [index].
  final String Function(int index) existingDiveIdForIndex;

  /// Optional projected dive numbers keyed by item index.
  ///
  /// When provided, each row shows a `#N` badge indicating the dive number
  /// that will be assigned on import. Only meaningful for dive entity lists.
  final Map<int, int>? projectedDiveNumbers;

  const EntityReviewList({
    super.key,
    required this.group,
    required this.selectedIndices,
    required this.duplicateActions,
    required this.availableActions,
    this.pendingIndices = const {},
    required this.onToggleSelection,
    required this.onDuplicateActionChanged,
    this.onBulkAction = _noopBulkAction,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.existingDiveIdForIndex,
    this.projectedDiveNumbers,
  });

  static void _noopBulkAction(DuplicateAction _) {}

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

        // Bulk action row (only when there are pending duplicates).
        if (pendingIndices.isNotEmpty)
          _BulkActionRow(
            isDiveTab: _isDiveTab(),
            pendingCount: pendingIndices.length,
            matchableConsolidateCount: _matchableConsolidateCount(),
            availableActions: availableActions,
            onBulkAction: onBulkAction,
          ),

        // Scored duplicates (dives with matchResults) appear first so rows
        // that need user attention are at the top of the tab.
        if (likelyDuplicateIndices.isNotEmpty) ...[
          _SectionLabel(
            label: 'Potential Duplicates',
            color: colorScheme.error,
          ),
          for (final index in likelyDuplicateIndices)
            _buildDuplicateCard(index),
        ],

        if (possibleDuplicateIndices.isNotEmpty) ...[
          const _SectionLabel(
            label: 'Possible Duplicates',
            color: Colors.orange,
          ),
          for (final index in possibleDuplicateIndices)
            _buildDuplicateCard(index),
        ],

        // Unscored duplicates (non-dive entities without matchResults)
        if (_unscoredDuplicateIndices().isNotEmpty) ...[
          _SectionLabel(
            label: 'Potential Duplicates',
            color: colorScheme.error,
          ),
          for (final index in _unscoredDuplicateIndices())
            _buildEntityDuplicateCard(index),
        ],

        // Non-duplicate items (no conflicts — listed after duplicates so the
        // rows requiring decisions aren't buried beneath clean imports).
        if (nonDuplicateIndices.isNotEmpty) ...[
          for (final index in nonDuplicateIndices)
            _NonDuplicateRow(
              item: group.items[index],
              index: index,
              isSelected: selectedIndices.contains(index),
              onToggle: () => onToggleSelection(index),
              projectedDiveNumber: projectedDiveNumbers?[index],
            ),
        ],
      ],
    );
  }

  Widget _buildDuplicateCard(int index) {
    final item = group.items[index];
    final matchResult = group.matchResults![index]!;
    // Pass the user's chosen action verbatim — including `null`, which means
    // the user has not yet decided. Falling back to a default here would
    // contradict the "Needs decision" pending state and pre-highlight a
    // button the user did not pick.
    final action = duplicateActions[index];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DuplicateActionCard(
        item: item,
        matchResult: matchResult,
        selectedAction: action,
        availableActions: availableActions,
        onActionChanged: (a) => onDuplicateActionChanged(index, a),
        existingDiveId: existingDiveIdForIndex(index),
        projectedDiveNumber: projectedDiveNumbers?[index],
        isPending: pendingIndices.contains(index),
      ),
    );
  }

  List<int> _nonDuplicateIndices() {
    return [
      for (int i = 0; i < group.items.length; i++)
        if (!group.duplicateIndices.contains(i)) i,
    ];
  }

  /// Returns duplicate indices filtered by score range.
  ///
  /// Pending-review indices are emitted first (preserving their
  /// enumeration order from [group.duplicateIndices]). The remaining
  /// non-pending indices are then sorted descending by match score.
  List<int> _sortedDuplicateIndices({
    required double minScore,
    double maxScore = double.infinity,
  }) {
    final matchResults = group.matchResults;
    if (matchResults == null) return const [];

    final all = <int>[];
    for (final index in group.duplicateIndices) {
      final result = matchResults[index];
      if (result == null) continue;
      if (result.score >= minScore && result.score < maxScore) {
        all.add(index);
      }
    }

    final pendingFirst = all.where(pendingIndices.contains).toList();
    final rest = all.where((i) => !pendingIndices.contains(i)).toList();
    rest.sort((a, b) {
      final scoreA = matchResults[a]?.score ?? 0;
      final scoreB = matchResults[b]?.score ?? 0;
      return scoreB.compareTo(scoreA);
    });

    return [...pendingFirst, ...rest];
  }

  /// Returns duplicate indices that have no match score (non-dive entities).
  ///
  /// Pending-review indices are emitted first, in ascending index order; the
  /// remaining non-pending indices follow in ascending index order.
  List<int> _unscoredDuplicateIndices() {
    final matchResults = group.matchResults;
    if (matchResults != null) {
      // Entities with matchResults are handled by _sortedDuplicateIndices.
      return const [];
    }
    final sorted = group.duplicateIndices.toList()..sort();
    final pendingFirst = sorted.where(pendingIndices.contains).toList();
    final rest = sorted.where((i) => !pendingIndices.contains(i)).toList();
    return [...pendingFirst, ...rest];
  }

  Widget _buildEntityDuplicateCard(int index) {
    final item = group.items[index];
    // Pass the user's chosen action verbatim — `null` means "not yet decided"
    // and is rendered as a pending row with no pre-selected button.
    final action = duplicateActions[index];
    final entityMatch = group.entityMatches?[index];

    return _EntityDuplicateCard(
      item: item,
      entityMatch: entityMatch,
      selectedAction: action,
      onActionChanged: (a) => onDuplicateActionChanged(index, a),
      isPending: pendingIndices.contains(index),
    );
  }

  /// Whether this group represents the dive tab.
  ///
  /// A group is a "dive tab" if at least one item carries dive data. This
  /// controls the bulk-action label variant (Import all as new vs Import all).
  bool _isDiveTab() {
    if (group.items.isEmpty) return false;
    return group.items.any((item) => item.diveData != null);
  }

  /// Number of pending rows whose match score is high enough (>= 0.7) to
  /// qualify for bulk consolidation.
  int _matchableConsolidateCount() {
    final matchResults = group.matchResults;
    if (matchResults == null) return 0;
    return pendingIndices
        .where((i) => (matchResults[i]?.score ?? 0) >= 0.7)
        .length;
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
  final int? projectedDiveNumber;

  const _NonDuplicateRow({
    required this.item,
    required this.index,
    required this.isSelected,
    required this.onToggle,
    this.projectedDiveNumber,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Checkbox
            Checkbox(
              value: isSelected,
              onChanged: (_) => onToggle(),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 4),
            // Optional icon
            if (item.icon != null) ...[
              Icon(item.icon, size: 20, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
            ],
            // Dive number badge (centered vertically between title and subtitle)
            if (projectedDiveNumber != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#$projectedDiveNumber',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            // Title + subtitle column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.subtitle.isNotEmpty)
                    Text(
                      item.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Dive profile sparkline (only when profile data exists)
            if (item.diveData != null && item.diveData!.profile.isNotEmpty) ...[
              const SizedBox(width: 4),
              DiveSparkline(profile: item.diveData!.profile),
            ],
            const SizedBox(width: 8),
            // Import/Skip badge
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green, width: 1),
                ),
                child: Text(
                  'IMPORT',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: colorScheme.onSurface.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  'SKIP',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// An expandable card for a non-dive duplicate entity.
///
/// Collapsed state shows the entity name, subtitle, action badge, and a
/// chevron to expand. Expanded state adds a two-column comparison table
/// showing existing vs incoming field values, plus Skip/Import action buttons.
class _EntityDuplicateCard extends StatefulWidget {
  final EntityItem item;
  final EntityMatchResult? entityMatch;

  /// The action chosen for this row, or `null` when the user has not yet
  /// decided. Null suppresses the action badge in the collapsed header and
  /// leaves both action buttons outlined in the expanded panel.
  final DuplicateAction? selectedAction;
  final ValueChanged<DuplicateAction> onActionChanged;

  /// Whether this row still needs an explicit user decision.
  ///
  /// When true the card renders a warning-colored 1.5-px border and a
  /// [NeedsDecisionPill] in its header.
  final bool isPending;

  const _EntityDuplicateCard({
    required this.item,
    required this.entityMatch,
    required this.selectedAction,
    required this.onActionChanged,
    this.isPending = false,
  });

  @override
  State<_EntityDuplicateCard> createState() => _EntityDuplicateCardState();
}

class _EntityDuplicateCardState extends State<_EntityDuplicateCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isImporting = widget.selectedAction == DuplicateAction.importAsNew;
    // When [selectedAction] is null (row pending a decision) we fall back to
    // the tertiary warning colour so the border reads as "undecided" rather
    // than implying a skip. The pending branch below also uses tertiary, so
    // this fallback only matters for the rare non-pending-null case.
    final Color borderColor;
    if (widget.selectedAction == null) {
      borderColor = colorScheme.tertiary;
    } else if (isImporting) {
      borderColor = Colors.green;
    } else {
      borderColor = colorScheme.error;
    }

    final BorderSide borderSide = widget.isPending
        ? BorderSide(color: colorScheme.tertiary, width: 1.5)
        : BorderSide(color: borderColor, width: 1.5);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: borderSide,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Collapsed header
            InkWell(
              borderRadius: widget.entityMatch != null
                  ? const BorderRadius.vertical(top: Radius.circular(12))
                  : BorderRadius.circular(12),
              onTap: widget.entityMatch != null
                  ? () => setState(() => _expanded = !_expanded)
                  : () => widget.onActionChanged(
                      // First tap on an undecided row (null) defaults to
                      // importAsNew; otherwise toggle between the two states.
                      isImporting
                          ? DuplicateAction.skip
                          : DuplicateAction.importAsNew,
                    ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    // Icon
                    if (widget.item.icon != null) ...[
                      Icon(
                        widget.item.icon,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                    ],
                    // Title + subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.item.subtitle.isNotEmpty)
                            Text(
                              widget.item.subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    // Needs-decision pill — only shown when this row is pending.
                    if (widget.isPending) ...[
                      const SizedBox(width: 8),
                      NeedsDecisionPill(colorScheme: colorScheme),
                    ],
                    // Action badge — suppressed when no decision has been made.
                    if (widget.selectedAction != null) ...[
                      const SizedBox(width: 8),
                      _SimpleActionBadge(isImporting: isImporting),
                    ],
                    // Expand/collapse chevron (only when comparison data exists)
                    if (widget.entityMatch != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Expanded comparison
            if (_expanded && widget.entityMatch != null)
              _EntityComparisonPanel(
                entityMatch: widget.entityMatch!,
                selectedAction: widget.selectedAction,
                onActionChanged: widget.onActionChanged,
                isPending: widget.isPending,
              ),
          ],
        ),
      ),
    );
  }
}

/// The expanded comparison panel showing existing vs incoming fields.
class _EntityComparisonPanel extends StatelessWidget {
  final EntityMatchResult entityMatch;

  /// The currently selected action, or `null` when the row is still pending a
  /// decision. Null leaves both action buttons outlined (no pre-highlight).
  final DuplicateAction? selectedAction;
  final ValueChanged<DuplicateAction> onActionChanged;

  /// Whether the enclosing row still needs an explicit user decision.
  ///
  /// When `true` AND [selectedAction] is `null`, a "Choose an action" label
  /// is rendered above the action-button row.
  final bool isPending;

  const _EntityComparisonPanel({
    required this.entityMatch,
    required this.selectedAction,
    required this.onActionChanged,
    this.isPending = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Collect all field labels from both maps to handle asymmetric data.
    final labels = <String>{
      ...entityMatch.existingFields.keys,
      ...entityMatch.incomingFields.keys,
    };

    final showChooseLabel = isPending && selectedAction == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        // Column headers
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              const SizedBox(width: 80),
              Expanded(
                child: Text(
                  'Existing',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: Text(
                  'Incoming',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        // Field rows
        for (final label in labels)
          _ComparisonRow(
            label: label,
            existingValue: entityMatch.existingFields[label],
            incomingValue: entityMatch.incomingFields[label],
          ),
        // Action buttons — match dive card style
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showChooseLabel)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    context.l10n.universalImport_pending_chooseAction,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.tertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Wrap(
                alignment: WrapAlignment.start,
                spacing: 8,
                runSpacing: 4,
                children: [
                  _EntityActionButton(
                    label: 'Skip',
                    subtitle: 'Discard this import',
                    isSelected: selectedAction == DuplicateAction.skip,
                    color: colorScheme.error,
                    onPressed: () => onActionChanged(DuplicateAction.skip),
                  ),
                  _EntityActionButton(
                    label: 'Import as New',
                    subtitle: 'Create separate entry',
                    isSelected: selectedAction == DuplicateAction.importAsNew,
                    color: Colors.green.shade700,
                    onPressed: () =>
                        onActionChanged(DuplicateAction.importAsNew),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A single row in the comparison table.
class _ComparisonRow extends StatelessWidget {
  final String label;
  final String? existingValue;
  final String? incomingValue;

  const _ComparisonRow({
    required this.label,
    required this.existingValue,
    required this.incomingValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final existing = existingValue ?? '';
    final incoming = incomingValue ?? '';
    final isDifferent =
        existing.toLowerCase() != incoming.toLowerCase() &&
        (existing.isNotEmpty || incoming.isNotEmpty);

    // Dimmed style for matching values, normal for differing values.
    final valueColor = isDifferent
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              existing.isEmpty ? '-' : existing,
              style: theme.textTheme.bodySmall?.copyWith(color: valueColor),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          Expanded(
            child: Text(
              incoming.isEmpty ? '-' : incoming,
              style: theme.textTheme.bodySmall?.copyWith(color: valueColor),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Action button for the entity comparison panel.
///
/// Matches the dive comparison card's button style: [FilledButton] when
/// selected (with color background + white text), [OutlinedButton] when not.
class _EntityActionButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool isSelected;
  final Color color;
  final VoidCallback onPressed;

  const _EntityActionButton({
    required this.label,
    this.subtitle = '',
    required this.isSelected,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const minSize = Size(0, 48);

    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : null,
          ),
        ),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.85)
                  : theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
      ],
    );

    if (isSelected) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: minSize,
          backgroundColor: color,
          foregroundColor: Colors.white,
        ),
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: minSize,
        foregroundColor: color,
        side: BorderSide(color: color, width: 2.5),
      ),
      child: child,
    );
  }
}

class _SimpleActionBadge extends StatelessWidget {
  final bool isImporting;

  const _SimpleActionBadge({required this.isImporting});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = isImporting
        ? ('IMPORT', Colors.green.shade700)
        : ('SKIP', theme.colorScheme.error);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
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

/// Horizontal row of bulk-action buttons rendered above the duplicate list.
///
/// Visible only when at least one row is pending. The set of buttons is
/// filtered by [availableActions] so adapters that don't support certain
/// actions simply don't render the corresponding button.
class _BulkActionRow extends StatelessWidget {
  final bool isDiveTab;
  final int pendingCount;
  final int matchableConsolidateCount;
  final Set<DuplicateAction> availableActions;
  final void Function(DuplicateAction) onBulkAction;

  const _BulkActionRow({
    required this.isDiveTab,
    required this.pendingCount,
    required this.matchableConsolidateCount,
    required this.availableActions,
    required this.onBulkAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          if (availableActions.contains(DuplicateAction.skip))
            OutlinedButton.icon(
              onPressed: () => onBulkAction(DuplicateAction.skip),
              icon: const Icon(Icons.block, size: 16),
              label: Text(
                context.l10n.universalImport_bulk_skipAll(pendingCount),
              ),
            ),
          if (availableActions.contains(DuplicateAction.importAsNew))
            OutlinedButton.icon(
              onPressed: () => onBulkAction(DuplicateAction.importAsNew),
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: Text(
                isDiveTab
                    ? context.l10n.universalImport_bulk_importAllAsNew(
                        pendingCount,
                      )
                    : context.l10n.universalImport_bulk_importAll(pendingCount),
              ),
            ),
          if (availableActions.contains(DuplicateAction.replaceSource))
            OutlinedButton.icon(
              onPressed: () => onBulkAction(DuplicateAction.replaceSource),
              icon: const Icon(Icons.sync, size: 16),
              label: Text(
                context.l10n.universalImport_bulk_replaceSourceAll(
                  pendingCount,
                ),
              ),
            ),
          if (availableActions.contains(DuplicateAction.consolidate))
            // TODO(#200): enable when bulk-consolidate is implemented end-to-end.
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.merge_type, size: 16),
              label: Text(
                context.l10n.universalImport_bulk_consolidateMatched(
                  matchableConsolidateCount,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
