import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/documents/document_dates.dart';
import 'package:submersion/features/agent_access/data/writes/change_set.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan_store.dart';
import 'package:submersion/features/agent_access/data/writes/write_planner.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';

/// Works out what a change set would do, without doing it.
class PreviewChangesTool implements AgentTool {
  PreviewChangesTool({
    required DiverContextLoader loader,
    required WritePlanner planner,
    required WritePlanStore store,
    required WriteCatalog writes,
  }) : _loader = loader,
       _planner = planner,
       _store = store,
       _writes = writes;

  final DiverContextLoader _loader;
  final WritePlanner _planner;
  final WritePlanStore _store;
  final WriteCatalog _writes;

  @override
  String get name => 'preview_changes';

  @override
  String get description {
    final entities = [
      for (final e in _writes.all)
        '${e.name} (fields: ${e.fields.keys.join(', ')}'
            '${e.relations.isEmpty ? '' : '; relations: ${e.relations.keys.join(', ')}'}'
            '${e.note == null ? '' : '. ${e.note}'})',
    ].join('; ');
    return 'First of two steps to change the logbook: this works out what a '
        'change set would do and changes nothing. Call apply_changes with the '
        'plan_id it returns, within ${kWritePlanLifetime.inMinutes} minutes. '
        'A plan with a blocked item has no plan_id: fix or drop those '
        'operations and preview again. Values are metric with the unit in the '
        'key name, as get_records returns them. $kDocumentDateRule In update '
        'fields, null clears a field and a key left out stays as it is. A '
        'relation takes add and remove, or set for the whole list. An update '
        'or delete acts on the record whichever profile owns it; a create '
        'uses diver_id, or the active profile. $_children'
        'Writable: $entities.';
  }

  /// How a record that belongs to another is created, one sentence per kind
  /// of parent.
  String get _children {
    final byParent = <(String, String), List<String>>{};
    for (final e in _writes.all) {
      if (e.parent case final parent?) {
        (byParent[(parent.entity, parent.field)] ??= []).add(e.name);
      }
    }
    return [
      for (final MapEntry(key: (entity, field), value: names)
          in byParent.entries)
        'Each ${names.join(', ')} record belongs to one record of $entity: '
            'a create names it in $field and takes its profile, and the '
            'record stays on it. ',
    ].join();
  }

  @override
  Map<String, Object?> get inputSchema => {
    'type': 'object',
    'properties': {
      'label': {
        'type': 'string',
        'description':
            'What this change does, in the diver\'s language. The diver sees '
            'it when confirming and in the change log.',
      },
      'operations': {
        'type': 'array',
        'minItems': 1,
        'maxItems': kMaxChangeSetOperations,
        'items': {
          'type': 'object',
          'properties': {
            'op': {
              'type': 'string',
              'enum': ['create', 'update', 'delete'],
            },
            'entity': {
              'type': 'string',
              'enum': [for (final e in _writes.all) e.name],
            },
            'id': {
              'type': 'string',
              'description': 'The record, for update and delete.',
            },
            'diver_id': {
              'type': 'string',
              'description': 'The owner of a new record, for create.',
            },
            'fields': {'type': 'object'},
            'relations': {
              'type': 'object',
              'description':
                  'For update: relation name to {add, remove} or {set}, each '
                  'a list of ids.',
            },
          },
          'required': ['op', 'entity'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['label', 'operations'],
    'additionalProperties': false,
  };

  @override
  Future<Map<String, Object?>> call(
    Map<String, Object?> args,
    AgentToolContext context,
  ) async {
    final set = ChangeSet.parse(args);
    final plan = await _planner.preview(
      context.db,
      set,
      resolveDiver: _loader.resolveDiverId,
      clientName: context.clientName,
    );
    if (plan.applicable) _store.put(plan);
    return plan.toJson();
  }
}
