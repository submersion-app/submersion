import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// One choice among [values] for a site value, as the site form's chips:
/// tapping the selected chip clears it (issue #4527, phase 2).
class SiteEnumChipsRow<E> extends StatelessWidget {
  const SiteEnumChipsRow({
    super.key,
    required this.session,
    required this.field,
    required this.label,
    required this.values,
    required this.name,
  });

  final EditSession<DiveSite> session;
  final EditField<DiveSite, E?> field;
  final String label;
  final List<E> values;
  final String Function(E value) name;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final current = session.valueOf(field);
        return FormRow.custom(
          label: label,
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final value in values)
                ChoiceChip(
                  label: Text(name(value)),
                  selected: current == value,
                  visualDensity: VisualDensity.compact,
                  onSelected: (selected) =>
                      session.set(field, selected ? value : null),
                ),
            ],
          ),
        );
      },
    );
  }
}
