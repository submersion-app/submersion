import 'package:flutter/material.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class CustomFieldInputRow extends StatelessWidget {
  final int index;
  final DiveCustomField field;
  final List<String> keySuggestions;
  final ValueChanged<DiveCustomField> onChanged;
  final VoidCallback onDelete;

  const CustomFieldInputRow({
    super.key,
    required this.index,
    required this.field,
    required this.keySuggestions,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle, color: Colors.grey),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Autocomplete<String>(
              initialValue: TextEditingValue(text: field.key),
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return keySuggestions;
                }
                return keySuggestions.where(
                  (s) => s.toLowerCase().contains(
                    textEditingValue.text.toLowerCase(),
                  ),
                );
              },
              onSelected: (value) {
                onChanged(field.copyWith(key: value));
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: context.l10n.diveLog_edit_customFieldKey,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    onChanged(field.copyWith(key: value));
                  },
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: TextFormField(
              initialValue: field.value,
              decoration: InputDecoration(
                labelText: context.l10n.diveLog_edit_customFieldValue,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                onChanged(field.copyWith(value: value));
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onDelete,
            tooltip: context.l10n.common_action_delete,
            iconSize: 20,
          ),
        ],
      ),
    );
  }
}
