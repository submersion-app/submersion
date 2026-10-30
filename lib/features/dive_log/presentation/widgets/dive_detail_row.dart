import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/widgets/field_attribution_badge.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row.dart';

/// A label/value row used throughout the dive detail page.
///
/// The value sits right beside the label, on the card's shared label column
/// when the row is inside a `DetailRowGroup` (issue #3678). When the value
/// is long it wraps onto additional lines rather than crowding the label or
/// overflowing the edge (issue #434).
class DiveDetailRow extends StatelessWidget {
  const DiveDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.sourceName,
  });

  /// Leading, muted field name (e.g. "Dive Type").
  final String label;

  /// The value (e.g. a comma-joined list of dive types).
  final String value;

  /// When non-null, an attribution badge is shown after the value.
  final String? sourceName;

  @override
  Widget build(BuildContext context) {
    return DetailRow(
      label: label,
      value: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
          if (sourceName != null) ...[
            const SizedBox(width: 6),
            FieldAttributionBadge(sourceName: sourceName),
          ],
        ],
      ),
    );
  }
}
