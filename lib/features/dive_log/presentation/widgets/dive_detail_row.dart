import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/widgets/field_attribution_badge.dart';

/// A label/value row used throughout the dive detail page.
///
/// The label sits at the leading edge and the value at the trailing edge. When
/// the value is long it wraps onto additional lines rather than crowding the
/// label or overflowing the right edge (issue #434).
class DiveDetailRow extends StatelessWidget {
  const DiveDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.sourceName,
  });

  /// Leading, muted field name (e.g. "Dive Type").
  final String label;

  /// Trailing value (e.g. a comma-joined list of dive types).
  final String value;

  /// When non-null, an attribution badge is shown after the value.
  final String? sourceName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      // Top-align so a multi-line value keeps the label pinned to the first
      // line rather than vertically centring against the wrapped block.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          // A guaranteed gap so the label and value never touch, even when the
          // value grows wide enough to fill the rest of the row.
          const SizedBox(width: 16),
          // Expanded gives the value the remaining width as a bound, so a long
          // value wraps (right-aligned) instead of overflowing the edge.
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.end,
                  ),
                ),
                if (sourceName != null) ...[
                  const SizedBox(width: 6),
                  FieldAttributionBadge(sourceName: sourceName),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
