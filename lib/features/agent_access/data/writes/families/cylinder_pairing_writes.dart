import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_pairing.dart';
import 'package:submersion/features/cylinder_passports/domain/services/pairing_rules.dart';

/// Twin set pairings of two cylinders (issue #4242), through the repository
/// the Twin set card uses: a pairing is made from a day, ended on a later
/// day, or deleted when it was a mistake. The two cylinders are fixed once
/// paired; a swap is an end and a new pairing. A pairing that would put a
/// cylinder in two sets on one day is refused, naming the set it clashes
/// with, where the card offers to replace a partner instead.
class CylinderPairingWrites extends WritableEntry {
  CylinderPairingWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'cylinder_pairings';

  @override
  String get table => 'cylinder_pairings';

  @override
  ChildOf get parent =>
      const ChildOf(entity: 'equipment', field: 'cylinder_a_id');

  @override
  late final Map<String, FieldCodec> fields = {
    'cylinder_a_id': const FieldCodec.reference('equipment'),
    'cylinder_b_id': const FieldCodec.reference('equipment'),
    'paired_on': const FieldCodec.calendarDate(),
    'unpaired_on': const FieldCodec.calendarDate(nullable: true),
  };

  @override
  Set<String> get requiredOnCreate => const {'cylinder_b_id', 'paired_on'};

  @override
  Set<String> get createOnly => const {'cylinder_b_id', 'paired_on'};

  @override
  String get note =>
      'Days are whole calendar days: a pairing covers paired_on up to the '
      'day before unpaired_on, and is current while unpaired_on is null. To '
      'swap a partner, end the current pairing and create a new one.';

  static DateTime? _day(Object? value) => switch (value) {
    final String text => DateTime.parse('${text}T00:00:00Z'),
    _ => null,
  };

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) return null;
    final pairings = _r.cylinderPairings;
    if (check.kind == ChangeKind.create) {
      final a = check.values['cylinder_a_id']! as String;
      final b = check.values['cylinder_b_id']! as String;
      if (a == b) {
        return const PlanBlock(
          BlockReason.invalidValue,
          'cylinder_b_id: a cylinder cannot pair with itself.',
        );
      }
      for (final id in [a, b]) {
        final item = await _r.equipment.getEquipmentById(id);
        if (item?.type != EquipmentType.tank) {
          return PlanBlock(
            BlockReason.invalidValue,
            '$id is not a cylinder; only two cylinders form a twin set.',
          );
        }
      }
      final clashes = clashesWith(
        await pairings.getAll(),
        cylinderAId: a,
        cylinderBId: b,
        pairedOn: _day(check.values['paired_on'])!,
      );
      return clashes.isEmpty ? null : await _clashBlock(clashes);
    }
    if (!check.values.containsKey('unpaired_on')) return null;
    final document = check.document!;
    final start = _day(document['paired_on'])!;
    final end = _day(check.values['unpaired_on']);
    if (end == null) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'unpaired_on: an ended pairing is not reopened; create a new one.',
      );
    }
    if (!end.isAfter(start)) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'unpaired_on: a pairing ends after the day it starts.',
      );
    }
    final clashes = clashesWith(
      await pairings.getAll(),
      cylinderAId: document['cylinder_a_id']! as String,
      cylinderBId: document['cylinder_b_id']! as String,
      pairedOn: start,
      unpairedOn: end,
      ignoreId: check.id,
    );
    return clashes.isEmpty ? null : await _clashBlock(clashes);
  }

  Future<PlanBlock> _clashBlock(List<CylinderPairing> clashes) async {
    Future<String> nameOf(String id) async =>
        (await _r.equipment.getEquipmentById(id))?.name ?? id;
    final names = [
      for (final c in clashes)
        '${await nameOf(c.cylinderAId)} and ${await nameOf(c.cylinderBId)} '
            '(${c.id})',
    ];
    return PlanBlock(
      BlockReason.invalidValue,
      'A cylinder can be in one twin set on any day. This overlaps the '
      'pairing of ${names.join('; ')}. End that pairing first.',
    );
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async =>
      (await _r.cylinderPairings.createPairing(
        cylinderAId: values['cylinder_a_id']! as String,
        cylinderBId: values['cylinder_b_id']! as String,
        pairedOn: _day(values['paired_on'])!,
      )).id;

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final end = _day(update.values['unpaired_on']);
    if (end != null) await _r.cylinderPairings.endPairing(id, end);
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.cylinderPairings.deletePairing(id);
}
