import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/checklists/presentation/pages/checklist_editable_item.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Add/edit dialog for a single template item.
///
/// Owns its ephemeral [TextEditingController]s and disposes them in its own
/// [State.dispose]. Disposing them from `showDialog(...).whenComplete(...)`
/// instead frees the controllers the instant the route is popped, while the
/// dialog's exit transition is still rebuilding these fields, which throws
/// "TextEditingController used after being disposed" (and, on release builds,
/// trips the InheritedElement `_dependents` assertion) mid-animation.
class ChecklistItemDialog extends StatefulWidget {
  final EditableChecklistItem? item;
  final int defaultSortOrder;
  final List<EditableChecklistSection> sections;

  const ChecklistItemDialog({
    super.key,
    required this.item,
    required this.defaultSortOrder,
    this.sections = const [],
  });

  @override
  State<ChecklistItemDialog> createState() => _ChecklistItemDialogState();
}

class _ChecklistItemDialogState extends State<ChecklistItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _offsetController;
  String? _sectionId;

  /// The selection the dropdown may show: [_sectionId] only when it still
  /// names a section in the current draft. A dangling id (the section was
  /// deleted from the list while this dialog's value carried over from a
  /// stale item) would otherwise make DropdownButtonFormField assert, the
  /// same hazard PreDiveItemDialog's _selectedSourceId guards against.
  String? get _selectedSectionId =>
      widget.sections.any((s) => s.id == _sectionId) ? _sectionId : null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item?.title ?? '');
    _sectionId = widget.item?.sectionId;
    _notesController = TextEditingController(text: widget.item?.notes ?? '');
    final offsetDays = widget.item?.dueOffsetDays;
    _offsetController = TextEditingController(
      text: offsetDays == null
          ? ''
          : formatDecimalForInput(offsetDays.toDouble()),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _offsetController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      EditableChecklistItem(
        id: widget.item?.id ?? const Uuid().v4(),
        title: _titleController.text.trim(),
        sectionId: _selectedSectionId,
        notes: _notesController.text.trim(),
        // Blank is "no due date"; validate() stopped unreadable text.
        dueOffsetDays: switch (readNumber(
          _offsetController.text,
          integer: true,
        )) {
          NumberValue(:final value) => value.toInt(),
          NumberBlank() || NumberInvalid() => null,
        },
        sortOrder: widget.item?.sortOrder ?? widget.defaultSortOrder,
        createdAt: widget.item?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.item == null
            ? context.l10n.checklists_template_addItem
            : context.l10n.checklists_item_edit,
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.l10n.checklists_item_titleLabel,
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? context.l10n.checklists_item_titleRequired
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: _selectedSectionId,
                decoration: InputDecoration(
                  labelText: context.l10n.checklists_item_categoryLabel,
                ),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(context.l10n.sectionEditor_noSection),
                  ),
                  for (final section in widget.sections)
                    DropdownMenuItem(
                      value: section.id,
                      child: Text(section.title),
                    ),
                ],
                onChanged: (value) => setState(() => _sectionId = value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: context.l10n.checklists_item_notesLabel,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _offsetController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.l10n.checklists_item_dueOffsetLabel,
                ),
                validator: numberValidator(
                  context,
                  integer: true,
                  check: (days) => days < 0
                      ? context.l10n.checklists_item_dueOffsetInvalid
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(context.l10n.common_action_ok),
        ),
      ],
    );
  }
}
