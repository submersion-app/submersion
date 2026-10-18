import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Create/edit page for a checklist template and its items.
class ChecklistTemplateEditPage extends ConsumerStatefulWidget {
  final String? templateId;

  const ChecklistTemplateEditPage({super.key, this.templateId});

  bool get isEditing => templateId != null;

  @override
  ConsumerState<ChecklistTemplateEditPage> createState() =>
      _ChecklistTemplateEditPageState();
}

/// An item mid-edit on this page, before its section title (free text, same
/// UX as before issue #3360) has been resolved to a real section row. The
/// page holds a list of these instead of [ChecklistTemplateItem] directly,
/// since items here are edited in memory and only persisted as a whole on
/// [_ChecklistTemplateEditPageState._save] -- resolving section titles to
/// ids one at a time as the dialog closes would create a section the diver
/// then discards by not saving the page.
class _EditableTemplateItem {
  final String id;
  final String title;
  final String? sectionTitle;
  final String notes;
  final int? dueOffsetDays;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const _EditableTemplateItem({
    required this.id,
    required this.title,
    this.sectionTitle,
    this.notes = '',
    this.dueOffsetDays,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
}

class _ChecklistTemplateEditPageState
    extends ConsumerState<ChecklistTemplateEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<_EditableTemplateItem> _items = [];
  ChecklistTemplate? _existing;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repository = ref.read(checklistTemplateRepositoryProvider);
    final template = await repository.getTemplateById(widget.templateId!);
    final items = await repository.getItemsForTemplate(widget.templateId!);
    final sections = await repository.getSectionsForTemplate(
      widget.templateId!,
    );
    final sectionTitleById = {for (final s in sections) s.id: s.title};
    if (!mounted) return;
    setState(() {
      _existing = template;
      _nameController.text = template?.name ?? '';
      _descriptionController.text = template?.description ?? '';
      _items = [
        for (final item in items)
          _EditableTemplateItem(
            id: item.id,
            title: item.title,
            sectionTitle: item.sectionId == null
                ? null
                : sectionTitleById[item.sectionId],
            notes: item.notes,
            dueOffsetDays: item.dueOffsetDays,
            sortOrder: item.sortOrder,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
          ),
      ];
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _addOrEditItem({_EditableTemplateItem? item}) async {
    final result = await _showItemDialog(item: item);
    if (result == null) return;
    setState(() {
      if (item == null) {
        _items = [..._items, result];
      } else {
        _items = [
          for (final existing in _items)
            if (identical(existing, item)) result else existing,
        ];
      }
    });
  }

  Future<_EditableTemplateItem?> _showItemDialog({
    _EditableTemplateItem? item,
  }) {
    return showDialog<_EditableTemplateItem>(
      context: context,
      builder: (context) =>
          _ChecklistItemDialog(item: item, defaultSortOrder: _items.length),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repository = ref.read(checklistTemplateRepositoryProvider);
    final navigator = Navigator.of(context);
    String templateId;
    if (_existing == null) {
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      final created = await repository.createTemplate(
        ChecklistTemplate(
          id: '',
          diverId: diverId,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      templateId = created.id;
    } else {
      await repository.updateTemplate(
        _existing!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
        ),
      );
      templateId = _existing!.id;
    }

    // Resolve each distinct typed section title to a real section row once
    // (find-or-create is async; this must finish before building the final
    // item list), folding titles that differ only in case onto the same
    // section, exactly like the trip checklist's picker.
    final sectionIdByTitle = <String, String?>{};
    for (final item in _items) {
      final title = item.sectionTitle;
      if (title == null) continue;
      final key = title.toLowerCase();
      sectionIdByTitle[key] ??= await repository.findOrCreateSectionId(
        templateId,
        title,
      );
    }

    await repository.saveItems(templateId, [
      for (final item in _items)
        ChecklistTemplateItem(
          id: item.id,
          templateId: templateId,
          title: item.title,
          sectionId: item.sectionTitle == null
              ? null
              : sectionIdByTitle[item.sectionTitle!.toLowerCase()],
          notes: item.notes,
          dueOffsetDays: item.dueOffsetDays,
          sortOrder: item.sortOrder,
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
        ),
    ]);
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? context.l10n.checklists_templates_editTemplate
              : context.l10n.checklists_templates_addTemplate,
        ),
        actions: [
          AppBarTextAction(
            label: context.l10n.common_action_save,
            onPressed: _loading ? null : _save,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: context.l10n.checklists_template_nameLabel,
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? context.l10n.checklists_template_nameRequired
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText:
                          context.l10n.checklists_template_descriptionLabel,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.l10n.checklists_template_itemsHeader,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: true,
                    onReorderItem: (oldIndex, newIndex) {
                      setState(() {
                        final items = [..._items];
                        final item = items.removeAt(oldIndex);
                        items.insert(newIndex, item);
                        _items = items;
                      });
                    },
                    children: [
                      for (var i = 0; i < _items.length; i++)
                        ListTile(
                          key: ValueKey(_items[i].id),
                          title: Text(_items[i].title),
                          subtitle: _items[i].sectionTitle == null
                              ? null
                              : Text(_items[i].sectionTitle!),
                          leading: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => setState(
                              () => _items = [..._items]..removeAt(i),
                            ),
                          ),
                          onTap: () => _addOrEditItem(item: _items[i]),
                        ),
                    ],
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.checklists_template_addItem),
                    onPressed: () => _addOrEditItem(),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Add/edit dialog for a single template item.
///
/// Owns its ephemeral [TextEditingController]s and disposes them in its own
/// [State.dispose]. Disposing them from `showDialog(...).whenComplete(...)`
/// instead frees the controllers the instant the route is popped, while the
/// dialog's exit transition is still rebuilding these fields — which throws
/// "TextEditingController used after being disposed" (and, on release builds,
/// trips the InheritedElement `_dependents` assertion) mid-animation.
class _ChecklistItemDialog extends StatefulWidget {
  final _EditableTemplateItem? item;
  final int defaultSortOrder;

  const _ChecklistItemDialog({
    required this.item,
    required this.defaultSortOrder,
  });

  @override
  State<_ChecklistItemDialog> createState() => _ChecklistItemDialogState();
}

class _ChecklistItemDialogState extends State<_ChecklistItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _categoryController;
  late final TextEditingController _notesController;
  late final TextEditingController _offsetController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item?.title ?? '');
    _categoryController = TextEditingController(
      text: widget.item?.sectionTitle ?? '',
    );
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
    _categoryController.dispose();
    _notesController.dispose();
    _offsetController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final category = _categoryController.text.trim();
    Navigator.of(context).pop(
      _EditableTemplateItem(
        id: widget.item?.id ?? const Uuid().v4(),
        title: _titleController.text.trim(),
        sectionTitle: category.isEmpty ? null : category,
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
              TextFormField(
                controller: _categoryController,
                decoration: InputDecoration(
                  labelText: context.l10n.checklists_item_categoryLabel,
                ),
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
