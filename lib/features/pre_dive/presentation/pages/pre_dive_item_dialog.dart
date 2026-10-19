import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_editable_item.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// A bound once the form has validated: blank is "no bound", and unreadable
/// text cannot reach here.
double? _validatedNumber(TextEditingController controller) =>
    switch (readNumber(controller.text)) {
      NumberValue(:final value) => value,
      NumberBlank() => null,
      NumberInvalid() => null, // unreachable: validate() ran first
    };

/// Add/edit dialog for a single template item.
///
/// Owns its ephemeral [TextEditingController]s and disposes them in its own
/// [State.dispose]. Disposing them from `showDialog(...).whenComplete(...)`
/// instead frees the controllers the instant the route is popped, while the
/// dialog's exit transition is still rebuilding these fields — which throws
/// "TextEditingController used after being disposed" (and, on release builds,
/// trips the InheritedElement `_dependents` assertion) mid-animation.
class PreDiveItemDialog extends StatefulWidget {
  final EditablePreDiveItem? item;
  final int defaultSortOrder;

  /// The other items in this template, so a cell linearity item can name one
  /// of them as the source of its air reading (issue #986).
  final List<EditablePreDiveItem> siblings;

  /// This template's sections, for the section picker -- see
  /// EditableTemplateItem's dialog in checklist_template_edit_page.dart for
  /// why this is a picker over the draft's own sections rather than free
  /// text.
  final List<EditablePreDiveSection> sections;

  const PreDiveItemDialog({
    super.key,
    required this.item,
    required this.defaultSortOrder,
    this.siblings = const [],
    this.sections = const [],
  });

  @override
  State<PreDiveItemDialog> createState() => _PreDiveItemDialogState();
}

