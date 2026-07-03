import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Create/edit page for a checklist template and its items.
class ChecklistTemplateEditPage extends ConsumerStatefulWidget {
  final String? templateId;

  const ChecklistTemplateEditPage({super.key, this.templateId});

  bool get isEditing => templateId != null;

  @override
  ConsumerState<ChecklistTemplateEditPage> createState() =>
      _ChecklistTemplateEditPageState();
}

class _ChecklistTemplateEditPageState
    extends ConsumerState<ChecklistTemplateEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<ChecklistTemplateItem> _items = [];
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
    if (!mounted) return;
    setState(() {
      _existing = template;
      _nameController.text = template?.name ?? '';
      _descriptionController.text = template?.description ?? '';
      _items = items;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _addOrEditItem({ChecklistTemplateItem? item}) async {
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

  Future<ChecklistTemplateItem?> _showItemDialog({
    ChecklistTemplateItem? item,
  }) {
    return showDialog<ChecklistTemplateItem>(
      context: context,
      builder: (context) => _ChecklistItemDialog(
        item: item,
        templateId: widget.templateId ?? '',
        defaultSortOrder: _items.length,
      ),
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
    await repository.saveItems(templateId, [
      for (final item in _items) item.copyWith(templateId: templateId),
    ]);
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.checklists_templates_pageTitle),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: Text(context.l10n.common_action_save),
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
                          subtitle: _items[i].category == null
                              ? null
                              : Text(_items[i].category!),
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
  final ChecklistTemplateItem? item;
  final String templateId;
  final int defaultSortOrder;

  const _ChecklistItemDialog({
    required this.item,
    required this.templateId,
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
      text: widget.item?.category ?? '',
    );
    _notesController = TextEditingController(text: widget.item?.notes ?? '');
    _offsetController = TextEditingController(
      text: widget.item?.dueOffsetDays?.toString() ?? '',
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
      ChecklistTemplateItem(
        id: widget.item?.id ?? const Uuid().v4(),
        templateId: widget.templateId,
        title: _titleController.text.trim(),
        category: category.isEmpty ? null : category,
        notes: _notesController.text.trim(),
        dueOffsetDays: int.tryParse(_offsetController.text.trim()),
        sortOrder: widget.item?.sortOrder ?? widget.defaultSortOrder,
        createdAt: widget.item?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.checklists_template_addItem),
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
              TextFormField(
                controller: _categoryController,
                decoration: InputDecoration(
                  labelText: context.l10n.checklists_item_categoryLabel,
                ),
              ),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: context.l10n.checklists_item_notesLabel,
                ),
              ),
              TextFormField(
                controller: _offsetController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.l10n.checklists_item_dueOffsetLabel,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final parsed = int.tryParse(value.trim());
                  return (parsed == null || parsed < 0)
                      ? context.l10n.checklists_item_dueOffsetInvalid
                      : null;
                },
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
