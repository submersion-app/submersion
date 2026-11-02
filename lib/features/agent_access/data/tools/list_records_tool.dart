import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/documents/document_dates.dart';
import 'package:submersion/features/agent_access/data/records/record_catalog.dart';
import 'package:submersion/features/agent_access/data/records/record_entity.dart';
import 'package:submersion/features/agent_access/data/records/record_reader.dart';
import 'package:submersion/features/agent_access/data/tools/tool_args.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';

const kListRecordsDefaultLimit = 100;
const kListRecordsMaxLimit = 500;

/// Lists the entities `query` does not root at, so an agent can find an id
/// to fetch without writing SQL.
class ListRecordsTool implements AgentTool {
  ListRecordsTool({
    required DiverContextLoader loader,
    required RecordCatalog catalog,
  }) : _loader = loader,
       _catalog = catalog;

  final DiverContextLoader _loader;
  final RecordCatalog _catalog;

  @override
  String get name => 'list_records';

  @override
  String get description =>
      'List records of an entity that is not a query root, with a compact '
      'summary per record, paged by limit and offset. parent_id narrows a '
      'child entity to one parent (a dive id for dive_tanks). Use query for '
      'dives, sites, equipment, trips, buddies, centers, certifications, '
      'courses and species, and get_records for full documents. '
      '$kDocumentDateRule';

  @override
  Map<String, Object?> get inputSchema => {
    'type': 'object',
    'properties': {
      'entity': {
        'type': 'string',
        'enum': [for (final e in _catalog.nonRoots) e.name],
      },
      'diver_id': {
        'type': 'string',
        'description': 'Profile to read as. Omitted means the active profile.',
      },
      'parent_id': {
        'type': 'string',
        'description': 'Only the children of this parent record.',
      },
      'limit': {
        'type': 'integer',
        'minimum': 1,
        'maximum': kListRecordsMaxLimit,
        'default': kListRecordsDefaultLimit,
      },
      'offset': {'type': 'integer', 'minimum': 0, 'default': 0},
    },
    'required': ['entity'],
    'additionalProperties': false,
  };

  @override
  Future<Map<String, Object?>> call(
    Map<String, Object?> args,
    AgentToolContext context,
  ) async {
    final entry = _entry(args['entity']);
    final limit = intArg(
      args,
      'limit',
      fallback: kListRecordsDefaultLimit,
      min: 1,
      max: kListRecordsMaxLimit,
    );
    final offset = intArg(args, 'offset', fallback: 0, min: 0);
    final diverId = await _loader.resolveDiverId(args['diver_id'] as String?);
    final page = await RecordReader(context.db).page(
      entry,
      diverId,
      parentId: args['parent_id'] as String?,
      limit: limit,
      offset: offset,
    );
    return {
      'entity': entry.name,
      'diver_id': diverId,
      'total': page.total,
      'records': await entry.summaries(
        page.ids,
        RecordLoad(include: const {}, diverId: diverId),
      ),
      'offset': offset,
      'limit': limit,
      'has_more': offset + page.ids.length < page.total,
    };
  }

  RecordEntry _entry(Object? raw) {
    for (final entry in _catalog.nonRoots) {
      if (entry.name == raw) return entry;
    }
    if (_catalog.all.any((e) => e.name == raw)) {
      throw AgentToolException(
        AgentToolErrorCode.invalidArgument,
        '$raw is a query root: use the query tool to list it.',
        details: {'entity': raw},
      );
    }
    throw AgentToolException(
      AgentToolErrorCode.invalidArgument,
      'entity must be one of ${[for (final e in _catalog.nonRoots) e.name]}.',
      details: {'entity': raw},
    );
  }
}
