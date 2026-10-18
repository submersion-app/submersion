import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template_section.dart'
    as domain;
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';
import 'package:submersion/shared/widgets/section_list_editor.dart';

/// A bound once the form has validated: blank is "no bound", and unreadable
/// text cannot reach here.
double? _validatedNumber(TextEditingController controller) =>
    switch (readNumber(controller.text)) {
      NumberValue(:final value) => value,
      NumberBlank() => null,
      NumberInvalid() => null, // unreachable: validate() ran first
    };

/// An item mid-edit on this page. See checklist_template_edit_page.dart's
/// `_EditableTemplateItem` for why sections and items are held in memory
/// here instead of going through the repository directly: resolving a
/// section one at a time as each item dialog closes would touch the
/// database for a section the diver then discards by not saving the page.
class _EditablePreDiveItem {
  final String id;
  final String? sectionId;
  final String title;
  final String notes;
  final int sortOrder;
  final PreDiveItemType itemType;
  final String? valueLabel;
  final String? valueUnit;
  final double? valueMin;
  final double? valueMax;
  final bool isRequired;
  final String? equipmentId;
  final String? sourceItemId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const _EditablePreDiveItem({
    required this.id,
    this.sectionId,
    required this.title,
    this.notes = '',
    this.sortOrder = 0,
    this.itemType = PreDiveItemType.check,
    this.valueLabel,
    this.valueUnit,
    this.valueMin,
    this.valueMax,
    this.isRequired = false,
    this.equipmentId,
    this.sourceItemId,
    required this.createdAt,
    required this.updatedAt,
  });

