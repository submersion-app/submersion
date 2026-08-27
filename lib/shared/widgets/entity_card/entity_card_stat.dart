import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/shared/constants/entity_field.dart';

/// One icon + value stat on a list card, resolved through the entity's
/// field adapter so any configurable field renders the same way.
///
/// Renders nothing when the field has no value, so a card never shows a
/// dangling "--" for a stat that does not apply (a site never dived, a
/// buddy with no last dive). A value that is non-null but formats to
/// nothing counts as absent too: a buddy's notes is a non-nullable String,
/// so an empty one survives the null check and its adapter renders it as
/// [kFieldValuePlaceholder], which only a table cell wants.
class EntityCardStat<T, F extends EntityField> extends StatelessWidget {
  final EntityFieldAdapter<T, F> adapter;
  final T entity;
  final F field;
  final UnitFormatter units;
  final Color color;

  /// Optional replacement for [EntityFieldAdapter.formatValue], for stats
  /// whose card rendering needs a plural or other l10n the adapter cannot
  /// reach ("14 dives" rather than "14").
  final String Function(F field, dynamic value)? formatter;

  const EntityCardStat({
    super.key,
    required this.adapter,
    required this.entity,
    required this.field,
    required this.units,
    required this.color,
    this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final value = adapter.extractValue(field, entity);
    if (value == null) return const SizedBox.shrink();
    final formatted =
        formatter?.call(field, value) ??
        adapter.formatValue(field, value, units);
    if (isBlankFieldValue(formatted)) return const SizedBox.shrink();
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: color);
    final icon = field.icon;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          ExcludeSemantics(child: Icon(icon, size: 14, color: color)),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            formatted,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
