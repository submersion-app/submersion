import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/detail_row/detail_row.dart';

/// A detail-page row: a leading icon, a label, and a bold value right
/// beside it, read by screen readers as one "label: value" node.
///
/// The value wraps instead of squeezing the label (issue #2695). The label
/// column, icon included, never takes more than 40% of the row, so a long
/// localized label (the Spanish "Also Recognized" is 23 characters) wraps
/// rather than squeezing the value or overflowing the row at a large text
/// size. Inside a `DetailRowGroup` every row of the card shares one label
/// column (issue #3678).
class IconDetailRow extends StatelessWidget {
  const IconDetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Tints the value, e.g. an expiry date that has passed.
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(
      context,
    ).style.merge(Theme.of(context).textTheme.bodyMedium);

    // The row reads as one "label: value" node; the texts are not read again.
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: DetailRow.text(
        icon: icon,
        label: label,
        labelStyle: style,
        value: value,
        valueStyle: style.copyWith(
          fontWeight: FontWeight.bold,
          color: valueColor,
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
      ),
    );
  }
}
