import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template_section.dart';
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_editable_item.dart';
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_item_dialog.dart';
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_template_draft.dart';
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_template_save.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_editor_host.dart';
import 'package:submersion/shared/widgets/section_list_editor.dart';

/// Create/edit page for a pre-dive checklist template and its items.
///
/// An editor with no read page (issue #4527, phase 4): a user template
/// opens on the shared Cancel and Save bar, asks before its changes are
/// left behind, and writes the template, its sections and its items in one
/// transaction and one History entry. A built-in template opens as a
/// viewer: the plain bar, a back arrow and no Save, with no sitting.
class PreDiveTemplateEditPage extends ConsumerStatefulWidget {
  final String? templateId;

  const PreDiveTemplateEditPage({super.key, this.templateId});

  bool get isEditing => templateId != null;

  @override
  ConsumerState<PreDiveTemplateEditPage> createState() =>
      _PreDiveTemplateEditPageState();
}

class _PreDiveTemplateEditPageState
    extends ConsumerState<PreDiveTemplateEditPage>
    with RecordEditorHost<PreDiveTemplateEditPage, PreDiveTemplateDraft> {
  static final _log = LoggerService.forClass(PreDiveTemplateEditPage);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  bool _strictOrder = false;
  List<EditablePreDiveItem> _items = [];
  List<EditablePreDiveSection> _sections = [];

  /// Section titles being typed, by section id: the section editor renames
  /// a section only when its title field lets go, and a title being typed
  /// is already a change.
  final Map<String, String> _typedTitles = {};

  /// [_sections] as shown, with each title being typed as the rename it
  /// will become: trimmed, and the title it had when typed blank.
  List<EditablePreDiveSection> get _shownSections => [
    for (final section in _sections)
      switch (_typedTitles[section.id]?.trim()) {
        final typed? when typed.isNotEmpty => section.copyWith(title: typed),
        _ => section,
      },
  ];
  bool _loaded = false;

  /// The loaded template is a built-in, which this page only shows.
  bool _builtIn = false;

  /// Built-ins reach this page as viewers: the list opens them so a diver
  /// can read what a default checks before cloning it. Everything that would
  /// mutate the template is withheld rather than merely disabled, so the page
  /// reads as a viewer instead of a broken editor.
  ///
  /// False until [_load] lands, so read [_editable] rather than `!_readOnly`
  /// for anything that offers editing.
  bool get _readOnly => _builtIn;

  /// Whether the editing chrome may be shown yet.
  ///
  /// The built-in flag lives on the fetched row, so while a template is in
  /// flight this page does not know which mode it is in. Treating "not known
  /// to be read-only" as editable put the edit title and a Save button on the
  /// first frame and then withdrew them the instant a built-in resolved.
  /// Waiting is the claim that can only be upgraded, never retracted.
  ///
  /// It follows what was loaded, not the sitting: the sitting ends as the
  /// page leaves (a Save, a discard, a change of diver), and the title must
  /// not turn to "View" on the way out. A brand new template has nothing to
  /// fetch, so it is editable at once.
  bool get _editable => _loaded && !_builtIn;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(editorChanged);
    _descriptionController.addListener(editorChanged);
    _categoryController.addListener(editorChanged);
    if (widget.isEditing) {
      _load();
    } else {
      // A new template opens on its empty form, so the first frame shows
      // the Cancel and Save bar.
      _loaded = true;
      openEditor();
    }
  }

  Future<void> _load() async {
    final repository = ref.read(preDiveTemplateRepositoryProvider);
    final id = widget.templateId!;
    final PreDiveChecklistTemplate? template;
    final List<PreDiveChecklistTemplateItem> items;
    final List<PreDiveChecklistTemplateSection> sections;
    try {
      template = await repository.getTemplateById(id);
      items = await repository.getItemsForTemplate(id);
      sections = await repository.getSectionsForTemplate(id);
    } catch (error, stackTrace) {
      _log.warning(
        'Loading pre-dive template $id failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) _leaveUnopened(context.l10n.recordEdit_loadFailed);
      return;
    }
    if (!mounted) return;
    // A stale link, or a template deleted on another device: there is
    // nothing to show, and saving the empty form would make a new one.
    if (template == null) {
      _leaveUnopened(context.l10n.preDive_edit_notFound);
      return;
    }
    setState(() {
      _builtIn = template!.isBuiltIn;
      _nameController.text = template.name;
      _descriptionController.text = template.description;
      _categoryController.text = template.category ?? '';
      _strictOrder = template.strictOrder;
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
      _loaded = true;
    });
    // A built-in can only be read: no sitting, so the plain bar stays.
    if (!_builtIn) openEditor();
  }

  /// Says [message] and leaves a template that could not be opened.
  void _leaveUnopened(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    leaveEditor();
  }

  @override
  void dispose() {
    disposeEditor();
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  /// Changes the form and hands it to the sitting.
  void _change(VoidCallback change) {
    setState(change);
    editorChanged();
  }

  Future<void> _addOrEditItem({EditablePreDiveItem? item}) async {
    final result = await showDialog<EditablePreDiveItem>(
      context: context,
      builder: (context) => PreDiveItemDialog(
        item: item,
        defaultSortOrder: _items.length,
        siblings: _items,
        // A title being typed commits only once the dialog takes the
        // focus: offer the titles as shown.
        sections: _shownSections,
      ),
    );
    if (result == null || !mounted) return;
    _change(() {
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

  /// Whether [item] is a linearity item whose source sorts after it in the
  /// order shown, the order Save writes ([writePreDiveTemplate]).
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
  /// as unsectioned, as it does on screen). Save assigns sortOrder from
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
    _change(() {
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

  @override
  String get editorTable => 'pre_dive_checklist_templates';

  @override
  String? get editorStoredId => widget.templateId;

  @override
  String? get editorLeaveLocation => '/pre-dive-checklists';

  /// The edit title once a template that can be edited has loaded (see
  /// [_editable]): while one loads, and for a built-in, the page claims no
  /// editing, and it keeps the title as it leaves.
  @override
  String editorTitle(BuildContext context) => !widget.isEditing
      ? context.l10n.preDive_edit_titleNew
      : _editable
      ? context.l10n.preDive_edit_titleEdit
      : context.l10n.preDive_edit_titleView;

  @override
  PreDiveTemplateDraft readEditorDraft() => preDiveTemplateDraft(
    name: _nameController.text,
    description: _descriptionController.text,
    category: _categoryController.text,
    strictOrder: _strictOrder,
    sections: _shownSections,
    itemsInDisplayOrder: _itemsInDisplayOrder(),
  );

  @override
  bool validateEditor() => _formKey.currentState?.validate() ?? false;

  @override
  Future<void> writeEditor(String recordId) => writePreDiveTemplate(
    repository: ref.read(preDiveTemplateRepositoryProvider),
    templateId: recordId,
    diverId: editorDiverId,
    draft: readEditorDraft(),
    start: editorCreating ? null : editorStartDraft,
    sections: _shownSections,
    itemsInDisplayOrder: _itemsInDisplayOrder(),
  );

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
    return editorScaffold(
      context,
      body: !_loaded
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
                        : (value) => _change(() => _strictOrder = value),
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
        _change(() {
          _sections = [
            ..._sections,
            EditablePreDiveSection(id: const Uuid().v4(), title: title),
          ];
        });
      },
      onTitleChanged: (id, text) {
        _typedTitles[id] = text;
        editorChanged();
      },
      onRenameSection: (id, title) async {
        _typedTitles.remove(id);
        _change(() {
          _sections = [
            for (final s in _sections)
              if (s.id == id) s.copyWith(title: title) else s,
          ];
        });
      },
      onReorderSections: (orderedIds) async {
        _change(() {
          final byId = {for (final s in _sections) s.id: s};
          _sections = [for (final id in orderedIds) byId[id]!];
        });
      },
      onDeleteSection: (id, {moveItemsToSectionId}) async {
        _typedTitles.remove(id);
        _change(() {
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
        _change(() {
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
