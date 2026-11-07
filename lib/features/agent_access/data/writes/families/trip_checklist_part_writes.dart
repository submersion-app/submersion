import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/checklist_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/service_ledger_rules.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';

/// The sections of a trip's checklist, as its section editor keeps them: a
/// section goes last, moves to a position, and is renamed. Deleting one
/// takes its items; merging it into a section of the same list moves them
/// there instead. A list's last section stays.
class TripChecklistSectionWrites extends WritableEntry {
  TripChecklistSectionWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'trip_checklist_sections';

  @override
  String get table => 'trip_checklist_sections';

  @override
  ChildOf get parent =>
      const ChildOf(entity: 'trip_checklists', field: 'checklist_id');

  @override
  String get note =>
      'sort_order is the position among the checklist\'s sections. A delete '
      'takes the section\'s items; a delete with merge_into another section '
      'of the same checklist moves them there. A checklist keeps at least one '
      'section.';

  @override
  late final Map<String, FieldCodec> fields = {
    'checklist_id': const FieldCodec.reference('trip_checklists'),
    'title': const FieldCodec.text(maxLength: 100, trim: true),
    'sort_order': const FieldCodec.integer(min: 0, max: 999),
  };

  @override
  Set<String> get requiredOnCreate => const {'title'};

  @override
  bool get mergeable => true;

  @override
  String? titleOf(Map<String, Object?> document) =>
      document['title'] as String?;

  @override
  Future<Map<String, Object?>> stored(
    String id,
    Map<String, Object?> document,
  ) async {
    final ids = await _sections(document['checklist_id']! as String);
    return {...document, 'sort_order': ids.indexOf(id)};
  }

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    final listId =
        check.values['checklist_id'] as String? ??
        check.document!['checklist_id']! as String;
    final ids = await _sections(listId);
    if (check.kind != ChangeKind.delete) {
      return positionProblem(check, ids.length);
    }
    final gone = check.soFar.deleted[name] ?? const {};
    if (ids.any((s) => s != check.id && !gone.contains(s))) return null;
    return const PlanBlock(
      BlockReason.notPermitted,
      'A checklist keeps at least one section; this is its last.',
    );
  }

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async {
    final own = alongside['trip_checklist_items'] ?? const {};
    final items = (await _items(id)).where((i) => !own.contains(i)).length;
    return DeleteReach(parts: {if (items > 0) 'trip_checklist_items': items});
  }

  @override
  Future<DeleteReach> mergeReach(
    String id,
    String intoId, {
    Set<String> mergedBefore = const {},
  }) async {
    final items = (await _items(id)).length;
    return DeleteReach(moved: {if (items > 0) 'trip_checklist_items': items});
  }

  @override
  Future<void> merge(String id, String intoId, String? ownerId) =>
      _r.tripChecklists.deleteSection(id, moveItemsToSectionId: intoId);

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async =>
      (await _r.tripChecklists.createSection(
        checklistId: values['checklist_id']! as String,
        title: values['title']! as String,
      )).id;

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final v = update.values;
    if (v['title'] case final String title) {
      await _r.tripChecklists.renameSection(id, title);
    }
    if (v['sort_order'] case final int at) {
      final listId = await checklistOf(_r, table, id);
      await _r.tripChecklists.reorderSections(
        listId,
        placed(await _sections(listId), id, at),
      );
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.tripChecklists.deleteSection(id);

  Future<List<String>> _sections(String listId) async => [
    for (final s in await _r.tripChecklists.getSectionsForChecklist(listId))
      s.id,
  ];

  Future<List<String>> _items(String sectionId) async {
    final listId = await checklistOf(_r, table, sectionId);
    return [
      for (final i in await _r.tripChecklists.getByChecklistId(listId))
        if (i.sectionId == sectionId) i.id,
    ];
  }
}

/// The items of a trip's checklist, as its item sheet and section editor
/// keep them: an item goes last, is edited, ticked off, and moved within or
/// between the list's sections.
class TripChecklistItemWrites extends WritableEntry {
  TripChecklistItemWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'trip_checklist_items';

  @override
  String get table => 'trip_checklist_items';

  @override
  ChildOf get parent =>
      const ChildOf(entity: 'trip_checklists', field: 'checklist_id');

  @override
  String get note =>
      'section_id is a section of the same checklist, or null for none. '
      'sort_order is the position within the item\'s section. Marking an item '
      'done stamps completed_at with the moment of the save.';

