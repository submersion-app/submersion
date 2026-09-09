import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';

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

  /// Built-ins reach this page as viewers: the list opens them so a diver
  /// can read what a default checks before cloning it. Everything that would
  /// mutate the template is withheld rather than merely disabled, so the page
  /// reads as a viewer instead of a broken editor.
  ///
  /// False until [_load] lands, so read [_editable] rather than `!_readOnly`
  /// for anything that offers editing.
  bool get _readOnly => _existing?.isBuiltIn ?? false;

  /// Whether the editing chrome may be shown yet.
  ///
  /// The built-in flag lives on the fetched row, so while a template is in
  /// flight this page does not know which mode it is in. Treating "not known
  /// to be read-only" as editable put the edit title and a Save button on the
  /// first frame and then withdrew them the instant a built-in resolved.
  /// Waiting is the claim that can only be upgraded, never retracted.
  ///
  /// A brand new template has nothing to fetch, so it is editable at once.
  bool get _editable => !_loading && !_readOnly;

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
        siblings: _items,
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

  /// Whether the item at [index] is a linearity item whose source sorts
  /// after it.
  ///
  /// Deliberately not gated on strict order. Strict order makes the trap
  /// unavoidable, because the runner will not let the diver reach the air
  /// row first, but the same trap exists without it: a diver working the
  /// list top to bottom meets the linearity row with no air reading, records
  /// the oxygen value anyway, and ends up with an item that can only be
  /// completed properly by resetting it. The warning is worth showing in
  /// both modes, and its wording claims nothing about gating.
  bool _readsLaterValue(int index) {
    final item = _items[index];
    // Guarded on the type as well as on the link, so malformed data (a
    // sourceItemId arriving on some other type via sync) cannot raise a
    // warning that talks about a reading this item never makes.
    if (item.itemType != PreDiveItemType.cellLinearity) return false;
    final sourceId = item.sourceItemId;
    if (sourceId == null) return false;
    final sourceIndex = _items.indexWhere((i) => i.id == sourceId);
    return sourceIndex >= 0 && sourceIndex > index;
  }

  /// Removes the item at [index], clearing the link on any item that sourced
  /// it and naming each one in a snackbar.
  ///
  /// The link is cleared rather than the deletion blocked: the diver may be
  /// mid-restructure and about to add a replacement, and a modal refusal in
  /// the middle of reordering a checklist would be worse than a broken link
  /// the composer already degrades gracefully.
  void _removeItem(int index) {
    final removed = _items[index];
    final dependants = [
      for (final i in _items)
        if (i.sourceItemId == removed.id) i,
    ];
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() {
      _items = [
        for (final i in _items)
          if (i.id != removed.id)
            if (i.sourceItemId == removed.id)
              i.copyWith(sourceItemId: null)
            else
              i,
      ];
    });
    for (final d in dependants) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.preDive_item_sourceCleared(d.title))),
      );
    }
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
      PreDiveItemType.equipment => context.l10n.preDive_item_type_equipment,
      PreDiveItemType.cellLinearity =>
        context.l10n.preDive_item_type_cellLinearity,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          !widget.isEditing
              ? l10n.preDive_edit_titleNew
              : _editable
              ? l10n.preDive_edit_titleEdit
              : l10n.preDive_edit_titleView,
        ),
        actions: [
          if (_editable)
            AppBarTextAction(label: l10n.common_action_save, onPressed: _save),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_readOnly) ...[
                    Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: Text(l10n.preDive_edit_builtInNotice),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
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
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                [
                                  if (_items[i].section != null)
                                    _items[i].section!,
                                  _typeLabel(context, _items[i].itemType),
                                  if (_items[i].isRequired)
                                    l10n.preDive_item_required,
                                ].join(' - '),
                              ),
                              // A linearity row that sorts above its
                              // source is worth flagging in either mode:
                              // strict order makes it unavoidable, and
                              // without it a diver working top to bottom
                              // still meets the row before the air reading
                              // exists. See _readsLaterValue. Warn, never
                              // block.
                              if (_readsLaterValue(i))
                                Text(
                                  l10n.preDive_item_sourceBelow,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                ),
                            ],
                          ),
                          // No leading column at all in read-only mode. An
                          // empty checkbox was standing in as a spacer, but
                          // that glyph reads as "tap to toggle" on a row
                          // whose onTap is null, and these template items
                          // have no state to toggle. Nothing here needs
                          // aligning either: every row in this mode lacks the
                          // delete button, so reserving its column would hold
                          // space for a control that never appears.
                          leading: _readOnly
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _removeItem(i),
                                ),
                          onTap: _readOnly
                              ? null
                              : () => _addOrEditItem(item: _items[i]),
                        ),
                    ],
                  ),
                  if (!_readOnly)
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: Text(l10n.preDive_edit_addItem),
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
class _PreDiveItemDialog extends StatefulWidget {
  final PreDiveChecklistTemplateItem? item;
  final String templateId;
  final int defaultSortOrder;

  /// The other items in this template, so a cell linearity item can name one
  /// of them as the source of its air reading (issue #986).
  final List<PreDiveChecklistTemplateItem> siblings;

  const _PreDiveItemDialog({
    required this.item,
    required this.templateId,
    required this.defaultSortOrder,
    this.siblings = const [],
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
  List<PreDiveChecklistTemplateItem> get _sourceCandidates => [
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
      PreDiveItemType.equipment => context.l10n.preDive_item_type_equipment,
      PreDiveItemType.cellLinearity =>
        context.l10n.preDive_item_type_cellLinearity,
    };
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final section = _sectionController.text.trim();
    final valueLabel = _valueLabelController.text.trim();
    final valueUnit = _valueUnitController.text.trim();
    // A cell linearity item records a number exactly as a value item does,
    // so it carries the same label, unit and threshold fields. Those
    // thresholds mean a percentage there rather than a unit of measure.
    final isValue =
        _itemType == PreDiveItemType.value ||
        _itemType == PreDiveItemType.cellLinearity;
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
        valueMin: isValue ? parseUserDecimal(_valueMinController.text) : null,
        valueMax: isValue ? parseUserDecimal(_valueMaxController.text) : null,
        isRequired: _isRequired,
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
