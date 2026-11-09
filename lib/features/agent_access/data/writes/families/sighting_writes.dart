import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart'
    as domain;

/// A dive's sightings, through the species repository as the dive editor
/// writes them. A sighting keeps its species: the repository's update writes
/// only the abundance, the count and the notes.
///
/// Abundance (issue #4337): a write naming neither `abundance` nor `count`
/// is Seen; a `count` without an `abundance` is an exact count; a REEF group
/// or Seen always stores count 1.
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
  late final Map<String, FieldCodec> fields = {
    'dive_id': const FieldCodec.reference('dives'),
    'species_id': const FieldCodec.reference('species'),
    'abundance': FieldCodec.enumName(SightingAbundance.values),
    'count': const FieldCodec.integer(min: 1, max: 100000),
    'notes': const FieldCodec.text(allowBlank: true),
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
    final amount = _amount(
      values,
      current: (abundance: SightingAbundance.seen, count: 1),
    );
    final sighting = await _r.species.addSighting(
      diveId: values['dive_id']! as String,
      speciesId: values['species_id']! as String,
      abundance: amount.abundance,
      count: amount.count,
      notes: values['notes'] as String? ?? '',
    );
    return sighting.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current = await _row(id);
    final v = update.values;
    final amount = _amount(
      v,
      current: (
        abundance: SightingAbundance.fromStorage(current.abundance),
        count: current.count,
      ),
    );
    await _r.species.updateSighting(
      domain.Sighting(
        id: id,
        diveId: current.diveId,
        speciesId: current.speciesId,
        speciesName: '',
        abundance: amount.abundance,
        count: amount.count,
        notes: v.containsKey('notes') ? v['notes']! as String : current.notes,
      ),
    );
  }

  @override
  Future<void> delete(String id, String? ownerId) async {
    await _row(id);
    await _r.species.deleteSighting(id);
  }

  /// The amount a write leaves: an `abundance` it names (an exact one with
  /// its `count`, or the [current] count when it was exact already), a
  /// `count` alone as an exact count, or [current] when it names neither.
  static SightingAmount _amount(
    Map<String, Object?> values, {
    required SightingAmount current,
  }) {
    final count = values['count'] as int?;
    final named = values['abundance'] as String?;
    if (named == null) {
      return count == null
          ? current
          : (abundance: SightingAbundance.exact, count: count);
    }
    final abundance = SightingAbundance.values.byName(named);
    if (abundance != SightingAbundance.exact) {
      return (abundance: abundance, count: 1);
    }
    final kept = current.abundance == SightingAbundance.exact
        ? current.count
        : 1;
    return (abundance: SightingAbundance.exact, count: count ?? kept);
  }

  /// The row as stored. The update writes the abundance, the count and the
  /// notes together, so the ones the change leaves alone are read here.
  Future<
    ({
      String diveId,
      String speciesId,
      String? abundance,
      int count,
      String notes,
    })
  >
  _row(String id) async {
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
      abundance: row.abundance,
      count: row.count,
      notes: row.notes,
    );
  }
}