  @override
  late final Map<String, FieldCodec> fields = {
    'checklist_id': const FieldCodec.reference('trip_checklists'),
    'title': const FieldCodec.text(maxLength: 200, trim: true),
    'section_id': const FieldCodec.reference(
      'trip_checklist_sections',
      nullable: true,
    ),
    'notes': const FieldCodec.text(allowBlank: true, trim: true),
    'due_date': const FieldCodec.calendarDate(nullable: true),
    'is_done': const FieldCodec.flag(),
    'sort_order': const FieldCodec.integer(min: 0, max: 9999),
  };

  @override
  Set<String> get requiredOnCreate => const {'title'};

  @override
  String? titleOf(Map<String, Object?> document) =>
      document['title'] as String?;

  @override
  Future<Map<String, Object?>> stored(
    String id,
    Map<String, Object?> document,
  ) async {
    final buckets = await _buckets(document['checklist_id']! as String);
    final at = buckets.values
        .map((bucket) => bucket.indexOf(id))
        .firstWhere((i) => i >= 0, orElse: () => -1);
    return {...document, 'sort_order': at};
  }

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) return null;
    final v = check.values;
    final listId =
        v['checklist_id'] as String? ??
        check.document!['checklist_id']! as String;
    final buckets = await _buckets(listId);
    if (v['section_id'] case final String sectionId
        when !buckets.containsKey(sectionId)) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'section_id: a section of the same checklist.',
      );
    }
    final target = v.containsKey('section_id')
        ? v['section_id'] as String?
        : _bucketOf(buckets, check.id);
    final size = (buckets[target] ?? const []).length;
    final moving = check.id != null && !buckets[target]!.contains(check.id);
    return positionProblem(check, moving ? size + 1 : size);
  }

  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async {
    if (update.values['is_done'] == false && document['completed_at'] != null) {
      return const SideEffects(fields: {'completed_at': null});
    }
    return const SideEffects();
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final now = DateTime.now();
    final done = values['is_done'] == true;
    return (await _r.tripChecklists.createItem(
      TripChecklistItem(
        id: '',
        checklistId: values['checklist_id']! as String,
        title: values['title']! as String,
        sectionId: values['section_id'] as String?,
        notes: values['notes'] as String? ?? '',
        dueDate: calendarDay(values['due_date']),
        isDone: done,
        completedAt: done ? now : null,
        createdAt: now,
        updatedAt: now,
      ),
    )).id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final v = update.values;
    final repo = _r.tripChecklists;
    final listId = await checklistOf(_r, table, id);
    if (v.keys.any(const {'title', 'notes', 'due_date'}.contains)) {
      final current = (await repo.getByChecklistId(listId)).firstWhere(
        (i) => i.id == id,
        orElse: () => throw AgentToolException(
          AgentToolErrorCode.writeRefused,
          'Checklist item $id no longer exists.',
          details: {'id': id},
        ),
      );
      await repo.updateItem(
        current.copyWith(
          title: v['title'] as String?,
          notes: v['notes'] as String?,
          dueDate: v.containsKey('due_date')
              ? calendarDay(v['due_date'])
              : current.dueDate,
        ),
      );
    }
    if (v['is_done'] case final bool done) {
      await repo.toggleDone(id, isDone: done);
    }
    if (v.containsKey('section_id') || v.containsKey('sort_order')) {
      final buckets = await _buckets(listId);
      final target = v.containsKey('section_id')
          ? v['section_id'] as String?
          : _bucketOf(buckets, id);
      await repo.moveItem(
        checklistId: listId,
        itemId: id,
        targetSectionId: target,
        orderedIds: [
          for (final MapEntry(:key, value: ids) in buckets.entries)
            ...(key == target
                ? placed(ids, id, v['sort_order'] as int?)
                : [
                    for (final other in ids)
                      if (other != id) other,
                  ]),
        ],
      );
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.tripChecklists.deleteItem(id);

  /// The list's items by section, in the order the section editor shows
  /// them: each section in turn, then the items under none. An item whose
  /// section has gone shows under none, as the editor shows it.
  Future<Map<String?, List<String>>> _buckets(String listId) async {
    final repo = _r.tripChecklists;
    final sections = await repo.getSectionsForChecklist(listId);
    final items = await repo.getByChecklistId(listId);
    final known = {for (final s in sections) s.id};
    return {
      for (final s in sections)
        s.id: [
          for (final i in items)
            if (i.sectionId == s.id) i.id,
        ],
      null: [
        for (final i in items)
          if (!known.contains(i.sectionId)) i.id,
      ],
    };
  }

  static String? _bucketOf(Map<String?, List<String>> buckets, String? id) =>
      buckets.entries.where((e) => e.value.contains(id)).firstOrNull?.key;
}
