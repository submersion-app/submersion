import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/visibility/visibility_filter.dart';
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

/// The item holding a passport id, and what type it is now.
typedef PassportHolder = ({String equipmentId, EquipmentType type});

/// The passport id of any equipment item: the `passport_id` equipment
/// attribute (cylinder spec 6.5, gear tag spec 7). Reads and writes go through the equipment
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

  /// The one item holding [passportId], of any type unless [type] narrows
  /// it, limited to the gear [diverId] can see (owns or has been shared)
  /// when given; the whole library when null. An item keeps its id across a
  /// retype, and answers as what it is now (issue #2652).
  Future<PassportHolder?> findHolderByPassportId(
    String passportId, {
    String? diverId,
    EquipmentType? type,
  }) async {
    final holders = await _holdersOf(passportId, diverId: diverId, type: type);
    if (holders.isEmpty) return null;
    final row = holders.first;
    return (equipmentId: row.id, type: _typeOf(row.type));
  }

  /// Every item holding [passportId], in the order a lookup prefers them.
  /// One id should have one holder, but an old import could have written
  /// two. Resolve the same way every time: in service, oldest, then id.
  Future<List<EquipmentData>> _holdersOf(
    String passportId, {
    String? diverId,
    EquipmentType? type,
  }) async {
    final attrs = _db.equipmentAttributes;
    final eq = _db.equipment;
    final query =
        _db.select(attrs).join([
          innerJoin(eq, eq.id.equalsExp(attrs.equipmentId)),
        ])..where(
          attrs.attrKey.equals(EquipmentAttrKeys.passportId) &
              attrs.isCustom.equals(false) &
              attrs.valueText.equals(passportId),
        );
    if (type != null) query.where(eq.type.equals(type.name));
    final visible = VisibilityFilter.equipmentVisibleTo(_db, eq, diverId);
    if (visible != null) query.where(visible);
    return [for (final r in await query.get()) r.readTable(eq)]..sort((a, b) {
      final byFitted = (_isFitted(a) ? 0 : 1) - (_isFitted(b) ? 0 : 1);
      if (byFitted != 0) return byFitted;
      final byAge = a.createdAt.compareTo(b.createdAt);
      return byAge != 0 ? byAge : a.id.compareTo(b.id);
    });
  }

  Future<String?> findEquipmentIdByPassportId(
    String passportId, {
    String? diverId,
    EquipmentType? type,
  }) async => (await findHolderByPassportId(
    passportId,
    diverId: diverId,
    type: type,
  ))?.equipmentId;

  static EquipmentType _typeOf(String name) =>
      EquipmentType.values.asNameMap()[name] ?? EquipmentType.other;

  /// In service: active and neither retired, sold nor wanted (#2025), as
  /// EquipmentItem.isFitted defines it.
  static bool _isFitted(EquipmentData row) =>
      row.isActive &&
      row.status != EquipmentStatus.retired.name &&
      row.status != EquipmentStatus.sold.name &&
      row.status != EquipmentStatus.wanted.name;

  /// Removes [equipmentId]'s passport id, so a tag can move off a cylinder
  /// that is no longer in service.
  Future<void> _releasePassportId(String equipmentId) async {
    final existing = await _equipment.getAttributesForEquipment(equipmentId);
    await _equipment.saveAttributes(equipmentId, [
      for (final a in existing)
        if (a.isCustom || a.key != EquipmentAttrKeys.passportId) a,
    ], preserveSystem: false);
  }

  /// Writes [passportId] onto [equipmentId] and, for a cylinder, relinks the
  /// fills stored under it. Throws [PassportIdInUse] when a different
  /// visible item of any type that is still in service holds the id; one
  /// that is not gives it up.
  Future<void> assignPassportId({
    required String equipmentId,
    required String passportId,
    String? diverId,
  }) async {
    // One transaction for the whole move: the holder check, releasing a
    // holder no longer in service, writing the id and, for a cylinder,
    // moving the fills. Drift runs
    // transactions one at a time, so two links of the same tag cannot both
    // pass the check, and a failure part-way rolls every step back.
    await _db.transaction(() async {
      final holders = await _holdersOf(passportId, diverId: diverId);
      final others = [
        for (final row in holders)
          if (row.id != equipmentId) row,
      ];
      // An item still in service keeps its tag; retired, sold or inactive
      // ones give it up to the item being linked, every one of them, so the
      // id never stays on two rows.
      for (final row in others) {
        if (_isFitted(row)) throw PassportIdInUse(row.id);
      }
      for (final row in others) {
        await _releasePassportId(row.id);
      }
      final alreadyHeld = holders.any((row) => row.id == equipmentId);
      final target = await (_db.select(
        _db.equipment,
      )..where((t) => t.id.equals(equipmentId))).getSingleOrNull();
      // Fills belong to cylinders; other gear never collects them.
      final holdsFills = target?.type == EquipmentType.tank.name;
      final previous = await getPassportId(equipmentId);
      if (!alreadyHeld) {
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
      if (holdsFills && previous != null && previous != passportId) {
        await _fills.rekeyPassport(
          from: previous,
          to: passportId,
          equipmentId: equipmentId,
        );
      }
      if (holdsFills) {
        await _fills.relinkToEquipment(
          passportId: passportId,
          equipmentId: equipmentId,
        );
      }
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
