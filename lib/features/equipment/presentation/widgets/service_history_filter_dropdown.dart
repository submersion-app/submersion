part of 'service_history_section.dart';

/// One compact dropdown in the maintenance history filter bar.
///
/// Bordered container with the underline suppressed, matching the filter
/// dropdown in EquipmentListContent so the two read as the same control.
class _FilterDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<T>(
        value: value,
        underline: const SizedBox(),
        isDense: true,
        items: [
          for (final option in options)
            DropdownMenuItem<T>(value: option, child: Text(labelOf(option))),
        ],
        onChanged: (selected) {
          if (selected is T) onChanged(selected);
        },
      ),
    );
  }
}
