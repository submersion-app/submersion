import 'package:drift/drift.dart' show Variable;
import 'package:uuid/uuid.dart';

import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/checklist_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/template_list_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/object_list_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template_section.dart';

/// Why one pre-dive item's values do not fit its type, or null: bounds only
/// on a value or cell linearity item, the low one not above the high one.
String? _itemRule(Map<String, Object?> item) {
  final type = item['item_type'];
  final bounded = type == 'value' || type == 'cellLinearity';
  final min = item['value_min'] as num?;
  final max = item['value_max'] as num?;
  if (!bounded && (min != null || max != null)) {
    return 'value_min and value_max go on a value or cellLinearity item.';
  }
  if (min != null && max != null && min > max) {
    return 'value_min is above value_max.';
  }
  if (type != 'equipment' && item['equipment_id'] != null) {
    return 'equipment_id goes on an equipment item.';
  }
  if (type != 'cellLinearity' && item['source_index'] != null) {
    return 'source_index goes on a cellLinearity item.';
  }
  if (type == 'cellLinearity' && item['source_index'] == null) {
    return 'a cellLinearity item names its air reading by source_index.';
  }
  return null;
}

/// Pre-dive checklist templates, through the repository the template edit
/// page uses. A built-in template is read only; cloning one, or any other,
/// makes an editable copy, as the template list does.
class PreDiveTemplateWrites extends WritableEntry {
  PreDiveTemplateWrites(this._r);

  final RecordRepositories _r;

  static const _clone = 'clone_of';
  static const _uuid = Uuid();

  @override
  String get name => 'pre_dive_templates';

  @override
  String get table => 'pre_dive_checklist_templates';

  @override
  String get note =>
      'sections and items are written whole, in order. An item names its '
      'section by title; a cellLinearity item names the item holding its air '
      'reading by source_index, that item\'s place in items. $_clone copies '
      'a template, built-in ones included, into a new one.';

  @override
  late final Map<String, FieldCodec> fields = {
    'name': const FieldCodec.text(maxLength: 100, trim: true),
    'description': const FieldCodec.text(allowBlank: true, trim: true),
    'category': const FieldCodec.text(
      maxLength: 60,
      nullable: true,
      trim: true,
    ),
    'strict_order': const FieldCodec.flag(),
    'sections': templateSectionsCodec,
    'items': ObjectListCodec(
      {
        'title': const FieldCodec.text(maxLength: 200, trim: true),
        'section': const FieldCodec.text(
          maxLength: 100,
          nullable: true,
          trim: true,
        ),
        'notes': const FieldCodec.text(allowBlank: true, trim: true),
        'item_type': FieldCodec.enumName(PreDiveItemType.values),
        'value_label': const FieldCodec.text(
          maxLength: 60,
          nullable: true,
          trim: true,
        ),
        'value_unit': const FieldCodec.text(
          maxLength: 20,
          nullable: true,
          trim: true,
        ),
        'value_min': const FieldCodec.number(nullable: true),
        'value_max': const FieldCodec.number(nullable: true),
        'is_required': const FieldCodec.flag(),
        'equipment_id': const FieldCodec.text(maxLength: 100, nullable: true),
        'source_index': const FieldCodec.integer(
          min: 0,
          max: 199,
          nullable: true,
        ),
      },
      defaults: {
        'notes': '',
        'item_type': PreDiveItemType.check.name,
        'is_required': false,
      },
      rule: _itemRule,
      maxItems: 200,
    ),
    _clone: const FieldCodec.reference('pre_dive_templates'),
  };

  @override
  Set<String> get requiredOnCreate => const {'name'};

  @override
  Set<String> get createOnly => const {_clone};

  @override
  Future<Map<String, Object?>> stored(
    String id,
    Map<String, Object?> document,
  ) async {
    final repo = _r.preDiveTemplates;
    final sections = await repo.getSectionsForTemplate(id);
    final titles = {for (final s in sections) s.id: s.title};
    final items = await repo.getItemsForTemplate(id);
    final index = {for (final (i, item) in items.indexed) item.id: i};
    return {
      ...document,
      'sections': [
        for (final s in sections) {'title': s.title},
      ],
      'items': [
        for (final i in items)
          {
            'title': i.title,
            'section': titles[i.sectionId],
            'notes': i.notes,
            'item_type': i.itemType.name,
            'value_label': i.valueLabel,
            'value_unit': i.valueUnit,
            'value_min': i.valueMin,
            'value_max': i.valueMax,
            'is_required': i.isRequired,
            'equipment_id': i.equipmentId,
            'source_index': index[i.sourceItemId],
          },
      ],
    };
  }

