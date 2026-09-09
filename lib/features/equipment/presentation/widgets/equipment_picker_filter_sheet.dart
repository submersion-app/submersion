import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/models/equipment_picker_filter.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the picker's filter panel and resolves to the chosen filter, or null
/// when the diver cancels.
///
/// [availableTypes] and [availableStatuses] come from the gear actually in the
/// picker, so it never offers a chip that would match nothing. The current
/// selection is always included even if nothing matches it any more, so an
/// active filter stays clearable from here.
Future<EquipmentPickerFilter?> showEquipmentPickerFilterSheet(
  BuildContext context, {
  required EquipmentPickerFilter current,
  required List<EquipmentType> availableTypes,
  required List<EquipmentStatus> availableStatuses,
}) {
  return showModalBottomSheet<EquipmentPickerFilter>(
    context: context,
    isScrollControlled: true,
    builder: (_) => EquipmentPickerFilterSheet(
      current: current,
      availableTypes: availableTypes,
      availableStatuses: availableStatuses,
    ),
  );
}

/// Filter panel for the Add Equipment picker (#1576).
///
/// Edits a local draft and returns it on Apply, matching the contract the
/// Equipment page's filter sheet uses: nothing moves under the diver while
/// they are choosing.
class EquipmentPickerFilterSheet extends StatefulWidget {
  const EquipmentPickerFilterSheet({
    super.key,
    required this.current,
    required this.availableTypes,
    required this.availableStatuses,
  });

  final EquipmentPickerFilter current;
  final List<EquipmentType> availableTypes;
  final List<EquipmentStatus> availableStatuses;

  @override
  State<EquipmentPickerFilterSheet> createState() =>
      _EquipmentPickerFilterSheetState();
}

class _EquipmentPickerFilterSheetState
    extends State<EquipmentPickerFilterSheet> {
  EquipmentStatus? _status;
  EquipmentType? _type;

  // Seeded in initState rather than in a field initializer. A `late` field
  // initializer would also work, because it defers to first read in build,
  // by which point the framework has assigned `widget`. But a plain field
  // initializer reading `widget` DOES throw, since State fields are built
  // during createState before the element assigns it, so the `late` was the
  // only thing standing between this and a crash. initState says so plainly.
  @override
  void initState() {
    super.initState();
    _status = widget.current.status;
    _type = widget.current.type;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Flexible with an ellipsis: the Clear All action beside
                    // it is itself a translated string, so the pair can
                    // outgrow a narrow phone.
                    Flexible(
                      child: Semantics(
                        header: true,
                        child: Text(
                          l10n.equipment_filter_title,
                          style: textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() {
                        _status = null;
                        _type = null;
                      }),
                      child: Text(l10n.equipment_filter_clearAll),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (widget.availableStatuses.isNotEmpty) ...[
                _label(l10n.equipment_filter_section_status, textTheme),
                _chips(
                  allLabel: l10n.equipment_list_filterAll,
                  allSelected: _status == null,
                  onAll: () => setState(() => _status = null),
                  children: [
                    for (final status in widget.availableStatuses)
                      ChoiceChip(
                        key: ValueKey('picker_filter_status_${status.name}'),
                        label: Text(status.localizedName(l10n)),
                        selected: _status == status,
                        onSelected: (selected) =>
                            setState(() => _status = selected ? status : null),
                      ),
                  ],
                ),
              ],
              if (widget.availableTypes.isNotEmpty) ...[
                _label(l10n.equipment_filter_section_category, textTheme),
                _chips(
                  allLabel: l10n.equipment_list_typeFilterAll,
                  allSelected: _type == null,
                  onAll: () => setState(() => _type = null),
                  children: [
                    for (final type in widget.availableTypes)
                      ChoiceChip(
                        key: ValueKey('picker_filter_type_${type.name}'),
                        avatar: Icon(equipmentTypeIcon(type), size: 18),
                        label: Text(type.localizedName(l10n)),
                        selected: _type == type,
                        onSelected: (selected) =>
                            setState(() => _type = selected ? type : null),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.equipment_filter_cancel),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('picker_filter_apply'),
                        onPressed: () => Navigator.of(context).pop(
                          EquipmentPickerFilter(status: _status, type: _type),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                        ),
                        child: Text(l10n.equipment_filter_apply),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text, TextTheme textTheme) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Text(text, style: textTheme.titleMedium),
  );

  Widget _chips({
    required String allLabel,
    required bool allSelected,
    required VoidCallback onAll,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: Text(allLabel),
            selected: allSelected,
            onSelected: (_) => onAll(),
          ),
          ...children,
        ],
      ),
    );
  }
}