class _PreDiveItemDialogState extends State<PreDiveItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  String? _sectionId;

  /// The selection the dropdown may show: [_sectionId] only when it still
  /// names a section in the current draft -- the same dangling-value guard
  /// as [_selectedSourceId] below, for the same DropdownButtonFormField
  /// assert hazard.
  String? get _selectedSectionId =>
      widget.sections.any((s) => s.id == _sectionId) ? _sectionId : null;
  late final TextEditingController _notesController;
  late final TextEditingController _valueLabelController;
  late final TextEditingController _valueUnitController;
  late final TextEditingController _valueMinController;
  late final TextEditingController _valueMaxController;
  late PreDiveItemType _itemType;
  String? _sourceItemId;

  /// The selection the dropdown may show: [_sourceItemId] only when it still
  /// names a candidate.
  ///
  /// A dangling link is reachable without sync: retype the air item as a
  /// check and it drops out of the candidate list while the linearity item
  /// still points at it. DropdownButtonFormField asserts when its value is
  /// absent from a non-empty item list, which would take the editor down
  /// rather than let the diver fix the link. Falling back to null leaves the
  /// field empty and lets the validator ask for a new source.
  String? get _selectedSourceId =>
      _sourceCandidates.any((c) => c.id == _sourceItemId)
      ? _sourceItemId
      : null;

  /// Items this one may take its air reading from: the plain value items in
  /// the same template, minus itself (nothing may source itself).
  List<EditablePreDiveItem> get _sourceCandidates => [
    for (final sibling in widget.siblings)
      if (sibling.itemType == PreDiveItemType.value &&
          sibling.id != widget.item?.id)
        sibling,
  ];
  late bool _isRequired;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item?.title ?? '');
    _sectionId = widget.item?.sectionId;
    _notesController = TextEditingController(text: widget.item?.notes ?? '');
    _valueLabelController = TextEditingController(
      text: widget.item?.valueLabel ?? '',
    );
    _valueUnitController = TextEditingController(
      text: widget.item?.valueUnit ?? '',
    );
    final valueMin = widget.item?.valueMin;
    final valueMax = widget.item?.valueMax;
    _valueMinController = TextEditingController(
      text: valueMin == null ? '' : formatDecimalForInput(valueMin),
    );
    _valueMaxController = TextEditingController(
      text: valueMax == null ? '' : formatDecimalForInput(valueMax),
    );
    _itemType = widget.item?.itemType ?? PreDiveItemType.check;
    _sourceItemId = widget.item?.sourceItemId;
    _isRequired = widget.item?.isRequired ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _valueLabelController.dispose();
    _valueUnitController.dispose();
    _valueMinController.dispose();
    _valueMaxController.dispose();
    super.dispose();
  }

  String _typeLabel(BuildContext context, PreDiveItemType type) {
    return switch (type) {
      PreDiveItemType.check => context.l10n.preDive_item_type_check,
      PreDiveItemType.value => context.l10n.preDive_item_type_value,
      PreDiveItemType.equipmentSet =>
        context.l10n.preDive_item_type_equipmentSet,
      PreDiveItemType.equipment => context.l10n.preDive_item_type_equipment,
      PreDiveItemType.cellLinearity =>
        context.l10n.preDive_item_type_cellLinearity,
    };
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final valueLabel = _valueLabelController.text.trim();
    final valueUnit = _valueUnitController.text.trim();
    // A cell linearity item records a number exactly as a value item does,
    // so it carries the same label, unit and threshold fields. Those
    // thresholds mean a percentage there rather than a unit of measure.
    final isValue =
        _itemType == PreDiveItemType.value ||
        _itemType == PreDiveItemType.cellLinearity;
    Navigator.of(context).pop(
      EditablePreDiveItem(
        id: widget.item?.id ?? const Uuid().v4(),
        sectionId: _selectedSectionId,
        title: _titleController.text.trim(),
        notes: _notesController.text.trim(),
        sortOrder: widget.item?.sortOrder ?? widget.defaultSortOrder,
        itemType: _itemType,
        valueLabel: isValue && valueLabel.isNotEmpty ? valueLabel : null,
        valueUnit: isValue && valueUnit.isNotEmpty ? valueUnit : null,
        valueMin: isValue ? _validatedNumber(_valueMinController) : null,
        valueMax: isValue ? _validatedNumber(_valueMaxController) : null,
        isRequired: _isRequired,
        // Not edited here: the start-session flow remembers the device an
        // 'equipment' item last used. Carried through so an edit to the
        // title or notes does not forget it; dropped once the item is
        // retyped, since only that type reads it.
        equipmentId: _itemType == PreDiveItemType.equipment
            ? widget.item?.equipmentId
            : null,
        sourceItemId: _itemType == PreDiveItemType.cellLinearity
            ? _selectedSourceId
            : null,
        createdAt: widget.item?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.preDive_edit_addItem),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.preDive_item_title),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.checklists_item_titleRequired
                    : null,
              ),
              DropdownButtonFormField<String?>(
                initialValue: _selectedSectionId,
                decoration: InputDecoration(
                  labelText: l10n.preDive_item_section,
                ),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(l10n.sectionEditor_noSection),
                  ),
                  for (final section in widget.sections)
                    DropdownMenuItem(
                      value: section.id,
                      child: Text(section.title),
                    ),
                ],
                onChanged: (value) => setState(() => _sectionId = value),
              ),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(labelText: l10n.preDive_item_notes),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<PreDiveItemType>(
                initialValue: _itemType,
                items: [
                  for (final type in PreDiveItemType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(_typeLabel(context, type)),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _itemType = value ?? PreDiveItemType.check),
              ),
              if (_itemType == PreDiveItemType.cellLinearity)
                DropdownButtonFormField<String>(
                  initialValue: _selectedSourceId,
                  decoration: InputDecoration(
                    labelText: l10n.preDive_item_sourceItem,
                  ),
                  items: [
                    for (final candidate in _sourceCandidates)
                      DropdownMenuItem(
                        value: candidate.id,
                        child: Text(
                          candidate.valueLabel == null
                              ? candidate.title
                              : '${candidate.title} (${candidate.valueLabel})',
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _sourceItemId = value),
                  // Required in the editor. Degradation exists for rows that
                  // arrive from a clone, from sync, or from a since-deleted
                  // source, not as a state the editor may author.
                  // Reads the resolved selection rather than the raw
                  // field, so a dangling link is rejected as firmly as an
                  // empty one instead of being saved back unchanged.
                  validator: (_) => _selectedSourceId == null
                      ? l10n.preDive_item_sourceItemRequired
                      : null,
                ),
              if (_itemType == PreDiveItemType.value ||
                  _itemType == PreDiveItemType.cellLinearity) ...[
                TextFormField(
                  controller: _valueLabelController,
                  decoration: InputDecoration(
                    labelText: l10n.preDive_item_valueLabel,
                  ),
                ),
                TextFormField(
                  controller: _valueUnitController,
                  decoration: InputDecoration(
                    labelText: l10n.preDive_item_valueUnit,
                  ),
                ),
                TextFormField(
                  controller: _valueMinController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  // An unreadable bound used to save as no bound (#1900).
                  validator: numberValidator(context),
                  decoration: InputDecoration(
                    labelText: _itemType == PreDiveItemType.cellLinearity
                        ? l10n.preDive_item_linearityMin
                        : l10n.preDive_item_valueMin,
                  ),
                ),
                TextFormField(
                  controller: _valueMaxController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  // An unreadable bound used to save as no bound (#1900).
                  validator: numberValidator(context),
                  decoration: InputDecoration(
                    labelText: _itemType == PreDiveItemType.cellLinearity
                        ? l10n.preDive_item_linearityMax
                        : l10n.preDive_item_valueMax,
                  ),
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.preDive_item_required),
                value: _isRequired,
                onChanged: (value) => setState(() => _isRequired = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.common_action_ok)),
      ],
    );
  }
}
