import 'package:flutter/material.dart';

import 'package:submersion/core/presentation/widgets/dive_comparison_card.dart';
import 'package:submersion/core/presentation/widgets/dive_sparkline.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/needs_decision_pill.dart';

/// A collapsed/expandable card summarising one duplicate item.
///
/// In collapsed state the card shows a match-percentage badge, item title and
/// subtitle, and the current action badge. Tapping the chevron expands the
/// card to reveal a [DiveComparisonCard] in tri-state selector mode.
class DuplicateActionCard extends StatefulWidget {
  /// The item data for display.
  final EntityItem item;

  /// The duplicate match result containing score and matched dive ID.
  final DiveMatchResult matchResult;

  /// The currently selected action for this item.
  ///
  /// `null` when the user has not yet made a decision. In that state the
  /// card renders without an action badge and the embedded comparison card
  /// leaves every action button outlined (no button is pre-highlighted).
  final DuplicateAction? selectedAction;

  /// The set of action buttons to show in the expanded comparison card.
  final Set<DuplicateAction> availableActions;

  /// Called when the user selects a different action.
  final ValueChanged<DuplicateAction> onActionChanged;

  /// The ID of the matched existing dive, passed to [DiveComparisonCard].
  final String existingDiveId;

  /// Optional projected dive number to display when this item will be imported.
  ///
  /// Only shown when [selectedAction] is [DuplicateAction.importAsNew].
  final int? projectedDiveNumber;

  /// Whether this duplicate still needs an explicit user decision.
  ///
  /// When `true`, the card is rendered in a warning visual state: a 1.5-px
  /// warning-colored border and a [NeedsDecisionPill] in the header.
  final bool isPending;

  const DuplicateActionCard({
    super.key,
    required this.item,
    required this.matchResult,
    required this.selectedAction,
    required this.availableActions,
    required this.onActionChanged,
    required this.existingDiveId,
    this.projectedDiveNumber,
    this.isPending = false,
  });

  @override
  State<DuplicateActionCard> createState() => _DuplicateActionCardState();
}

class _DuplicateActionCardState extends State<DuplicateActionCard> {
  bool _expanded = false;

  @override
  void didUpdateWidget(DuplicateActionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-collapse when an action is selected (user made their decision).
    if (oldWidget.selectedAction == null && widget.selectedAction != null) {
      setState(() => _expanded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final score = widget.matchResult.score;

    // Fallback-free border colour for non-pending rows. Pending rows always
    // override with the tertiary warning border below, so the fallback used
    // here (when [selectedAction] is null) is only theoretical.
    final borderColor = switch (widget.selectedAction) {
      DuplicateAction.importAsNew => Colors.green,
      DuplicateAction.consolidate => colorScheme.primary,
      DuplicateAction.skip => score >= 0.7 ? colorScheme.error : Colors.orange,
      DuplicateAction.replaceSource => Colors.blue.shade700,
      null => colorScheme.tertiary,
    };

    final BorderSide borderSide = widget.isPending
        ? BorderSide(color: colorScheme.tertiary, width: 1.5)
        : BorderSide(color: borderColor, width: 1.5);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: borderSide,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CollapsedHeader(
            item: widget.item,
            matchResult: widget.matchResult,
            selectedAction: widget.selectedAction,
            expanded: _expanded,
            isPending: widget.isPending,
            onToggle: () => setState(() => _expanded = !_expanded),
            projectedDiveNumber:
                widget.selectedAction == DuplicateAction.importAsNew
                ? widget.projectedDiveNumber
                : null,
          ),
          if (_expanded) _buildExpanded(context, colorScheme),
        ],
      ),
    );
  }

  Widget _buildExpanded(BuildContext context, ColorScheme colorScheme) {
    final diveData = widget.item.diveData;
    if (diveData == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Dive data not available for comparison.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return DiveComparisonCard(
      embedded: true,
      incoming: diveData,
      existingDiveId: widget.existingDiveId,
      matchScore: widget.matchResult.score,
      incomingLabel: 'Incoming',
      selectedAction: widget.selectedAction,
      onActionChanged: widget.onActionChanged,
      availableActions: widget.availableActions,
      isPending: widget.isPending,
    );
  }
}

class _CollapsedHeader extends StatelessWidget {
  final EntityItem item;
  final DiveMatchResult matchResult;

  /// The action chosen for this row, or `null` when the user has not yet
  /// decided. Null suppresses the trailing [_ActionBadge].
  final DuplicateAction? selectedAction;
  final bool expanded;
  final bool isPending;
  final VoidCallback onToggle;
  final int? projectedDiveNumber;

  const _CollapsedHeader({
    required this.item,
    required this.matchResult,
    required this.selectedAction,
    required this.expanded,
    required this.onToggle,
    this.isPending = false,
    this.projectedDiveNumber,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final score = matchResult.score;
    final percent = (score * 100).toStringAsFixed(0);

    final badgeBorderColor = score >= 0.7 ? colorScheme.error : Colors.orange;

    // Use subtitle from the adapter (already includes site name when available).
    // Fall back to the matched existing dive's site name if the adapter didn't
    // have one (e.g., import data lacks site info but existing dive has it).
    final String effectiveSubtitle;
    if (item.subtitle.isNotEmpty) {
      effectiveSubtitle = item.subtitle;
    } else if (matchResult.siteName != null &&
        matchResult.siteName!.isNotEmpty) {
      effectiveSubtitle = matchResult.siteName!;
    } else {
      effectiveSubtitle = '';
    }

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: dive number + title/subtitle + chevron
            Row(
              children: [
                if (projectedDiveNumber != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (effectiveSubtitle.isNotEmpty)
                        Text(
                          effectiveSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Bottom row: sparkline + badges (wraps on narrow screens)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (!expanded &&
                    item.diveData != null &&
                    item.diveData!.profile.isNotEmpty)
                  DiveSparkline(profile: item.diveData!.profile),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: badgeBorderColor, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$percent% match',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: badgeBorderColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isPending) NeedsDecisionPill(colorScheme: colorScheme),
                if (selectedAction != null)
                  _ActionBadge(action: selectedAction!),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBadge extends StatelessWidget {
  final DuplicateAction action;

  const _ActionBadge({required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (action) {
      DuplicateAction.skip => ('SKIP', theme.colorScheme.error),
      DuplicateAction.importAsNew => ('IMPORT', Colors.green.shade700),
      DuplicateAction.consolidate => ('CONSOLIDATE', Colors.green.shade700),
      DuplicateAction.replaceSource => ('REPLACE', Colors.blue.shade700),
    };

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
