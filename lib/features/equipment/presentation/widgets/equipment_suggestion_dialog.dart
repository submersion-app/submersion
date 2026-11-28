import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_suggestion.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Asks the diver for a new equipment category or subcategory (issue
/// #5103). Returns the suggestion, trimmed, or null when cancelled.
///
/// [currentType] is the item's type: the parent a subcategory starts under.
/// An item filed as Other has no fitting type, so it starts as a new
/// category instead. [example] is the item's brand and model, offered
/// behind an unticked checkbox and never sent unless the diver ticks it.
Future<EquipmentSuggestion?> showEquipmentSuggestionDialog(
  BuildContext context, {
  required EquipmentType currentType,
  String? example,
}) => showDialog<EquipmentSuggestion>(
  context: context,
  builder: (_) => _EquipmentSuggestionDialog(
    currentType: currentType,
    example: example?.trim() ?? '',
  ),
);

class _EquipmentSuggestionDialog extends StatefulWidget {
  const _EquipmentSuggestionDialog({
    required this.currentType,
    required this.example,
  });

  final EquipmentType currentType;
  final String example;

  @override
  State<_EquipmentSuggestionDialog> createState() =>
      _EquipmentSuggestionDialogState();
}

class _EquipmentSuggestionDialogState
    extends State<_EquipmentSuggestionDialog> {
  late EquipmentSuggestionKind _kind;
  EquipmentType? _parent;
  bool _includeExample = false;
  final _name = TextEditingController();
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    final isOther = widget.currentType == EquipmentType.other;
    _kind = isOther
        ? EquipmentSuggestionKind.category
        : EquipmentSuggestionKind.subcategory;
    _parent = isOther ? null : widget.currentType;
    _name.addListener(_changed);
    _reason.addListener(_changed);
  }

  @override
  void dispose() {
    _name.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  bool get _isSubcategory => _kind == EquipmentSuggestionKind.subcategory;

  bool get _ready =>
      _name.text.trim().isNotEmpty &&
      _reason.text.trim().isNotEmpty &&
      (!_isSubcategory || _parent != null);

  void _submit() => Navigator.of(context).pop(
    EquipmentSuggestion(
      kind: _kind,
      name: _name.text.trim(),
      parent: _parent,
      reason: _reason.text.trim(),
      example: _includeExample ? widget.example : null,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final types = EquipmentType.values.sortedByLocalizedName(l10n);
    return AlertDialog(
      title: Text(l10n.equipment_suggest_title),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.equipment_suggest_intro,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.equipment_suggest_kindQuestion,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              SegmentedButton<EquipmentSuggestionKind>(
                key: const ValueKey('equipment-suggest-kind'),
                segments: [
                  ButtonSegment(
                    value: EquipmentSuggestionKind.category,
                    label: Text(l10n.equipment_suggest_kindCategory),
                  ),
                  ButtonSegment(
                    value: EquipmentSuggestionKind.subcategory,
                    label: Text(l10n.equipment_suggest_kindSubcategory),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (picked) =>
                    setState(() => _kind = picked.single),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('equipment-suggest-name'),
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.equipment_suggest_nameLabel,
                ),
              ),
              const SizedBox(height: 16),
              // Rebuilt when the kind changes: a subcategory offers no None,
              // so the field's items and value change with it.
              KeyedSubtree(
                key: ValueKey(_kind),
                child: DropdownButtonFormField<EquipmentType?>(
                  key: const ValueKey('equipment-suggest-parent'),
                  initialValue: _parent,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: _isSubcategory
                        ? l10n.equipment_suggest_parentSubcategoryLabel
                        : l10n.equipment_suggest_parentCategoryLabel,
                  ),
                  items: [
                    if (!_isSubcategory)
                      DropdownMenuItem(
                        value: null,
                        child: Text(l10n.equipment_suggest_parentNone),
                      ),
                    for (final type in types)
                      DropdownMenuItem(
                        value: type,
                        child: Text(
                          type.localizedName(l10n),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (type) => setState(() => _parent = type),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('equipment-suggest-reason'),
                controller: _reason,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.equipment_suggest_reasonLabel,
                  hintText: l10n.equipment_suggest_reasonHint,
                  alignLabelWithHint: true,
                ),
              ),
              if (widget.example.isNotEmpty) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  key: const ValueKey('equipment-suggest-example'),
                  value: _includeExample,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    l10n.equipment_suggest_includeExample(widget.example),
                  ),
                  onChanged: (value) =>
                      setState(() => _includeExample = value ?? false),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton.icon(
          key: const ValueKey('equipment-suggest-open'),
          icon: const Icon(Icons.open_in_new),
          label: Text(l10n.equipment_suggest_open),
          onPressed: _ready ? _submit : null,
        ),
      ],
    );
  }
}
