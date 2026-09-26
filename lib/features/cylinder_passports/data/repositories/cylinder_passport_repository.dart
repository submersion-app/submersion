import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';

/// Namespace for minting passport ids from equipment ids (UUID v5). Fixed
/// forever: two devices that mint for the same cylinder before they sync
/// arrive at the same id, so neither printed label is orphaned.
const String kCylinderPassportNamespace =
    '3bd0f137-e4d0-4e1b-a179-02f37d160966';

/// Another cylinder the diver can see already carries this passport id.
class PassportIdInUse implements Exception {
  final String equipmentId;
  const PassportIdInUse(this.equipmentId);

  @override
  String toString() => 'PassportIdInUse($equipmentId)';
}

/// The passport id of a cylinder: the `passport_id` equipment attribute
/// (spec section 6.5). Reads and writes go through the equipment
/// repository's attribute path so the row ids, tombstones and pending marks
/// match every other curated attribute.
class CylinderPassportRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  CylinderPassportRepository({CylinderFillRepository? fills})
    : _fills = fills ?? CylinderFillRepository();

  final EquipmentRepository _equipment = EquipmentRepository();
  final CylinderFillRepository _fills;
  final _uuid = const Uuid();

  Future<String?> getPassportId(String equipmentId) async {
    final row =
        await (_db.select(_db.equipmentAttributes)..where(
              (t) =>
                  t.equipmentId.equals(equipmentId) &
                  t.attrKey.equals(EquipmentAttrKeys.passportId) &
                  t.isCustom.equals(false),
            ))
            .getSingleOrNull();
    final value = row?.valueText?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// The one cylinder holding [passportId], limited to [diverId]'s own gear
  /// when given. The sharing program's visibility clause replaces the
  /// diver_id test when it lands.
  Future<String?> findEquipmentIdByPassportId(
    String passportId, {
    String? diverId,
  }) async {
    final attrs = _db.equipmentAttributes;
    final eq = _db.equipment;
    final query =
        _db.select(attrs).join([
          innerJoin(eq, eq.id.equalsExp(attrs.equipmentId)),
        ])..where(
          attrs.attrKey.equals(EquipmentAttrKeys.passportId) &
              attrs.isCustom.equals(false) &
              attrs.valueText.equals(passportId) &
              // Only a cylinder holds a tag. An item retyped to other gear
              // keeps the id (a retype undone gets it back) but never
              // blocks or answers a lookup while it is not a tank.
              eq.type.equals(EquipmentType.tank.name),
        );
    if (diverId != null) query.where(eq.diverId.equals(diverId));
    final holders = [for (final r in await query.get()) r.readTable(eq)];
    if (holders.isEmpty) return null;
    // One id should have one holder, but an old import could have written
    // two. Resolve the same way every time: a cylinder still in service,
    // then the oldest row, then the id.
    final sorted = [...holders]
      ..sort((a, b) {
        final byFitted = (_isFitted(a) ? 0 : 1) - (_isFitted(b) ? 0 : 1);
        if (byFitted != 0) return byFitted;
        final byAge = a.createdAt.compareTo(b.createdAt);
        return byAge != 0 ? byAge : a.id.compareTo(b.id);
      });
    return sorted.first.id;
  }

  /// In service: active and neither retired nor sold, as EquipmentItem
  /// defines it.
  static bool _isFitted(EquipmentData row) =>
      row.isActive &&
      row.status != EquipmentStatus.retired.name &&
      row.status != EquipmentStatus.sold.name;

  /// Items that are no longer cylinders but still carry [passportId], other
  /// than [except]: the leftovers of a retype.
  Future<List<String>> _nonTankCarriers(
    String passportId,
    String except,
  ) async {
    final attrs = _db.equipmentAttributes;
    final eq = _db.equipment;
    final rows =
        await (_db.select(attrs).join([
              innerJoin(eq, eq.id.equalsExp(attrs.equipmentId)),
            ])..where(
              attrs.attrKey.equals(EquipmentAttrKeys.passportId) &
                  attrs.isCustom.equals(false) &
                  attrs.valueText.equals(passportId) &
                  eq.type.equals(EquipmentType.tank.name).not() &
                  eq.id.equals(except).not(),
            ))
            .get();
    return [for (final r in rows) r.readTable(eq).id];
  }

  /// Removes [equipmentId]'s passport id, so a tag can move off a cylinder
  /// that is no longer in service.
  Future<void> _releasePassportId(String equipmentId) async {
    final existing = await _equipment.getAttributesForEquipment(equipmentId);
    await _equipment.saveAttributes(equipmentId, [
      for (final a in existing)
        if (a.isCustom || a.key != EquipmentAttrKeys.passportId) a,
    ], preserveSystem: false);
  }

  /// Writes [passportId] onto [equipmentId] and relinks the fills stored
  /// under it. Throws [PassportIdInUse] when a different visible cylinder
  /// that is still in service holds the id; one that is not gives it up.
  Future<void> assignPassportId({
    required String equipmentId,
    required String passportId,
    String? diverId,
  }) async {
    // One transaction for the whole move: the holder check, releasing a
    // retired holder, writing the id and moving the fills. Drift runs
    // transactions one at a time, so two links of the same tag cannot both
    // pass the check, and a failure part-way rolls every step back.
    await _db.transaction(() async {
      final holder = await findEquipmentIdByPassportId(
        passportId,
        diverId: diverId,
      );
      if (holder != null && holder != equipmentId) {
        final row = await (_db.select(
          _db.equipment,
        )..where((t) => t.id.equals(holder))).getSingle();
        // A cylinder still in service keeps its tag; a retired, sold or
        // inactive one gives it up to the cylinder being linked.
        if (_isFitted(row)) throw PassportIdInUse(holder);
        await _releasePassportId(holder);
      }
      // A retyped item still carrying the id gives it up to the cylinder the
      // tag is now linked to, so the id is never on two rows.
      for (final carrier in await _nonTankCarriers(passportId, equipmentId)) {
        await _releasePassportId(carrier);
      }
      final previous = await getPassportId(equipmentId);
      if (holder != equipmentId) {
        final existing = await _equipment.getAttributesForEquipment(
          equipmentId,
        );
        final desired = [
          for (final a in existing)
            if (a.isCustom || a.key != EquipmentAttrKeys.passportId) a,
          EquipmentAttribute.curated(
            equipmentId: equipmentId,
            key: EquipmentAttrKeys.passportId,
            valueText: passportId,
          ),
        ];
        await _equipment.saveAttributes(equipmentId, desired);
      }
      if (previous != null && previous != passportId) {
        await _fills.rekeyPassport(
          from: previous,
          to: passportId,
          equipmentId: equipmentId,
        );
      }
      await _fills.relinkToEquipment(
        passportId: passportId,
        equipmentId: equipmentId,
      );
    });
  }

  /// The cylinder's passport id, minted on first use. Minting is a pure
  /// function of the equipment id, so every device mints the same one.
  Future<String> ensurePassportId(String equipmentId, {String? diverId}) async {
    final existing = await getPassportId(equipmentId);
    if (existing != null) return existing;
    final minted = _uuid.v5(kCylinderPassportNamespace, equipmentId);
    await assignPassportId(
      equipmentId: equipmentId,
      passportId: minted,
      diverId: diverId,
    );
    return minted;
  }
}