  @override
  Future<Map<String, int>> alsoCreates(
    String diverId,
    Map<String, Object?> values,
  ) async {
    final from = values[_clone];
    if (from is! String) return const {};
    final repo = _r.preDiveTemplates;
    return {
      'pre_dive_checklist_template_items': (await repo.getItemsForTemplate(
        from,
      )).length,
      'pre_dive_checklist_template_sections':
          (await repo.getSectionsForTemplate(from)).length,
    }..removeWhere((_, n) => n == 0);
  }

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind != ChangeKind.create &&
        check.document?['is_built_in'] == true) {
      return const PlanBlock(
        BlockReason.notPermitted,
        'A built-in pre-dive template is read only; clone it with clone_of.',
      );
    }
    if (check.kind == ChangeKind.delete) return null;
    if (check.values.containsKey(_clone) &&
        (check.values.containsKey('sections') ||
            check.values.containsKey('items'))) {
      return const PlanBlock(
        BlockReason.notPermitted,
        'A clone takes the template\'s sections and items; edit them once it '
        'exists.',
      );
    }
    final lists = templateLists(check);
    final problem = templateSectionProblem(lists.sections, lists.items);
    if (problem != null) return problem;
    for (final (i, item) in lists.items.indexed) {
      final source = item['source_index'] as int?;
      if (source != null &&
          (source >= lists.items.length ||
              source == i ||
              lists.items[source]['item_type'] != 'value')) {
        return PlanBlock(
          BlockReason.invalidValue,
          'items: item $i\'s source_index is not a value item of this list.',
        );
      }
      if (item['equipment_id'] case final String equipmentId) {
        final rows = await _r.db
            .customSelect(
              'SELECT 1 FROM equipment WHERE id = ? AND '
              '(diver_id IS NULL OR diver_id = ?)',
              variables: [
                Variable.withString(equipmentId),
                Variable.withString(check.ownerId ?? ''),
              ],
            )
            .get();
        if (rows.isEmpty) {
          return PlanBlock(
            BlockReason.unknownReference,
            'items: item $i names equipment $equipmentId, not this '
            'profile\'s.',
          );
        }
      }
    }
    return null;
  }

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async => DeleteReach(
    parts: await countCascaded('pre_dive_checklist_templates', id),
  );

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final repo = _r.preDiveTemplates;
    if (values[_clone] case final String from) {
      final clone = await repo.cloneTemplate(
        from,
        diverId: diverId,
        newName: values['name']! as String,
      );
      final rest = {...values}..remove(_clone);
      if (rest.keys.any((k) => k != 'name')) {
        await _update(clone, rest);
      }
      return clone.id;
    }
    final now = DateTime.now();
    final template = await repo.createTemplate(
      PreDiveChecklistTemplate(
        id: '',
        diverId: diverId,
        name: values['name']! as String,
        description: values['description'] as String? ?? '',
        category: values['category'] as String?,
        strictOrder: values['strict_order'] as bool? ?? false,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await _saveLists(template.id, values);
    return template.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current =
        await _r.preDiveTemplates.getTemplateById(id) ??
        (throw AgentToolException(
          AgentToolErrorCode.writeRefused,
          'Pre-dive template $id no longer exists.',
          details: {'id': id},
        ));
    await _update(current, update.values);
  }

  Future<void> _update(
    PreDiveChecklistTemplate current,
    Map<String, Object?> v,
  ) async {
    if (const [
      'name',
      'description',
      'category',
      'strict_order',
    ].any(v.containsKey)) {
      await _r.preDiveTemplates.updateTemplate(
        current.copyWith(
          name: v['name'] as String?,
          description: v['description'] as String?,
          category: v.containsKey('category')
              ? v['category']
              : current.category,
          strictOrder: v['strict_order'] as bool?,
        ),
      );
    }
    await _saveLists(current.id, v);
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.preDiveTemplates.deleteTemplate(id);

  /// Writes the sections, then the items, that [values] names. Each item
  /// gets its id first, so a cell linearity item can name its source.
  Future<void> _saveLists(String id, Map<String, Object?> values) async {
    final repo = _r.preDiveTemplates;
    final hasSections = values.containsKey('sections');
    if (!hasSections && !values.containsKey('items')) return;
    final now = DateTime.now();
    final kept = await repo.getSectionsForTemplate(id);
    if (hasSections) {
      final titles = [
        for (final s in ObjectListCodec.items(values['sections']))
          s['title']! as String,
      ];
      final ids = keptSectionIds({
        for (final s in kept) ?sectionKey(s.title): s.id,
      }, titles);
      await repo.saveSections(id, [
        for (final (i, title) in titles.indexed)
          PreDiveChecklistTemplateSection(
            id: ids[i],
            templateId: id,
            title: title,
            sortOrder: i,
            createdAt: now,
            updatedAt: now,
          ),
      ]);
    }
    final sections = hasSections ? await repo.getSectionsForTemplate(id) : kept;
    final idByKey = <String?, String>{
      for (final s in sections) sectionKey(s.title): s.id,
    };
    final items = values.containsKey('items')
        ? ObjectListCodec.items(values['items'])
        : (await stored(id, const {}))['items']! as List<Map<String, Object?>>;
    final keptIds = keptItemIds([
      for (final i in await repo.getItemsForTemplate(id))
        (
          id: i.id,
          section: [
            for (final s in kept)
              if (s.id == i.sectionId) s.title,
          ].firstOrNull,
          title: i.title,
        ),
    ], items);
    final ids = [for (final kept in keptIds) kept.isEmpty ? _uuid.v4() : kept];
    await repo.saveItems(id, [
      for (final (i, item) in items.indexed)
        PreDiveChecklistTemplateItem(
          id: ids[i],
          templateId: id,
          sectionId: sectionIdFor(idByKey, item['section']),
          title: item['title']! as String,
          notes: item['notes'] as String? ?? '',
          sortOrder: i,
          itemType: PreDiveItemType.parse(item['item_type']! as String),
          valueLabel: item['value_label'] as String?,
          valueUnit: item['value_unit'] as String?,
          valueMin: (item['value_min'] as num?)?.toDouble(),
          valueMax: (item['value_max'] as num?)?.toDouble(),
          isRequired: item['is_required'] as bool? ?? false,
          equipmentId: item['equipment_id'] as String?,
          sourceItemId: switch (item['source_index']) {
            final int source => ids[source],
            _ => null,
          },
          createdAt: now,
          updatedAt: now,
        ),
    ]);
  }
}
