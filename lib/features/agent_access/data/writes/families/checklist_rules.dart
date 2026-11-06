import 'package:drift/drift.dart' show Variable;

import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';

/// A section title as the checklist pages match one: trimmed and without
/// case, or null for a blank one, which names no section.
String? sectionKey(String? title) {
  final trimmed = title?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed.toLowerCase();
}

/// How many distinct sections [titles] name, as a find-or-create by title
/// makes them.
int distinctSections(Iterable<String?> titles) =>
    {for (final title in titles) ?sectionKey(title)}.length;

/// What applying template [templateId] adds to checklist [checklistId], or
/// to a new, empty one when it is null, as `applyTemplate` decides it: an
/// item whose title and section the list holds already is skipped, and a
/// section is made for each title the list does not have.
Future<({int items, int sections})> templateAdds(
  RecordRepositories r,
  String templateId, {
  String? checklistId,
}) async {
  final templates = r.checklistTemplates;
  final sectionTitle = {
    for (final s in await templates.getSectionsForTemplate(templateId))
      s.id: s.title,
  };
  final existing = checklistId == null
      ? const []
      : await r.tripChecklists.getByChecklistId(checklistId);
  final known = {
    if (checklistId != null)
      for (final s in await r.tripChecklists.getSectionsForChecklist(
        checklistId,
      ))
        ?sectionKey(s.title): s.id,
  };
  final held = {for (final i in existing) (i.title, i.sectionId)};
  final made = <String>{};
  var items = 0;
  for (final item in await templates.getItemsForTemplate(templateId)) {
    final key = sectionKey(sectionTitle[item.sectionId]);
    final matched = key == null ? null : known[key];
    // An item under a section the list lacks cannot be held yet.
    if (key != null && matched == null) {
      made.add(key);
    } else if (held.contains((item.title, matched))) {
      continue;
    }
    items++;
  }
  return (items: items, sections: made.length);
}

/// [ids] with [id] moved to [at], or to the end when [at] is null.
List<String> placed(List<String> ids, String id, int? at) {
  final rest = [
    for (final other in ids)
      if (other != id) other,
  ];
  final index = at == null || at > rest.length ? rest.length : at;
  return [...rest.take(index), id, ...rest.skip(index)];
}

/// A block when [check] names a `sort_order` the list of [count] records
/// cannot hold, or names one on a create, which always goes last.
PlanBlock? positionProblem(WriteCheck check, int count) {
  final at = check.values['sort_order'];
  if (at is! int) return null;
  if (check.kind == ChangeKind.create) {
    return const PlanBlock(
      BlockReason.invalidValue,
      'sort_order: a new record goes last; move it with an update.',
    );
  }
  if (at < count) return null;
  return PlanBlock(
    BlockReason.invalidValue,
    'sort_order: this list holds positions 0 to ${count - 1}.',
  );
}

/// The checklist [table] row [id] is on.
Future<String> checklistOf(
  RecordRepositories r,
  String table,
  String id,
) async {
  final rows = await r.db
      .customSelect(
        'SELECT checklist_id FROM $table WHERE id = ?',
        variables: [Variable.withString(id)],
      )
      .get();
  if (rows.isEmpty) {
    throw AgentToolException(
      AgentToolErrorCode.writeRefused,
      'Checklist record $id no longer exists.',
      details: {'id': id},
    );
  }
  return rows.single.read<String>('checklist_id');
}
