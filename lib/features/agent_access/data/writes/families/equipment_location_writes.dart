import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';

/// The places gear is kept, through the repository the gear location sheet
/// uses. A place any move names keeps its history's name: it is archived,
/// never deleted, as the app refuses that delete. A Dive center place stands
/// for a saved center and a Person place for a buddy; a kind change drops the
/// link the new kind does not hold, as the place dialog's save drops it.
class EquipmentLocationWrites extends WritableEntry {
  EquipmentLocationWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'equipment_locations';

  @override
  String get table => 'equipment_locations';

  @override
  late final Map<String, FieldCodec> fields = {
    'name': const FieldCodec.text(maxLength: 100, trim: true),
    'kind': FieldCodec.enumName(EquipmentLocationKind.values),
    'dive_center_id': const FieldCodec.reference('centers', nullable: true),
    'buddy_id': const FieldCodec.reference('buddies', nullable: true),
    'notes': const FieldCodec.text(allowBlank: true, trim: true),
    'is_archived': const FieldCodec.flag(),
  };

  @override
  Set<String> get requiredOnCreate => const {'name', 'kind'};

  /// Each link and the kind of place that holds it.
  static const _links = {
    'dive_center_id': EquipmentLocationKind.diveCenter,
    'buddy_id': EquipmentLocationKind.person,
  };

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind != ChangeKind.delete) {
      final kind = check.values['kind'] ?? check.document?['kind'];
      for (final MapEntry(key: link, value: holder) in _links.entries) {
        if (check.values[link] != null && kind != holder.name) {
          return PlanBlock(
            BlockReason.invalidValue,
            '$link: only a ${holder.name} place stands for one.',
          );
        }
      }
      return null;
    }
    if (!await _r.equipmentLocations.isInUse(check.id!)) return null;
    return const PlanBlock(
      BlockReason.notPermitted,
      'A move names this place, and the app keeps it so that history keeps '
      'its name. Archive it with is_archived true instead.',
    );
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final locations = _r.equipmentLocations;
    final place = await locations.createLocation(
      diverId: diverId,
      name: values['name']! as String,
      kind: EquipmentLocationKind.values.byName(values['kind']! as String),
      diveCenterId: values['dive_center_id'] as String?,
      buddyId: values['buddy_id'] as String?,
      notes: values['notes'] as String? ?? '',
    );
    if (values['is_archived'] == true) {
      await locations.setArchived(place.id, archived: true);
    }
    return place.id;
  }

  /// The links a kind change in [values] drops from [document]: those the
  /// new kind does not hold.
  static Map<String, Object?> _dropped(
    Map<String, Object?> document,
    Map<String, Object?> values,
  ) {
    final kind = values['kind'];
    if (kind == null || kind == document['kind']) return const {};
    return {
      for (final MapEntry(key: link, value: holder) in _links.entries)
        if (kind != holder.name &&
            !values.containsKey(link) &&
            document[link] != null)
          link: null,
    };
  }

  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async => SideEffects(fields: _dropped(document, update.values));

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final locations = _r.equipmentLocations;
    if (update.values.keys.any((key) => key != 'is_archived')) {
      final current =
          await locations.getLocation(id) ??
          (throw AgentToolException(
            AgentToolErrorCode.writeRefused,
            'Place $id no longer exists.',
            details: {'id': id},
          ));
      final v = {
        ...update.values,
        ..._dropped({
          'kind': current.kind.name,
          'dive_center_id': current.diveCenterId,
          'buddy_id': current.buddyId,
        }, update.values),
      };
      await locations.updateLocation(
        current.copyWith(
          name: v['name'] as String?,
          kind: v['kind'] == null
              ? null
              : EquipmentLocationKind.values.byName(v['kind']! as String),
          diveCenterId: v['dive_center_id'] as String?,
          clearDiveCenterId:
              v.containsKey('dive_center_id') && v['dive_center_id'] == null,
          buddyId: v['buddy_id'] as String?,
          clearBuddyId: v.containsKey('buddy_id') && v['buddy_id'] == null,
          notes: v['notes'] as String?,
          isArchived: v['is_archived'] as bool?,
        ),
      );
    } else if (update.values['is_archived'] case final bool archived) {
      await locations.setArchived(id, archived: archived);
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.equipmentLocations.deleteLocation(id);
}

/// The moves of a gear item between places, through the repository the
/// gear location sheet records them with. A move belongs to its item.
class EquipmentLocationMoveWrites extends WritableEntry {
  EquipmentLocationMoveWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'equipment_location_moves';

  @override
  String get table => 'equipment_location_moves';

  @override
  ChildOf get parent =>
      const ChildOf(entity: 'equipment', field: 'equipment_id');

  @override
  late final Map<String, FieldCodec> fields = {
    'equipment_id': const FieldCodec.reference('equipment'),
    'location_id': const FieldCodec.reference(
      'equipment_locations',
      nullable: true,
    ),
    // A moment, as a read lists it in UTC.
    'moved_at': const FieldCodec.instant(),
    'note': const FieldCodec.text(allowBlank: true, trim: true),
  };

  /// Where and when, always named: null for location_id takes the item out
  /// of every place.
  @override
  Set<String> get requiredOnCreate => const {'location_id', 'moved_at'};

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async =>
      (await _r.equipmentLocationMoves.recordMoves(
        equipmentIds: [values['equipment_id']! as String],
        locationId: values['location_id'] as String?,
        movedAt: values['moved_at']! as DateTime,
        note: values['note'] as String? ?? '',
      )).single.id;

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current = await _move(id);
    final v = update.values;
    await _r.equipmentLocationMoves.updateMove(
      current.copyWith(
        locationId: v['location_id'] as String?,
        clearLocation: v.containsKey('location_id') && v['location_id'] == null,
        movedAt: v['moved_at'] as DateTime?,
        note: v['note'] as String?,
      ),
    );
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.equipmentLocationMoves.deleteMove(id);

  /// Move [id], found through its item, the repository's own read.
  Future<EquipmentLocationMove> _move(String id) async {
    final db = DatabaseService.instance.database;
    final row = await (db.select(
      db.equipmentLocationMoves,
    )..where((m) => m.id.equals(id))).getSingleOrNull();
    final moves = row == null
        ? const <EquipmentLocationMove>[]
        : await _r.equipmentLocationMoves.getMovesFor(row.equipmentId);
    return moves.where((m) => m.id == id).firstOrNull ??
        (throw AgentToolException(
          AgentToolErrorCode.writeRefused,
          'Move $id no longer exists.',
          details: {'id': id},
        ));
  }
}
