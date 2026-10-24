import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';

/// The multi-select twin of `EnumPickerRow`: a [FormRow.picker] showing the
/// selected values joined by ", ", opening a modal bottom sheet of
/// checkboxes. Each toggle reports the new selection at once, in [values]
/// order, as the dive-type checklist does; an empty selection is allowed.
class EnumMultiPickerRow<T> extends StatelessWidget {
  const EnumMultiPickerRow({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.displayName,
    required this.onChanged,
    this.placeholder,
  });

  final String label;
  final List<T> value;
  final List<T> values;
  final String Function(T value) displayName;
  final ValueChanged<List<T>> onChanged;
  final String? placeholder;

  Future<void> _openSheet(BuildContext context) {
    var selected = value.toSet();
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Text(label, style: theme.textTheme.titleMedium),
                ),
                for (final v in values)
                  CheckboxListTile(
                    controlAffinity: ListTileControlAffinity.leading,
                    value: selected.contains(v),
                    title: Text(displayName(v)),
                    onChanged: (checked) {
                      final next = {...selected};
                      checked == true ? next.add(v) : next.remove(v);
                      setSheetState(() => selected = next);
                      onChanged([
                        for (final w in values)
                          if (next.contains(w)) w,
                      ]);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormRow.picker(
      label: label,
      value: value.isEmpty ? null : value.map(displayName).join(', '),
      placeholder: placeholder ?? context.l10n.diveLog_edit_notSpecified,
      onTap: () => _openSheet(context),
    );
  }
}
