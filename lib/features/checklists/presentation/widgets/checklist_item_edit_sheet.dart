import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Bottom sheet for creating or editing a trip checklist item.
Future<void> showChecklistItemEditSheet({
  required BuildContext context,
  required String tripId,
  TripChecklistItem? item,
  List<String> categorySuggestions = const [],
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ChecklistItemEditSheet(
      tripId: tripId,
      item: item,
      categorySuggestions: categorySuggestions,
    ),
  );
}

class _ChecklistItemEditSheet extends ConsumerStatefulWidget {
  final String tripId;
  final TripChecklistItem? item;
  final List<String> categorySuggestions;

  const _ChecklistItemEditSheet({
    required this.tripId,
    this.item,
    this.categorySuggestions = const [],
  });

  @override
  ConsumerState<_ChecklistItemEditSheet> createState() =>
      _ChecklistItemEditSheetState();
}

class _ChecklistItemEditSheetState
    extends ConsumerState<_ChecklistItemEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _categoryController;
  late final TextEditingController _notesController;
  final _categoryFocusNode = FocusNode();
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item?.title ?? '');
    _categoryController = TextEditingController(
      text: widget.item?.category ?? '',
    );
    _notesController = TextEditingController(text: widget.item?.notes ?? '');
    _dueDate = widget.item?.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    _categoryFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repository = ref.read(tripChecklistRepositoryProvider);
    final category = _categoryController.text.trim();
    final existing = widget.item;
    if (existing == null) {
      await repository.createItem(
        TripChecklistItem(
          id: '',
          tripId: widget.tripId,
          title: _titleController.text.trim(),
          category: category.isEmpty ? null : category,
          notes: _notesController.text.trim(),
          dueDate: _dueDate,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    } else {
      await repository.updateItem(
        existing.copyWith(
          title: _titleController.text.trim(),
          category: category.isEmpty ? null : category,
          notes: _notesController.text.trim(),
          dueDate: _dueDate,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _titleController,
              autofocus: widget.item == null,
              decoration: InputDecoration(
                labelText: context.l10n.checklists_item_titleLabel,
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? context.l10n.checklists_item_titleRequired
                  : null,
            ),
            const SizedBox(height: 8),
            RawAutocomplete<String>(
              textEditingController: _categoryController,
              focusNode: _categoryFocusNode,
              optionsBuilder: (value) => widget.categorySuggestions.where(
                (c) => c.toLowerCase().contains(value.text.toLowerCase()),
              ),
              onSelected: (selection) => _categoryController.text = selection,
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: AlignmentDirectional.topStart,
                child: Material(
                  elevation: 4,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final option in options)
                          ListTile(
                            title: Text(option),
                            onTap: () => onSelected(option),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) =>
                      TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: context.l10n.checklists_item_categoryLabel,
                        ),
                      ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: context.l10n.checklists_item_notesLabel,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.checklists_item_dueDateLabel),
              subtitle: Text(
                _dueDate == null ? '-' : DateFormat.yMMMd().format(_dueDate!),
              ),
              trailing: _dueDate == null
                  ? const Icon(Icons.calendar_today)
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _dueDate = null),
                    ),
              onTap: _pickDueDate,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: Text(MaterialLocalizations.of(context).saveButtonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
