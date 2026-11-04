import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/checklist_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/template_list_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/object_list_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template_section.dart';

/// Trip checklist templates, through the repository the template edit page
/// uses: the template, then its sections, then its items, each list
/// written whole in the order given.
class ChecklistTemplateWrites extends WritableEntry {
  ChecklistTemplateWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'checklist_templates';

  @override
  String get table => 'checklist_templates';

  @override
  String get note =>
      'sections and items are written whole, in order. An item names its '
      'section by title, one of sections, or none; due_offset_days is how '
      'many days before a trip starts it falls due.';

  @override
  late final Map<String, FieldCodec> fields = {
    'name': const FieldCodec.text(maxLength: 100, trim: true),
    'description': const FieldCodec.text(allowBlank: true, trim: true),
    'sections': templateSectionsCodec,
    'items': const ObjectListCodec(
      {
        'title': FieldCodec.text(maxLength: 200, trim: true),
        'section': FieldCodec.text(maxLength: 100, nullable: true, trim: true),
        'notes': FieldCodec.text(allowBlank: true, trim: true),
        'due_offset_days': FieldCodec.integer(
          min: 0,
          max: 3650,
          nullable: true,
        ),
      },
      defaults: {'notes': ''},
      maxItems: 200,
    ),
  };

  @override
  Set<String> get requiredOnCreate => const {'name'};

  @override
  Future<Map<String, Object?>> stored(
    String id,
    Map<String, Object?> document,
  ) async {
    final repo = _r.checklistTemplates;
    final sections = await repo.getSectionsForTemplate(id);
    final titles = {for (final s in sections) s.id: s.title};
    return {
      ...document,
      'sections': [
        for (final s in sections) {'title': s.title},
      ],
      'items': [
        for (final i in await repo.getItemsForTemplate(id))
          {
            'title': i.title,
            'section': titles[i.sectionId],
            'notes': i.notes,
            'due_offset_days': i.dueOffsetDays,
          },
      ],
    };
  }

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) return null;
    final lists = templateLists(check);
    return templateSectionProblem(lists.sections, lists.items);
  }

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async =>
      DeleteReach(parts: await countCascaded('checklist_templates', id));

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final now = DateTime.now();
    final template = await _r.checklistTemplates.createTemplate(
      ChecklistTemplate(
        id: '',
        diverId: diverId,
        name: values['name']! as String,
        description: values['description'] as String? ?? '',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await _saveLists(template.id, values);
    return template.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final v = update.values;
    if (v.containsKey('name') || v.containsKey('description')) {
      final current =
          await _r.checklistTemplates.getTemplateById(id) ??
          (throw AgentToolException(
            AgentToolErrorCode.writeRefused,
            'Checklist template $id no longer exists.',
            details: {'id': id},
          ));
      await _r.checklistTemplates.updateTemplate(
        ChecklistTemplate(
          id: id,
          diverId: current.diverId,
          name: v['name'] as String? ?? current.name,
          description: v['description'] as String? ?? current.description,
          createdAt: current.createdAt,
          updatedAt: current.updatedAt,
        ),
      );
    }
    await _saveLists(id, v);
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.checklistTemplates.deleteTemplate(id);

  /// Writes the sections, then the items, that [values] names, keeping the
  /// stored ids of sections and items it keeps.
  Future<void> _saveLists(String id, Map<String, Object?> values) async {
    final repo = _r.checklistTemplates;
    final hasSections = values.containsKey('sections');
    if (!hasSections && !values.containsKey('items')) return;
    final now = DateTime.now();
    final stored = await repo.getSectionsForTemplate(id);
    if (hasSections) {
      final titles = [
        for (final s in ObjectListCodec.items(values['sections']))
          s['title']! as String,
      ];
      final ids = keptSectionIds({
        for (final s in stored) ?sectionKey(s.title): s.id,
      }, titles);
      await repo.saveSections(id, [
        for (final (i, title) in titles.indexed)
          ChecklistTemplateSection(
            id: ids[i],
            templateId: id,
            title: title,
            sortOrder: i,
            createdAt: now,
            updatedAt: now,
          ),
      ]);
    }
    final sections = hasSections
        ? await repo.getSectionsForTemplate(id)
        : stored;
    final idByKey = <String?, String>{
      for (final s in sections) sectionKey(s.title): s.id,
    };
    final items = values.containsKey('items')
        ? ObjectListCodec.items(values['items'])
        : [
            for (final i in await repo.getItemsForTemplate(id))
              {
                'title': i.title,
                'section': [
                  for (final s in stored)
                    if (s.id == i.sectionId) s.title,
                ].firstOrNull,
                'notes': i.notes,
                'due_offset_days': i.dueOffsetDays,
              },
          ];
    await repo.saveItems(id, [
      for (final (i, item) in items.indexed)
        ChecklistTemplateItem(
          id: '',
          templateId: id,
          title: item['title']! as String,
          sectionId: sectionIdFor(idByKey, item['section']),
          notes: item['notes'] as String? ?? '',
          dueOffsetDays: item['due_offset_days'] as int?,
          sortOrder: i,
          createdAt: now,
          updatedAt: now,
        ),
    ]);
  }
}
