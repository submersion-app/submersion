import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/documents/dive_document.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';

const kGetRecordsMaxIds = 50;

/// Fetches full documents for records by id. Dives only in this version.
class GetRecordsTool implements AgentTool {
  GetRecordsTool({
    required DiverContextLoader loader,
    required DiveRepository dives,
    required BuddyRepository buddies,
    required SpeciesRepository species,
    required MediaRepository media,
    required DiveTypeRepository diveTypes,
  }) : _loader = loader,
       _dives = dives,
       _buddies = buddies,
       _species = species,
       _media = media,
       _diveTypes = diveTypes;

  final DiverContextLoader _loader;
  final DiveRepository _dives;
  final BuddyRepository _buddies;
  final SpeciesRepository _species;
  final MediaRepository _media;
  final DiveTypeRepository _diveTypes;

  static const _entities = ['dives'];

  @override
  String get name => 'get_records';

  @override
  String get description =>
      'Fetch full records by id (up to $kGetRecordsMaxIds per call). Values '
      'are metric with the unit in the key name (max_depth_m, water_temp_c, '
      'start_pressure_bar, weight_kg); Dates are ISO 8601 strings of the dive\'s local wall clock carried with a nominal Z suffix; they are not UTC instants, so do not shift them to another time zone. Child blocks '
      '(tanks, buddies, tags, types, weights, sightings, media, profile) are '
      'returned only when listed in include; profile samples are paged with '
      'profile_offset and profile_limit. Ids the named diver cannot see are '
      'listed under missing.';

  @override
  Map<String, Object?> get inputSchema => {
    'type': 'object',
    'properties': {
      'entity': {'type': 'string', 'enum': _entities},
      'ids': {
        'type': 'array',
        'items': {'type': 'string'},
        'minItems': 1,
        'maxItems': kGetRecordsMaxIds,
      },
      'include': {
        'type': 'array',
        'items': {'type': 'string', 'enum': kDiveDocumentBlocks.toList()},
        'description': 'Child blocks to include.',
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
    final entity = args['entity'];
    if (!_entities.contains(entity)) {
      throw AgentToolException(
        AgentToolErrorCode.invalidArgument,
        'entity must be one of $_entities in this version.',
        details: {'entity': entity},
      );
    }
    final ids = _ids(args['ids']);
    final include = _include(args['include']);
    final profileOffset = _intArg(args, 'profile_offset', 0, 0, null);
    final profileLimit = _intArg(
      args,
      'profile_limit',
      kProfileDefaultLimit,
      1,
      kProfileMaxLimit,
    );
    final diverId = await _loader.resolveDiverId(args['diver_id'] as String?);

    final typeNames = include.contains('types')
        ? {
            for (final t in await _diveTypes.getAllDiveTypes(diverId: diverId))
              t.id: t.name,
          }
        : const <String, String>{};

    final records = <Map<String, Object?>>[];
    final missing = <String>[];
    for (final id in ids) {
      final dive = await _dives.getDiveById(id);
      if (dive == null || dive.diverId != diverId) {
        missing.add(id);
        continue;
      }
      records.add(
        diveDocument(
          dive,
          buddies: include.contains('buddies')
              ? await _buddies.getBuddiesForDive(id)
              : null,
          sightings: include.contains('sightings')
              ? await _species.getSightingsForDive(id)
              : null,
          media: include.contains('media')
              ? await _media.getMediaForDive(id)
              : null,
          typeNames: typeNames,
          include: include,
          profileOffset: profileOffset,
          profileLimit: profileLimit,
        ),
      );
    }
    return {'entity': entity, 'records': records, 'missing': missing};
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

  Set<String> _include(Object? raw) {
    if (raw == null) return const {};
    if (raw is! List || raw.any((e) => !kDiveDocumentBlocks.contains(e))) {
      throw AgentToolException(
        AgentToolErrorCode.invalidArgument,
        'include may only name ${kDiveDocumentBlocks.toList()}.',
        details: {'include': raw},
      );
    }
    return raw.cast<String>().toSet();
  }

  int _intArg(
    Map<String, Object?> args,
    String key,
    int fallback,
    int min,
    int? max,
  ) {
    final raw = args[key];
    if (raw == null) return fallback;
    if (raw is! int || raw < min || (max != null && raw > max)) {
      throw AgentToolException(
        AgentToolErrorCode.invalidArgument,
        '$key must be an integer from $min${max == null ? '' : ' to $max'}.',
        details: {key: raw},
      );
    }
    return raw;
  }
}
