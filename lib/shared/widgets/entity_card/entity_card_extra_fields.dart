import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/constants/entity_field.dart';

/// The configurable "extra fields" grid under a detailed list card: a
/// two-column wrap of `label: value` pairs (one column under 250 px), the
/// same shape the dive card uses.
///
/// Fields without a value are skipped, including ones whose value is non-null
/// but formats to nothing: an empty String extracts as non-null and its
/// adapter renders it as the placeholder, which would show here as a dangling
/// "Notes: --".
class EntityCardExtraFields<T, F extends EntityField> extends StatelessWidget {
  final EntityFieldAdapter<T, F> adapter;
  final T entity;
  final List<F> fields;
  final UnitFormatter units;
  final Color labelColor;
  final Color valueColor;

  const EntityCardExtraFields({
    super.key,
    required this.adapter,
    required this.entity,
    required this.fields,
    required this.units,
    required this.labelColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final entries = <(F, String)>[];
    for (final field in fields) {
      final value = adapter.extractValue(field, entity);
      if (value == null) continue;
      final formatted = adapter.formatValue(field, value, units);
      if (isBlankFieldValue(formatted)) continue;
      entries.add((field, formatted));
    }
    if (entries.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final useOneColumn = constraints.maxWidth < 250;
        final width = useOneColumn
            ? constraints.maxWidth
            : (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            for (final (field, formatted) in entries)
              SizedBox(
                width: width,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${field.localizedShortLabel(context.l10n)}: ',
                      style: TextStyle(
                        fontSize: 11,
                        color: labelColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        formatted,
                        style: TextStyle(fontSize: 11, color: valueColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