  _EditablePreDiveItem copyWith({
    String? id,
    Object? sectionId = _undefined,
    String? title,
    String? notes,
    int? sortOrder,
    PreDiveItemType? itemType,
    Object? valueLabel = _undefined,
    Object? valueUnit = _undefined,
    Object? valueMin = _undefined,
    Object? valueMax = _undefined,
    bool? isRequired,
    Object? equipmentId = _undefined,
    Object? sourceItemId = _undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return _EditablePreDiveItem(
      id: id ?? this.id,
      sectionId: sectionId == _undefined
          ? this.sectionId
          : sectionId as String?,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      sortOrder: sortOrder ?? this.sortOrder,
      itemType: itemType ?? this.itemType,
      valueLabel: valueLabel == _undefined
          ? this.valueLabel
          : valueLabel as String?,
      valueUnit: valueUnit == _undefined
          ? this.valueUnit
          : valueUnit as String?,
      valueMin: valueMin == _undefined ? this.valueMin : valueMin as double?,
      valueMax: valueMax == _undefined ? this.valueMax : valueMax as double?,
      isRequired: isRequired ?? this.isRequired,
      equipmentId: equipmentId == _undefined
          ? this.equipmentId
          : equipmentId as String?,
      sourceItemId: sourceItemId == _undefined
          ? this.sourceItemId
          : sourceItemId as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

const _undefined = Object();

/// A section mid-edit on this page -- see [_EditablePreDiveItem] for why.
class _EditablePreDiveSection {
  final String id;
  final String title;

  const _EditablePreDiveSection({required this.id, required this.title});

  _EditablePreDiveSection copyWith({String? title}) =>
      _EditablePreDiveSection(id: id, title: title ?? this.title);
}

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
  List<_EditablePreDiveItem> _items = [];
  List<_EditablePreDiveSection> _sections = [];
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
    final sections = await repository.getSectionsForTemplate(
      widget.templateId!,
    );
    if (!mounted) return;
    setState(() {
      _existing = template;
      _nameController.text = template?.name ?? '';
      _descriptionController.text = template?.description ?? '';
      _categoryController.text = template?.category ?? '';
      _strictOrder = template?.strictOrder ?? false;
      _sections = [
        for (final section in sections)
          _EditablePreDiveSection(id: section.id, title: section.title),
      ];
      _items = [
        for (final item in items)
          _EditablePreDiveItem(
            id: item.id,
            sectionId: item.sectionId,
            title: item.title,
            notes: item.notes,
            sortOrder: item.sortOrder,
            itemType: item.itemType,
            valueLabel: item.valueLabel,
            valueUnit: item.valueUnit,
            valueMin: item.valueMin,
            valueMax: item.valueMax,
            isRequired: item.isRequired,
            equipmentId: item.equipmentId,
            sourceItemId: item.sourceItemId,
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
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _addOrEditItem({_EditablePreDiveItem? item}) async {
    final result = await showDialog<_EditablePreDiveItem>(
      context: context,
      builder: (context) => _PreDiveItemDialog(
        item: item,
        defaultSortOrder: _items.length,
        siblings: _items,
        sections: _sections,
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

  /// Whether [item] is a linearity item whose source sorts after it in
  /// [_items], the same list order [_save] passes to the repository.
  ///
  /// Deliberately not gated on strict order. Strict order makes the trap
  /// unavoidable, because the runner will not let the diver reach the air
  /// row first, but the same trap exists without it: a diver working the
  /// list top to bottom meets the linearity row with no air reading, records
  /// the oxygen value anyway, and ends up with an item that can only be
  /// completed properly by resetting it. The warning is worth showing in
  /// both modes, and its wording claims nothing about gating.
  bool _readsLaterValue(_EditablePreDiveItem item) {
    // Guarded on the type as well as on the link, so malformed data (a
    // sourceItemId arriving on some other type via sync) cannot raise a
    // warning that talks about a reading this item never makes.
    if (item.itemType != PreDiveItemType.cellLinearity) return false;
    final sourceId = item.sourceItemId;
    if (sourceId == null) return false;
    final index = _items.indexOf(item);
    final sourceIndex = _items.indexWhere((i) => i.id == sourceId);
    return sourceIndex >= 0 && sourceIndex > index;
  }

  /// Removes [removed], clearing the link on any item that sourced it and
  /// naming each one in a snackbar.
  ///
  /// The link is cleared rather than the deletion blocked: the diver may be
  /// mid-restructure and about to add a replacement, and a modal refusal in
  /// the middle of reordering a checklist would be worse than a broken link
  /// the composer already degrades gracefully.
  void _removeItem(_EditablePreDiveItem removed) {
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

    // Sections must exist before the items referencing them are (re)inserted
    // -- saveItems satisfies a foreign key, not a dangling draft id.
    await repository.saveSections(templateId, [
      for (final section in _sections)
        domain.PreDiveChecklistTemplateSection(
          id: section.id,
          templateId: templateId,
          title: section.title,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
    ]);

    // sortOrder reassigned from list position at save time.
    await repository.saveItems(templateId, [
      for (var i = 0; i < _items.length; i++)
        PreDiveChecklistTemplateItem(
          id: _items[i].id,
          templateId: templateId,
          sectionId: _items[i].sectionId,
          title: _items[i].title,
          notes: _items[i].notes,
          sortOrder: i,
          itemType: _items[i].itemType,
          valueLabel: _items[i].valueLabel,
          valueUnit: _items[i].valueUnit,
          valueMin: _items[i].valueMin,
          valueMax: _items[i].valueMax,
          isRequired: _items[i].isRequired,
          equipmentId: _items[i].equipmentId,
          sourceItemId: _items[i].sourceItemId,
          createdAt: _items[i].createdAt,
          updatedAt: _items[i].updatedAt,
        ),
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
                  _buildSectionEditor(context),
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

  Widget _buildSectionEditor(BuildContext context) {
    final l10n = context.l10n;

    Widget buildItem(BuildContext context, _EditablePreDiveItem item) =>
        ListTile(
          title: Text(item.title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                [
                  _typeLabel(context, item.itemType),
                  if (item.isRequired) l10n.preDive_item_required,
                ].join(' - '),
              ),
              // A linearity row that sorts above its source is worth
              // flagging in either mode: strict order makes it unavoidable,
              // and without it a diver working top to bottom still meets
              // the row before the air reading exists. See
              // _readsLaterValue. Warn, never block.
              if (_readsLaterValue(item))
                Text(
                  l10n.preDive_item_sourceBelow,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
            ],
          ),
          // No leading column at all in read-only mode -- see the removed
          // comment above the old ReorderableListView for why.
          leading: _readOnly
              ? null
              : IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _removeItem(item),
                ),
          onTap: _readOnly ? null : () => _addOrEditItem(item: item),
        );

    return SectionListEditor<_EditablePreDiveItem>(
      sections: [
        for (final section in _sections)
          SectionGroup(
            id: section.id,
            title: section.title,
            items: _items.where((i) => i.sectionId == section.id).toList(),
          ),
      ],
      unsectionedItems: _items.where((i) => i.sectionId == null).toList(),
      itemId: (item) => item.id,
      itemBuilder: buildItem,
      addSectionLabel: l10n.sectionEditor_addSection,
      newSectionTitle: l10n.sectionEditor_newSectionTitle,
      noSectionLabel: l10n.sectionEditor_noSection,
      readOnly: _readOnly,
      onAddSection: (title) async {
        setState(() {
          _sections = [
            ..._sections,
            _EditablePreDiveSection(id: const Uuid().v4(), title: title),
          ];
        });
      },
      onRenameSection: (id, title) async {
        setState(() {
          _sections = [
            for (final s in _sections)
              if (s.id == id) s.copyWith(title: title) else s,
          ];
        });
      },
      onReorderSections: (orderedIds) async {
        setState(() {
          final byId = {for (final s in _sections) s.id: s};
          _sections = [for (final id in orderedIds) byId[id]!];
        });
      },
      onDeleteSection: (id, {moveItemsToSectionId}) async {
        setState(() {
          if (moveItemsToSectionId != null) {
            _items = [
              for (final i in _items)
                if (i.sectionId == id)
                  i.copyWith(sectionId: moveItemsToSectionId)
                else
                  i,
            ];
          } else {
            _items = _items.where((i) => i.sectionId != id).toList();
          }
          _sections = _sections.where((s) => s.id != id).toList();
        });
      },
      onMoveItem: (itemId, targetSectionId, orderedIds) async {
        setState(() {
          final byId = {for (final i in _items) i.id: i};
          _items = [
            for (final id in orderedIds)
              id == itemId
                  ? byId[id]!.copyWith(sectionId: targetSectionId)
                  : byId[id]!,
          ];
        });
      },
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
  final _EditablePreDiveItem? item;
  final int defaultSortOrder;

  /// The other items in this template, so a cell linearity item can name one
  /// of them as the source of its air reading (issue #986).
  final List<_EditablePreDiveItem> siblings;

  /// This template's sections, for the section picker -- see
  /// _EditableTemplateItem's dialog in checklist_template_edit_page.dart for
  /// why this is a picker over the draft's own sections rather than free
  /// text.
  final List<_EditablePreDiveSection> sections;

  const _PreDiveItemDialog({
    required this.item,
    required this.defaultSortOrder,
    this.siblings = const [],
    this.sections = const [],
  });

  @override
  State<_PreDiveItemDialog> createState() => _PreDiveItemDialogState();
}

class _PreDiveItemDialogState extends State<_PreDiveItemDialog> {
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
  List<_EditablePreDiveItem> get _sourceCandidates => [
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
      _EditablePreDiveItem(
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
