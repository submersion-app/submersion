import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';

/// A [FormRow.picker] over a fixed list of enum-like values, opening a
/// modal bottom sheet of radio options. Replaces the outlined
/// DropdownButtonFormField pattern inside edit-form sections.
class EnumPickerRow<T> extends StatelessWidget {
  const EnumPickerRow({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.displayName,
    required this.onChanged,
    this.allowClear = true,
    this.placeholder,
  });

  final String label;
  final T? value;
  final List<T> values;
  final String Function(T value) displayName;

  /// Called with the picked value, or null when "Not specified" is chosen.
  final ValueChanged<T?> onChanged;
  final bool allowClear;
  final String? placeholder;

  Future<void> _openSheet(BuildContext context) async {
    final result = await showModalBottomSheet<_EnumChoice<T>>(
      context: context,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(label, style: theme.textTheme.titleMedium),
              ),
              if (allowClear)
                ListTile(
                  leading: Icon(
                    value == null
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(
                    placeholder ?? sheetContext.l10n.diveLog_edit_notSpecified,
                  ),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_EnumChoice<T>(null)),
                ),
              for (final v in values)
                ListTile(
                  leading: Icon(
                    v == value
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(displayName(v)),
                  onTap: () => Navigator.of(sheetContext).pop(_EnumChoice(v)),
                ),
            ],
          ),
        );
      },
    );
    if (result != null) onChanged(result.value);
  }

  @override
  Widget build(BuildContext context) {
    return FormRow.picker(
      label: label,
      value: value == null ? null : displayName(value as T),
      placeholder: placeholder ?? context.l10n.diveLog_edit_notSpecified,
      onTap: () => _openSheet(context),
    );
  }
}

/// Wrapper distinguishing "picked null (clear)" from "sheet dismissed".
class _EnumChoice<T> {
  const _EnumChoice(this.value);

  final T? value;
}
