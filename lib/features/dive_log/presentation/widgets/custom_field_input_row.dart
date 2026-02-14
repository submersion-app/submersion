import 'package:flutter/material.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';

class CustomFieldInputRow extends StatelessWidget {
  final DiveCustomField field;
  final List<String> keySuggestions;
  final ValueChanged<DiveCustomField> onChanged;
  final VoidCallback onDelete;

  const CustomFieldInputRow({
    super.key,
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
          const Icon(Icons.drag_handle, color: Colors.grey),
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
                  decoration: const InputDecoration(
                    labelText: 'Key',
                    isDense: true,
                    border: OutlineInputBorder(),
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
              decoration: const InputDecoration(
                labelText: 'Value',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                onChanged(field.copyWith(value: value));
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onDelete,
            tooltip: 'Remove field',
            iconSize: 20,
          ),
        ],
      ),
    );
  }
}
