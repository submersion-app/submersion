import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart'
    as domain;

/// A dive's sightings, through the species repository as the dive editor
/// writes them. A sighting keeps its species: the repository's update writes
/// only the count and the notes.
class SightingWrites extends WritableEntry {
  SightingWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'sightings';

  @override
  String get table => 'sightings';

  @override
  ChildOf get parent => const ChildOf(entity: 'dives', field: 'dive_id');

  @override
  final Map<String, FieldCodec> fields = const {
    'dive_id': FieldCodec.reference('dives'),
    'species_id': FieldCodec.reference('species'),
    'count': FieldCodec.integer(min: 1, max: 100000),
    'notes': FieldCodec.text(allowBlank: true),
  };

  @override
  Set<String> get requiredOnCreate => const {'species_id'};

  @override
  Set<String> get createOnly => const {'species_id'};

  @override
  String? titleOf(Map<String, Object?> document) =>
      document['species_name'] as String?;

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final sighting = await _r.species.addSighting(
      diveId: values['dive_id']! as String,
      speciesId: values['species_id']! as String,
      count: values['count'] as int? ?? 1,
      notes: values['notes'] as String? ?? '',
    );
    return sighting.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current = await _row(id);
    final v = update.values;
    await _r.species.updateSighting(
      domain.Sighting(
        id: id,
        diveId: current.diveId,
        speciesId: current.speciesId,
        speciesName: '',
        count: v.containsKey('count') ? v['count']! as int : current.count,
        notes: v.containsKey('notes') ? v['notes']! as String : current.notes,
      ),
    );
  }

  @override
  Future<void> delete(String id, String? ownerId) async {
    await _row(id);
    await _r.species.deleteSighting(id);
  }

  /// The row as stored. The update writes the count and the notes together,
  /// so the one the change leaves alone is read here.
  Future<({String diveId, String speciesId, int count, String notes})> _row(
    String id,
  ) async {
    final db = DatabaseService.instance.database;
    final row = await (db.select(
      db.sightings,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw AgentToolException(
        AgentToolErrorCode.writeRefused,
        'Sighting $id no longer exists.',
        details: {'id': id},
      );
    }
    return (
      diveId: row.diveId,
      speciesId: row.speciesId,
      count: row.count,
      notes: row.notes,
    );
  }
}
