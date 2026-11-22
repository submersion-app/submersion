import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template_section.dart'
    as domain;
import 'package:submersion/features/checklists/presentation/pages/checklist_editable_item.dart';
import 'package:submersion/features/checklists/presentation/pages/checklist_item_dialog.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/section_list_editor.dart';

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
  List<EditableChecklistItem> _items = [];
  List<EditableChecklistSection> _sections = [];
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
    if (!mounted) return;
    setState(() {
      _existing = template;
      _nameController.text = template?.name ?? '';
      _descriptionController.text = template?.description ?? '';
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
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _addOrEditItem({EditableChecklistItem? item}) async {
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

  Future<EditableChecklistItem?> _showItemDialog({
    EditableChecklistItem? item,
  }) {
    return showDialog<EditableChecklistItem>(
      context: context,
      builder: (context) => ChecklistItemDialog(
        item: item,
        defaultSortOrder: _items.length,
        sections: _sections,
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

    // Sections must exist before the items referencing them are (re)inserted
    // -- saveItems satisfies a foreign key, not a dangling draft id.
    await repository.saveSections(templateId, [
      for (final section in _sections)
        domain.ChecklistTemplateSection(
          id: section.id,
          templateId: templateId,
          title: section.title,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
    ]);

    // sortOrder reassigned at save time from the order the editor shows
    // (section by section), not from the order items were added in, so a
    // trip the template is applied to lists them the same way.
    final ordered = _itemsInDisplayOrder();
    await repository.saveItems(templateId, [
      for (var i = 0; i < ordered.length; i++)
        ChecklistTemplateItem(
          id: ordered[i].id,
          templateId: templateId,
          title: ordered[i].title,
          sectionId: ordered[i].sectionId,
          notes: ordered[i].notes,
          dueOffsetDays: ordered[i].dueOffsetDays,
          sortOrder: i,
          createdAt: ordered[i].createdAt,
          updatedAt: ordered[i].updatedAt,
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
    setState(() => _items = _items.where((i) => i.id != item.id).toList());
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
        setState(() {
          _sections = [
            ..._sections,
            EditableChecklistSection(id: const Uuid().v4(), title: title),
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
      onDeleteItem: (item) async => _removeItem(item),
    );
  }
}
