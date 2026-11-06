import 'package:drift/drift.dart' show Variable;

import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/checklist_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

/// A trip's checklists, through the repositories the checklist panel uses:
/// a list is added last and moved to a position, made from a template,
/// refilled from one, or saved as one.
class TripChecklistWrites extends WritableEntry {
  TripChecklistWrites(this._r);

  final RecordRepositories _r;

  static const _from = 'from_template_id';
  static const _apply = 'apply_template_id';
  static const _replace = 'replace_with_template_id';
  static const _saveAs = 'save_as_template_name';
  static const _actions = [_apply, _replace, _saveAs];

  static const _contents = {
    'trip_checklist_items': 'checklist_id',
    'trip_checklist_sections': 'checklist_id',
  };

  @override
  String get name => 'trip_checklists';

  @override
  String get table => 'trip_checklists';

  @override
  ChildOf get parent => const ChildOf(entity: 'trips', field: 'trip_id');

  @override
  String get note =>
      'sort_order is the position among the trip\'s checklists. '
      '$_from makes a new list from a template, named after it unless a name '
      'is given. On an update, $_apply adds the template\'s items the list '
      'lacks, $_replace empties the list and fills it from the template, and '
      '$_saveAs saves the list as a new template; one of these per update.';

  @override
  late final Map<String, FieldCodec> fields = {
    'trip_id': const FieldCodec.reference('trips'),
    'name': const FieldCodec.text(maxLength: 100, trim: true),
    'sort_order': const FieldCodec.integer(min: 0, max: 999),
    _from: const FieldCodec.reference('checklist_templates'),
    _apply: const FieldCodec.reference('checklist_templates'),
    _replace: const FieldCodec.reference('checklist_templates'),
    _saveAs: const FieldCodec.text(maxLength: 100, trim: true),
  };

  @override
  Set<String> get requiredOnCreate => const {};

  @override
  Set<String> get createOnly => const {_from};

  @override
  Set<String> get effectFields => const {_apply, _replace, _saveAs};

  @override
  Future<Map<String, Object?>> stored(
    String id,
    Map<String, Object?> document,
  ) async {
    final lists = await _lists(document['trip_id']! as String);
    return {...document, 'sort_order': lists.indexOf(id)};
  }

  @override
  Future<Map<String, Object?>> createDefaults(
    String diverId,
    Map<String, Object?> values,
  ) async {
    if (values['name'] != null || values[_from] is! String) return const {};
    final template = await _r.checklistTemplates.getTemplateById(
      values[_from]! as String,
    );
    return {'name': ?template?.name};
  }

  @override
  Future<Map<String, int>> alsoCreates(
    String diverId,
    Map<String, Object?> values,
  ) async => switch (values[_from]) {
    final String templateId => _adds(await templateAdds(_r, templateId)),
    _ => const {},
  };

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) return null;
    final v = check.values;
    if (check.kind == ChangeKind.create) {
      if (v['name'] == null) {
        return const PlanBlock(
          BlockReason.missingField,
          'A new trip_checklists record needs name, or $_from to take the '
          'template\'s.',
        );
      }
      if (_actions.where(v.containsKey).firstOrNull case final key?) {
        return PlanBlock(
          BlockReason.invalidValue,
          '$key: a new checklist takes a template through $_from.',
        );
      }
    } else if (_actions.where(v.containsKey).length > 1) {
      return const PlanBlock(
        BlockReason.notPermitted,
        'One of $_apply, $_replace and $_saveAs per update.',
      );
    }
    final tripId = v['trip_id'] as String? ?? check.document!['trip_id']!;
    return positionProblem(check, (await _lists(tripId as String)).length);
  }

  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async {
    final v = update.values;
    if (v[_apply] case final String templateId) {
      return SideEffects(
        created: _adds(await templateAdds(_r, templateId, checklistId: id)),
      );
    }
    if (v[_replace] case final String templateId) {
      return SideEffects(
        parts: await countOwned(_contents, id),
        created: _adds(await templateAdds(_r, templateId)),
      );
    }
    if (v[_saveAs] is String) {
      final repo = _r.tripChecklists;
      final items = (await repo.getByChecklistId(id)).length;
      final sections = distinctSections([
        for (final s in await repo.getSectionsForChecklist(id)) s.title,
      ]);
      return SideEffects(
        created: {
          'checklist_templates': 1,
          if (items > 0) 'checklist_template_items': items,
          if (sections > 0) 'checklist_template_sections': sections,
        },
      );
    }
    return const SideEffects();
  }

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async => DeleteReach(parts: await countOwned(_contents, id));

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final tripId = values['trip_id']! as String;
    final list = await _r.tripChecklistLists.createChecklist(
      tripId: tripId,
      name: values['name']! as String,
    );
    if (values[_from] case final String templateId) {
      await _r.tripChecklists.applyTemplate(
        templateId: templateId,
        checklistId: list.id,
        trip: await _trip(tripId),
      );
    }
    return list.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final v = update.values;
    final tripId = await checklistTrip(id);
    if (v['name'] case final String name) {
      await _r.tripChecklistLists.renameChecklist(id, name);
    }
    final repo = _r.tripChecklists;
    if (v[_saveAs] case final String name) {
      final trip = await _trip(tripId);
      await repo.saveAsTemplate(
        checklistId: id,
        tripStartDate: trip.startDate,
        name: name,
        diverId: trip.diverId,
      );
    }
    if (v[_apply] case final String templateId) {
      await repo.applyTemplate(
        templateId: templateId,
        checklistId: id,
        trip: await _trip(tripId),
      );
    }
    if (v[_replace] case final String templateId) {
      await repo.replaceWithTemplate(
        templateId: templateId,
        checklistId: id,
        trip: await _trip(tripId),
      );
    }
    if (v['sort_order'] case final int at) {
      await _r.tripChecklistLists.reorderChecklists(
        tripId,
        placed(await _lists(tripId), id, at),
      );
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.tripChecklistLists.deleteChecklist(id);

  /// The trip checklist [id] is on.
  Future<String> checklistTrip(String id) async {
    final rows = await _r.db
        .customSelect(
          'SELECT trip_id FROM trip_checklists WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .get();
    if (rows.isEmpty) {
      throw AgentToolException(
        AgentToolErrorCode.writeRefused,
        'Trip checklist $id no longer exists.',
        details: {'id': id},
      );
    }
    return rows.single.read<String>('trip_id');
  }

  Future<List<String>> _lists(String tripId) async => [
    for (final l in await _r.tripChecklistLists.getChecklistsForTrip(tripId))
      l.id,
  ];

  Future<Trip> _trip(String tripId) async =>
      await _r.trips.getTripById(tripId) ??
      (throw AgentToolException(
        AgentToolErrorCode.writeRefused,
        'Trip $tripId no longer exists.',
        details: {'id': tripId},
      ));

  static Map<String, int> _adds(({int items, int sections}) adds) => {
    if (adds.items > 0) 'trip_checklist_items': adds.items,
    if (adds.sections > 0) 'trip_checklist_sections': adds.sections,
  };
}
