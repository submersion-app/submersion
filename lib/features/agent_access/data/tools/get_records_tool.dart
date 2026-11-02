import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/documents/document_dates.dart';
import 'package:submersion/features/agent_access/data/records/record_catalog.dart';
import 'package:submersion/features/agent_access/data/records/record_entity.dart';
import 'package:submersion/features/agent_access/data/records/record_reader.dart';
import 'package:submersion/features/agent_access/data/tools/tool_args.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';

const kGetRecordsMaxIds = 50;

/// Fetches full documents for records of any entity by id.
class GetRecordsTool implements AgentTool {
  GetRecordsTool({
    required DiverContextLoader loader,
    required RecordCatalog catalog,
  }) : _loader = loader,
       _catalog = catalog;

  final DiverContextLoader _loader;
  final RecordCatalog _catalog;

  @override
  String get name => 'get_records';

  @override
  String get description =>
      'Fetch full records of any entity by id (up to $kGetRecordsMaxIds per '
      'call). Values are metric with the unit in the key name (max_depth_m, '
      'water_temp_c, start_pressure_bar, weight_kg). $kDocumentDateRule Child '
      'blocks are returned only when listed in include; a name the entity '
      'does not have is refused and the refusal lists the ones it does. '
      'Samples and track points are paged with profile_offset and '
      'profile_limit. fields narrows each document to the named keys. Ids the '
      'named diver cannot see are listed under missing. Bytes (photos, card '
      'images, document pages) are never returned.';

  @override
  Map<String, Object?> get inputSchema => {
    'type': 'object',
    'properties': {
      'entity': {
        'type': 'string',
        'enum': [for (final e in _catalog.all) e.name],
      },
      'ids': {
        'type': 'array',
        'items': {'type': 'string'},
        'minItems': 1,
        'maxItems': kGetRecordsMaxIds,
      },
      'include': {
        'type': 'array',
        'items': {'type': 'string'},
        'description':
            'Child blocks to include, by entity. '
            '${[for (final e in _catalog.all)
              if (e.blocks.isNotEmpty) '${e.name}: ${e.blocks.join(', ')}'].join('; ')}.',
      },
      'fields': {
        'type': 'array',
        'items': {'type': 'string'},
        'description':
            'Top-level document keys to return. id is always returned. '
            'Omitted means the full document.',
      },
      'diver_id': {
        'type': 'string',
        'description': 'Profile to read as. Omitted means the active profile.',
      },
      'profile_offset': {'type': 'integer', 'minimum': 0, 'default': 0},
      'profile_limit': {
        'type': 'integer',
        'minimum': 1,
        'maximum': kProfileMaxLimit,
        'default': kProfileDefaultLimit,
      },
    },
    'required': ['entity', 'ids'],
    'additionalProperties': false,
  };

  @override
  Future<Map<String, Object?>> call(
    Map<String, Object?> args,
    AgentToolContext context,
  ) async {
    final entry = _catalog.named(args['entity']);
    // One document per distinct id, in the order first asked for.
    final ids = _ids(args['ids']).toSet().toList();
    final include = _include(entry, args['include']);
    final fields = _fields(args['fields']);
    final profileOffset = intArg(args, 'profile_offset', fallback: 0, min: 0);
    final profileLimit = intArg(
      args,
      'profile_limit',
      fallback: kProfileDefaultLimit,
      min: 1,
      max: kProfileMaxLimit,
    );
    final diverId = await _loader.resolveDiverId(args['diver_id'] as String?);

    final visible = await RecordReader(
      context.db,
    ).visibleIds(entry, ids, diverId);
    final documents = await entry.read(
      visible,
      RecordLoad(
        include: include,
        diverId: diverId,
        profileOffset: profileOffset,
        profileLimit: profileLimit,
      ),
    );
    return {
      'entity': entry.name,
      'records': [
        for (final id in ids)
          if (documents[id] case final document?)
            fields == null ? document : _narrow(document, fields),
      ],
      'missing': [
        for (final id in ids)
          if (!documents.containsKey(id)) id,
      ],
    };
  }

  List<String> _ids(Object? raw) {
    if (raw is! List || raw.isEmpty || raw.any((e) => e is! String)) {
      throw const AgentToolException(
        AgentToolErrorCode.invalidArgument,
        'ids must be a non-empty array of strings.',
      );
    }
    if (raw.length > kGetRecordsMaxIds) {
      throw AgentToolException(
        AgentToolErrorCode.tooManyIds,
        'At most $kGetRecordsMaxIds ids per call.',
        details: {'count': raw.length, 'max': kGetRecordsMaxIds},
      );
    }
    return raw.cast<String>();
  }

  Set<String> _include(RecordEntry entry, Object? raw) {
    if (raw == null) return const {};
    if (raw is! List || raw.any((e) => !entry.blocks.contains(e))) {
      throw AgentToolException(
        AgentToolErrorCode.invalidArgument,
        '${entry.name} include may only name ${entry.blocks.toList()}.',
        details: {'include': raw, 'valid': entry.blocks.toList()},
      );
    }
    return raw.cast<String>().toSet();
  }

  List<String>? _fields(Object? raw) {
    if (raw == null) return null;
    if (raw is! List || raw.any((e) => e is! String)) {
      throw const AgentToolException(
        AgentToolErrorCode.invalidArgument,
        'fields must be an array of strings.',
      );
    }
    return raw.cast<String>();
  }

  Map<String, Object?> _narrow(
    Map<String, Object?> document,
    List<String> fields,
  ) {
    final unknown = [
      for (final field in fields)
        if (!document.containsKey(field)) field,
    ];
    if (unknown.isNotEmpty) {
      throw AgentToolException(
        AgentToolErrorCode.invalidArgument,
        'Unknown fields $unknown.',
        details: {'unknown': unknown, 'valid': document.keys.toList()},
      );
    }
    return {
      'id': document['id'],
      for (final field in fields) field: document[field],
    };
  }
}
