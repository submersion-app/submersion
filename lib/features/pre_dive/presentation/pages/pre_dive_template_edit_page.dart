import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Create/edit page for a pre-dive checklist template and its items.
class PreDiveTemplateEditPage extends ConsumerStatefulWidget {
  final String? templateId;

  const PreDiveTemplateEditPage({super.key, this.templateId});

  bool get isEditing => templateId != null;

  @override
  ConsumerState<PreDiveTemplateEditPage> createState() =>
      _PreDiveTemplateEditPageState();
}

class _PreDiveTemplateEditPageState
    extends ConsumerState<PreDiveTemplateEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  bool _strictOrder = false;
  List<PreDiveChecklistTemplateItem> _items = [];
  PreDiveChecklistTemplate? _existing;
  bool _loading = false;

  /// Built-ins never reach this page from the list UI, but guard anyway.
  bool get _readOnly => _existing?.isBuiltIn ?? false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repository = ref.read(preDiveTemplateRepositoryProvider);
    final template = await repository.getTemplateById(widget.templateId!);
    final items = await repository.getItemsForTemplate(widget.templateId!);
    if (!mounted) return;
    setState(() {
      _existing = template;
      _nameController.text = template?.name ?? '';
      _descriptionController.text = template?.description ?? '';
      _categoryController.text = template?.category ?? '';
      _strictOrder = template?.strictOrder ?? false;
      _items = items;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _addOrEditItem({PreDiveChecklistTemplateItem? item}) async {
    final result = await showDialog<PreDiveChecklistTemplateItem>(
      context: context,
      builder: (context) => _PreDiveItemDialog(
        item: item,
        templateId: widget.templateId ?? '',
        defaultSortOrder: _items.length,
      ),
    );
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repository = ref.read(preDiveTemplateRepositoryProvider);
    final navigator = Navigator.of(context);
    final category = _categoryController.text.trim();
    String templateId;
    if (_existing == null) {
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      final created = await repository.createTemplate(
        PreDiveChecklistTemplate(
          id: '',
          diverId: diverId,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          category: category.isEmpty ? null : category,
          strictOrder: _strictOrder,
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
          category: category.isEmpty ? null : category,
          strictOrder: _strictOrder,
        ),
      );
      templateId = _existing!.id;
    }
    // sortOrder reassigned from list position at save time.
    await repository.saveItems(templateId, [
      for (var i = 0; i < _items.length; i++)
        _items[i].copyWith(templateId: templateId, sortOrder: i),
    ]);
    if (mounted) navigator.pop();
  }

  String _typeLabel(BuildContext context, PreDiveItemType type) {
    return switch (type) {
      PreDiveItemType.check => context.l10n.preDive_item_type_check,
      PreDiveItemType.value => context.l10n.preDive_item_type_value,
      PreDiveItemType.equipmentSet =>
        context.l10n.preDive_item_type_equipmentSet,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? l10n.preDive_edit_titleEdit
              : l10n.preDive_edit_titleNew,
        ),
        actions: [
          TextButton(
            onPressed: _loading || _readOnly ? null : _save,
            child: Text(l10n.common_action_save),
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
                    enabled: !_readOnly,
                    decoration: InputDecoration(
                      labelText: l10n.preDive_edit_name,
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? l10n.preDive_edit_nameRequired
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    enabled: !_readOnly,
                    decoration: InputDecoration(
                      labelText: l10n.preDive_edit_description,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _categoryController,
                    enabled: !_readOnly,
                    decoration: InputDecoration(
                      labelText: l10n.preDive_edit_category,
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.preDive_edit_strictOrder),
                    subtitle: Text(l10n.preDive_edit_strictOrderHelp),
                    value: _strictOrder,
                    onChanged: _readOnly
                        ? null
                        : (value) => setState(() => _strictOrder = value),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.checklists_template_itemsHeader,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: !_readOnly,
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
                          key: ValueKey(
                            _items[i].id.isEmpty ? 'new-$i' : _items[i].id,
                          ),
                          title: Text(_items[i].title),
                          subtitle: Text(
                            [
                              if (_items[i].section != null) _items[i].section!,
                              _typeLabel(context, _items[i].itemType),
                              if (_items[i].isRequired)
                                l10n.preDive_item_required,
                            ].join(' - '),
                          ),
                          leading: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _readOnly
                                ? null
                                : () => setState(
                                    () => _items = [..._items]..removeAt(i),
                                  ),
                          ),
                          onTap: _readOnly
                              ? null
                              : () => _addOrEditItem(item: _items[i]),
                        ),
                    ],
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(l10n.preDive_edit_addItem),
                    onPressed: _readOnly ? null : () => _addOrEditItem(),
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
class _PreDiveItemDialog extends StatefulWidget {
  final PreDiveChecklistTemplateItem? item;
  final String templateId;
  final int defaultSortOrder;

  const _PreDiveItemDialog({
    required this.item,
    required this.templateId,
    required this.defaultSortOrder,
  });

  @override
  State<_PreDiveItemDialog> createState() => _PreDiveItemDialogState();
}

class _PreDiveItemDialogState extends State<_PreDiveItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _sectionController;
  late final TextEditingController _notesController;
  late final TextEditingController _valueLabelController;
  late final TextEditingController _valueUnitController;
  late final TextEditingController _valueMinController;
  late final TextEditingController _valueMaxController;
  late PreDiveItemType _itemType;
  late bool _isRequired;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item?.title ?? '');
    _sectionController = TextEditingController(
      text: widget.item?.section ?? '',
    );
    _notesController = TextEditingController(text: widget.item?.notes ?? '');
    _valueLabelController = TextEditingController(
      text: widget.item?.valueLabel ?? '',
    );
    _valueUnitController = TextEditingController(
      text: widget.item?.valueUnit ?? '',
    );
    _valueMinController = TextEditingController(
      text: widget.item?.valueMin?.toString() ?? '',
    );
    _valueMaxController = TextEditingController(
      text: widget.item?.valueMax?.toString() ?? '',
    );
    _itemType = widget.item?.itemType ?? PreDiveItemType.check;
    _isRequired = widget.item?.isRequired ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _sectionController.dispose();
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
    };
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final section = _sectionController.text.trim();
    final valueLabel = _valueLabelController.text.trim();
    final valueUnit = _valueUnitController.text.trim();
    final isValue = _itemType == PreDiveItemType.value;
    Navigator.of(context).pop(
      PreDiveChecklistTemplateItem(
        id: widget.item?.id ?? const Uuid().v4(),
        templateId: widget.templateId,
        section: section.isEmpty ? null : section,
        title: _titleController.text.trim(),
        notes: _notesController.text.trim(),
        sortOrder: widget.item?.sortOrder ?? widget.defaultSortOrder,
        itemType: _itemType,
        valueLabel: isValue && valueLabel.isNotEmpty ? valueLabel : null,
        valueUnit: isValue && valueUnit.isNotEmpty ? valueUnit : null,
        valueMin: isValue
            ? double.tryParse(_valueMinController.text.trim())
            : null,
        valueMax: isValue
            ? double.tryParse(_valueMaxController.text.trim())
            : null,
        isRequired: _isRequired,
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
              TextFormField(
                controller: _sectionController,
                decoration: InputDecoration(
                  labelText: l10n.preDive_item_section,
                ),
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
              if (_itemType == PreDiveItemType.value) ...[
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
                  decoration: InputDecoration(
                    labelText: l10n.preDive_item_valueMin,
                  ),
                ),
                TextFormField(
                  controller: _valueMaxController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.preDive_item_valueMax,
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
