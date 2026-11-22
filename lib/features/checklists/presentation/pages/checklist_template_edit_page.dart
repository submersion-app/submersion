import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template_section.dart';
import 'package:submersion/features/checklists/presentation/pages/checklist_editable_item.dart';
import 'package:submersion/features/checklists/presentation/pages/checklist_item_dialog.dart';
import 'package:submersion/features/checklists/presentation/pages/checklist_template_draft.dart';
import 'package:submersion/features/checklists/presentation/pages/checklist_template_save.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_editor_host.dart';
import 'package:submersion/shared/widgets/section_list_editor.dart';

/// Create/edit page for a checklist template and its items.
///
/// An editor with no read page (issue #4527, phase 4): it opens on the
/// shared Cancel and Save bar, asks before its changes are left behind, and
/// writes the template, its sections and its items in one transaction and
/// one History entry.
class ChecklistTemplateEditPage extends ConsumerStatefulWidget {
  final String? templateId;

  const ChecklistTemplateEditPage({super.key, this.templateId});

  bool get isEditing => templateId != null;

  @override
  ConsumerState<ChecklistTemplateEditPage> createState() =>
      _ChecklistTemplateEditPageState();
}

class _ChecklistTemplateEditPageState
    extends ConsumerState<ChecklistTemplateEditPage>
    with RecordEditorHost<ChecklistTemplateEditPage, ChecklistTemplateDraft> {
  static final _log = LoggerService.forClass(ChecklistTemplateEditPage);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<EditableChecklistItem> _items = [];
  List<EditableChecklistSection> _sections = [];

  /// Section titles being typed, by section id: the section editor renames
  /// a section only when its title field lets go, and a title being typed
  /// is already a change.
  final Map<String, String> _typedTitles = {};

  /// [_sections] as shown, with each title being typed as the rename it
  /// will become: trimmed, and the title it had when typed blank.
  List<EditableChecklistSection> get _shownSections => [
    for (final section in _sections)
      switch (_typedTitles[section.id]?.trim()) {
        final typed? when typed.isNotEmpty => section.copyWith(title: typed),
        _ => section,
      },
  ];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(editorChanged);
    _descriptionController.addListener(editorChanged);
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
    final repository = ref.read(checklistTemplateRepositoryProvider);
    final id = widget.templateId!;
    final ChecklistTemplate? template;
    final List<ChecklistTemplateItem> items;
    final List<ChecklistTemplateSection> sections;
    try {
      template = await repository.getTemplateById(id);
      items = await repository.getItemsForTemplate(id);
      sections = await repository.getSectionsForTemplate(id);
    } catch (error, stackTrace) {
      _log.warning(
        'Loading checklist template $id failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) _leaveUnopened(context.l10n.recordEdit_loadFailed);
      return;
    }
    if (!mounted) return;
    // A stale link, or a template deleted on another device: there is
    // nothing to edit, and saving the empty form would make a new one.
    if (template == null) {
      _leaveUnopened(context.l10n.checklists_template_edit_notFound);
      return;
    }
    setState(() {
      _nameController.text = template!.name;
      _descriptionController.text = template.description;
      _sections = [
        for (final section in sections)
          EditableChecklistSection(id: section.id, title: section.title),
      ];
      _items = [
        for (final item in items)
          EditableChecklistItem(
            id: item.id,
            title: item.title,
            sectionId: item.sectionId,
            notes: item.notes,
            dueOffsetDays: item.dueOffsetDays,
            sortOrder: item.sortOrder,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
          ),
      ];
      _loaded = true;
    });
    openEditor();
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
    super.dispose();
  }

  /// Changes the form and hands it to the sitting.
  void _change(VoidCallback change) {
    setState(change);
    editorChanged();
  }

  Future<void> _addOrEditItem({EditableChecklistItem? item}) async {
    final result = await showDialog<EditableChecklistItem>(
      context: context,
      builder: (context) => ChecklistItemDialog(
        item: item,
        defaultSortOrder: _items.length,
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

  @override
  String get editorTable => 'checklist_templates';

  @override
  String? get editorStoredId => widget.templateId;

  @override
  String? get editorLeaveLocation => '/checklist-templates';

  @override
  String editorTitle(BuildContext context) => widget.isEditing
      ? context.l10n.checklists_templates_editTemplate
      : context.l10n.checklists_templates_addTemplate;

  @override
  ChecklistTemplateDraft readEditorDraft() => checklistTemplateDraft(
    name: _nameController.text,
    description: _descriptionController.text,
    sections: _shownSections,
    itemsInDisplayOrder: _itemsInDisplayOrder(),
  );

  @override
  bool validateEditor() => _formKey.currentState?.validate() ?? false;

  @override
  Future<void> writeEditor(String recordId) => writeChecklistTemplate(
    repository: ref.read(checklistTemplateRepositoryProvider),
    templateId: recordId,
    diverId: editorDiverId,
    draft: readEditorDraft(),
    start: editorCreating ? null : editorStartDraft,
    sections: _shownSections,
    itemsInDisplayOrder: _itemsInDisplayOrder(),
  );

  @override
  Widget build(BuildContext context) {
    return editorScaffold(
      context,
      body: !_loaded
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
                  _buildSectionEditor(context),
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

  /// [_items] in the order the editor shows them: each section's items in
  /// section order, then the unsectioned ones (a dangling sectionId counts
  /// as unsectioned, as it does on screen).
  List<EditableChecklistItem> _itemsInDisplayOrder() {
    final sectionIds = {for (final s in _sections) s.id};
    return [
      for (final s in _sections) ..._items.where((i) => i.sectionId == s.id),
      ..._items.where(
        (i) => i.sectionId == null || !sectionIds.contains(i.sectionId),
      ),
    ];
  }

  void _removeItem(EditableChecklistItem item) {
    _change(() => _items = _items.where((i) => i.id != item.id).toList());
  }

  Widget _buildSectionEditor(BuildContext context) {
    Widget buildItem(BuildContext context, EditableChecklistItem item) =>
        ListTile(
          title: Text(item.title),
          onTap: () => _addOrEditItem(item: item),
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

    return SectionListEditor<EditableChecklistItem>(
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
      addSectionLabel: context.l10n.sectionEditor_addSection,
      newSectionTitle: context.l10n.sectionEditor_newSectionTitle,
      noSectionLabel: context.l10n.sectionEditor_noSection,
      onAddSection: (title) async {
        _change(() {
          _sections = [
            ..._sections,
            EditableChecklistSection(id: const Uuid().v4(), title: title),
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
          } else {
            _items = _items.where((i) => i.sectionId != id).toList();
          }
          _sections = _sections.where((s) => s.id != id).toList();
        });
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
