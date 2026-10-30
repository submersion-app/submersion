import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template_section.dart'
    as domain;
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_editable_item.dart';
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_item_dialog.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/section_list_editor.dart';

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
  List<EditablePreDiveItem> _items = [];
  List<EditablePreDiveSection> _sections = [];
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
          EditablePreDiveSection(id: section.id, title: section.title),
      ];
      _items = [
        for (final item in items)
          EditablePreDiveItem(
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

  Future<void> _addOrEditItem({EditablePreDiveItem? item}) async {
    final result = await showDialog<EditablePreDiveItem>(
      context: context,
      builder: (context) => PreDiveItemDialog(
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
  bool _readsLaterValue(EditablePreDiveItem item) {
    // Guarded on the type as well as on the link, so malformed data (a
    // sourceItemId arriving on some other type via sync) cannot raise a
    // warning that talks about a reading this item never makes.
    if (item.itemType != PreDiveItemType.cellLinearity) return false;
    final sourceId = item.sourceItemId;
    if (sourceId == null) return false;
    final ordered = _itemsInDisplayOrder();
    final index = ordered.indexOf(item);
    final sourceIndex = ordered.indexWhere((i) => i.id == sourceId);
    return sourceIndex >= 0 && sourceIndex > index;
  }

  /// [_items] in the order the editor shows them: each section's items in
  /// section order, then the unsectioned ones (a dangling sectionId counts
  /// as unsectioned, as it does on screen). [_save] assigns sortOrder from
  /// this order, so a strict-order session enforces the order the diver
  /// saw rather than the order items happened to be added in.
  List<EditablePreDiveItem> _itemsInDisplayOrder() {
    final sectionIds = {for (final s in _sections) s.id};
    return [
      for (final s in _sections) ..._items.where((i) => i.sectionId == s.id),
      ..._items.where(
        (i) => i.sectionId == null || !sectionIds.contains(i.sectionId),
      ),
    ];
  }

  /// Removes [removed], clearing the link on any item that sourced it and
  /// naming each one in a snackbar.
  ///
  /// The link is cleared rather than the deletion blocked: the diver may be
  /// mid-restructure and about to add a replacement, and a modal refusal in
  /// the middle of reordering a checklist would be worse than a broken link
  /// the composer already degrades gracefully.
  void _removeItem(EditablePreDiveItem removed) => _removeItems({removed.id});

  /// [_removeItem] for several items at once (a section deleted together
  /// with its items). An item that sourced one of the removed items but is
  /// itself kept has its link cleared and is named in a snackbar.
  void _removeItems(Set<String> removedIds) {
    final dependants = [
      for (final i in _items)
        if (!removedIds.contains(i.id) && removedIds.contains(i.sourceItemId))
          i,
    ];
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() {
      _items = [
        for (final i in _items)
          if (!removedIds.contains(i.id))
            if (removedIds.contains(i.sourceItemId))
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
    final ordered = _itemsInDisplayOrder();
    await repository.saveItems(templateId, [
      for (var i = 0; i < ordered.length; i++)
        PreDiveChecklistTemplateItem(
          id: ordered[i].id,
          templateId: templateId,
          sectionId: ordered[i].sectionId,
          title: ordered[i].title,
          notes: ordered[i].notes,
          sortOrder: i,
          itemType: ordered[i].itemType,
          valueLabel: ordered[i].valueLabel,
          valueUnit: ordered[i].valueUnit,
          valueMin: ordered[i].valueMin,
          valueMax: ordered[i].valueMax,
          isRequired: ordered[i].isRequired,
          equipmentId: ordered[i].equipmentId,
          sourceItemId: ordered[i].sourceItemId,
          createdAt: ordered[i].createdAt,
          updatedAt: ordered[i].updatedAt,
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

    Widget buildItem(BuildContext context, EditablePreDiveItem item) =>
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
          onTap: _readOnly ? null : () => _addOrEditItem(item: item),
        );

    // An item whose sectionId matches no section in the current draft (a
    // dangling id, e.g. from sync or a since-deleted section) degrades to
    // unsectioned rather than silently vanishing from the list.
    final validSectionIds = {for (final s in _sections) s.id};
    final unsectioned = _items
        .where(
          (i) => i.sectionId == null || !validSectionIds.contains(i.sectionId),
        )
        .toList();

    return SectionListEditor<EditablePreDiveItem>(
      sections: [
        for (final section in _sections)
          SectionGroup(
            id: section.id,
            title: section.title,
            items: _items.where((i) => i.sectionId == section.id).toList(),
          ),
      ],
      unsectionedItems: unsectioned,
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
            EditablePreDiveSection(id: const Uuid().v4(), title: title),
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
          }
          _sections = _sections.where((s) => s.id != id).toList();
        });
        // Through _removeItems so a linearity item kept in another section
        // loses its link to a deleted source, as a single-item delete does.
        if (moveItemsToSectionId == null) {
          _removeItems({
            for (final i in _items)
              if (i.sectionId == id) i.id,
          });
        }
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
      onDeleteItem: (item) async => _removeItem(item),
    );
  }
}
