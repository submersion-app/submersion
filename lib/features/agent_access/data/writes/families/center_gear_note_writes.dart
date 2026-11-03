import 'package:submersion/core/constants/enums.dart' show EquipmentType;
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';

/// The notes a diver keeps on a dive center's rental gear, through the
/// repository the center page uses. A note is dated when it is written and
/// keeps that date; the dive it names only says where it was noticed.
class CenterGearNoteWrites extends WritableEntry {
  CenterGearNoteWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'center_gear_notes';

  @override
  String get table => 'dive_center_gear_notes';

  @override
  ChildOf get parent => const ChildOf(
    entity: 'centers',
    field: 'center_id',
    column: 'dive_center_id',
  );

  @override
  late final Map<String, FieldCodec> fields = {
    'center_id': const FieldCodec.reference('centers'),
    'gear_type': FieldCodec.enumName(EquipmentType.values),
    'verdict': FieldCodec.enumName(RentalVerdict.values),
    'label': const FieldCodec.text(maxLength: 100, nullable: true),
    'size': const FieldCodec.text(maxLength: 40, nullable: true),
    'lead_adjustment_kg': const FieldCodec.number(
      min: -30,
      max: 30,
      nullable: true,
    ),
    'volume_l': const FieldCodec.number(min: 0, max: 60, nullable: true),
    'note': const FieldCodec.text(allowBlank: true),
    'dive_id': const FieldCodec.reference('dives', nullable: true),
  };

  @override
  Set<String> get requiredOnCreate => const {'gear_type'};

  @override
  String? titleOf(Map<String, Object?> document) =>
      document['label'] as String? ?? document['gear_type'] as String?;

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final now = DateTime.now();
    final note = await _r.centerGearNotes.create(
      _applied(
        DiveCenterGearNote(
          id: '',
          diveCenterId: values['center_id']! as String,
          gearType: EquipmentType.values.byName(values['gear_type']! as String),
          notedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
        values,
      ),
    );
    return note.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current = await _r.centerGearNotes.getById(id);
    if (current == null) {
      throw AgentToolException(
        AgentToolErrorCode.writeRefused,
        'Gear note $id no longer exists.',
        details: {'id': id},
      );
    }
    await _r.centerGearNotes.update(_applied(current, update.values));
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.centerGearNotes.delete(id);

  /// [note] with the named values, a key sent as null cleared.
  DiveCenterGearNote _applied(DiveCenterGearNote note, Map<String, Object?> v) {
    T? kept<T>(String key, T? now) => v.containsKey(key) ? v[key] as T? : now;
    return DiveCenterGearNote(
      id: note.id,
      diveCenterId: note.diveCenterId,
      gearType: v['gear_type'] == null
          ? note.gearType
          : EquipmentType.values.byName(v['gear_type']! as String),
      label: kept('label', note.label),
      size: kept('size', note.size),
      verdict: v['verdict'] == null
          ? note.verdict
          : RentalVerdict.values.byName(v['verdict']! as String),
      leadAdjustmentKg: kept('lead_adjustment_kg', note.leadAdjustmentKg),
      volumeLiters: kept('volume_l', note.volumeLiters),
      note: v['note'] as String? ?? note.note,
      diveId: kept('dive_id', note.diveId),
      notedAt: note.notedAt,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
    );
  }
}
