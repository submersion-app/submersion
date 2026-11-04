import 'package:submersion/core/constants/enums.dart' show SpeciesCategory;
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/built_in_rule.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart'
    as domain;

/// Species, through the repository the species pages use. Every species can
/// be edited, built-in ones too; only a custom species nothing refers to can
/// be deleted, and it leaves the sites that expected it. A species' photo is
/// a link the app manages, so it is not written here.
class SpeciesWrites extends WritableEntry {
  SpeciesWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'species';

  @override
  String get table => 'species';

  @override
  late final Map<String, FieldCodec> fields = {
    'common_name': const FieldCodec.text(maxLength: 200),
    'scientific_name': const FieldCodec.text(maxLength: 200, nullable: true),
    'category': FieldCodec.enumName(SpeciesCategory.values),
    'taxonomy_class': const FieldCodec.text(maxLength: 100, nullable: true),
    'description': const FieldCodec.text(allowBlank: true, nullable: true),
  };

  @override
  Set<String> get requiredOnCreate => const {'common_name', 'category'};

  @override
  String? titleOf(Map<String, Object?> document) =>
      document['common_name'] as String?;

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind != ChangeKind.delete) return null;
    if (check.document?['is_built_in'] == true) {
      return const PlanBlock(
        BlockReason.notPermitted,
        'This is one of the app\'s built-in species, which can be edited but '
        'not deleted.',
      );
    }
    if (await _stillInUse(check.id!, check.soFar)) {
      return const PlanBlock(
        BlockReason.notPermitted,
        'A sighting or a photo names this species, and the app does not '
        'delete one in use.',
      );
    }
    return null;
  }

  /// Whether a sighting or a photo still names species [id] once the set's
  /// earlier deletes run, counted as isSpeciesInUse counts it: a sighting
  /// an earlier delete removes, or one on a dive it removes, no longer does.
  Future<bool> _stillInUse(String id, SetSoFar soFar) async {
    final sightings = await countLinks(
      'sightings',
      'species_id',
      id,
      except: [
        ('id', [...?soFar.deleted['sightings']]),
        ('dive_id', [...?soFar.deleted['dives']]),
      ],
    );
    return sightings > 0 ||
        await countLinks('media_species', 'species_id', id) > 0;
  }

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async {
    final sites = await countLinks('site_species', 'species_id', id);
    return DeleteReach(unlinked: {if (sites > 0) 'site_species': sites});
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async =>
      (await _r.species.createSpecies(
        commonName: values['common_name']! as String,
        scientificName: values['scientific_name'] as String?,
        category: SpeciesCategory.values.byName(values['category']! as String),
        taxonomyClass: values['taxonomy_class'] as String?,
        description: values['description'] as String?,
      )).id;

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current = await _r.species.getSpeciesById(id) ?? _gone(id);
    final v = update.values;
    T? kept<T>(String key, T? now) => v.containsKey(key) ? v[key] as T? : now;
    await _r.species.updateSpecies(
      domain.Species(
        id: id,
        commonName: v['common_name'] as String? ?? current.commonName,
        scientificName: kept('scientific_name', current.scientificName),
        category: v['category'] == null
            ? current.category
            : SpeciesCategory.values.byName(v['category']! as String),
        taxonomyClass: kept('taxonomy_class', current.taxonomyClass),
        description: kept('description', current.description),
        photoPath: current.photoPath,
        isBuiltIn: current.isBuiltIn,
      ),
    );
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.species.deleteSpecies(id);

  Never _gone(String id) => throw AgentToolException(
    AgentToolErrorCode.writeRefused,
    'Species $id no longer exists.',
    details: {'id': id},
  );
}
