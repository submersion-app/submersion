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
  ///
  /// When no item stores the id, the item it was minted for answers in its
  /// place (issue #4827): see [_mintersOf].
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
    final stored = [for (final r in await query.get()) r.readTable(eq)];
    final holders = stored.isNotEmpty
        ? stored
        : await _mintersOf(passportId, diverId: diverId, type: type);
    return holders..sort(_preferredHolderFirst);
  }

  /// The items [passportId] was minted for that store no passport id on
  /// this device yet (issue #4827). The device that first opens an item's
  /// passport mints its id and stores it there, and the row reaches the
  /// others only on that device's next sync; until then a label printed or
  /// shown from it would read as someone else's gear. Minting is a pure
  /// function of the equipment id, so the item is recognised without the
  /// row. An item that stores a different id gave its minted one up (it
  /// took another tag) and does not answer to it.
  Future<List<EquipmentData>> _mintersOf(
    String passportId, {
    String? diverId,
    EquipmentType? type,
  }) async {
    final wanted = passportId.trim().toLowerCase();
    // A minted id is a version 5 UUID; anything else was never minted here,
    // so skip hashing every item for it.
    if (wanted.length != 36 || wanted[14] != '5') return [];
    final attrs = _db.equipmentAttributes;
    final eq = _db.equipment;
    final query = _db.select(eq)
      ..where(
        (t) => t.id.isNotInQuery(
          _db.selectOnly(attrs)
            ..addColumns([attrs.equipmentId])
            ..where(
              attrs.attrKey.equals(EquipmentAttrKeys.passportId) &
                  attrs.isCustom.equals(false),
            ),
        ),
      );
    if (type != null) query.where((t) => t.type.equals(type.name));
    final visible = VisibilityFilter.equipmentVisibleTo(_db, eq, diverId);
    if (visible != null) query.where((_) => visible);
    return [
      for (final row in await query.get())
        if (_mint(row.id) == wanted) row,
    ];
  }

  /// The passport id [ensurePassportId] mints for [equipmentId].
  String _mint(String equipmentId) =>
      _uuid.v5(kCylinderPassportNamespace, equipmentId);

  static int _preferredHolderFirst(EquipmentData a, EquipmentData b) {
    final byFitted = (_isFitted(a) ? 0 : 1) - (_isFitted(b) ? 0 : 1);
    if (byFitted != 0) return byFitted;
    final byAge = a.createdAt.compareTo(b.createdAt);
    return byAge != 0 ? byAge : a.id.compareTo(b.id);
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

  /// The item still in service, other than [exceptEquipmentId], that holds
  /// [passportId] for [diverId]: what [assignPassportId] refuses on, read
  /// without writing, so a gear item's sitting can ask before it holds a
  /// link (issue #4527). Null when the id is free to take.
  Future<String?> fittedHolderOf(
    String passportId, {
    required String exceptEquipmentId,
    String? diverId,
  }) async {
    for (final row in await _holdersOf(passportId, diverId: diverId)) {
      if (row.id != exceptEquipmentId && _isFitted(row)) return row.id;
    }
    return null;
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
      final target = await (_db.select(
        _db.equipment,
      )..where((t) => t.id.equals(equipmentId))).getSingleOrNull();
      // Fills belong to cylinders; other gear never collects them.
      final holdsFills = target?.type == EquipmentType.tank.name;
      final previous = await getPassportId(equipmentId);
      // Whether the item stores the id already. Being among the holders is
      // not enough: an item answers to its own minted id before storing it.
      if (previous != passportId) {
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

  /// Writes [passportId] onto [equipmentId] for an import (issue #2651) and
  /// returns whether it did. Unlike [assignPassportId], which a diver runs
  /// deliberately, an import only fills an empty slot: an item keeps a tag
  /// it already has, and an id held by any other item [diverId] can see,
  /// in service or not, stays there. Nothing is released or re-keyed. A
  /// cylinder that takes the id relinks the fills stored under it.
  Future<bool> adoptImportedPassportId({
    required String equipmentId,
    required String passportId,
    String? diverId,
  }) => _db.transaction(() async {
    if (await getPassportId(equipmentId) != null) return false;
    final holders = await _holdersOf(passportId, diverId: diverId);
    if (holders.any((row) => row.id != equipmentId)) return false;
    final target = await (_db.select(
      _db.equipment,
    )..where((t) => t.id.equals(equipmentId))).getSingleOrNull();
    if (target == null) return false;
    final existing = await _equipment.getAttributesForEquipment(equipmentId);
    await _equipment.saveAttributes(equipmentId, [
      for (final a in existing)
        if (a.isCustom || a.key != EquipmentAttrKeys.passportId) a,
      EquipmentAttribute.curated(
        equipmentId: equipmentId,
        key: EquipmentAttrKeys.passportId,
        valueText: passportId,
      ),
    ]);
    if (target.type == EquipmentType.tank.name) {
      await _fills.relinkToEquipment(
        passportId: passportId,
        equipmentId: equipmentId,
      );
    }
    return true;
  });

  /// The cylinder's passport id, minted on first use. Minting is a pure
  /// function of the equipment id, so every device mints the same one.
  Future<String> ensurePassportId(String equipmentId, {String? diverId}) async {
    final existing = await getPassportId(equipmentId);
    if (existing != null) return existing;
    final minted = _mint(equipmentId);
    await assignPassportId(
      equipmentId: equipmentId,
      passportId: minted,
      diverId: diverId,
    );
    return minted;
  }
}
