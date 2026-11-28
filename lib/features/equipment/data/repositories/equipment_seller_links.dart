import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';

const _linkChunkSize = 500;

/// A gear item's buddy seller and its `retailer` name before a merge moved
/// it, for the merge's undo (issue #5140).
typedef SellerLinkSnapshot = ({String buddyId, String? retailer});

/// Writes each buddy's current name into the `retailer` of every item that
/// [buddyIds] sold, drops the link and stages the item (issue #5140). The
/// item keeps who sold it, as typed. The schema's SET NULL would clear the
/// link too, but it reaches no peer and keeps no name. Run it inside the
/// deleting transaction, before the buddies go.
Future<void> clearEquipmentSellerBuddyLinks(
  AppDatabase db,
  SyncRepository syncRepository,
  Iterable<String> buddyIds, {
  required int now,
}) async {
  final names = await _buddyNames(db, buddyIds);
  for (final item in await _soldBy(db, buddyIds, buddies: true)) {
    await _write(
      db,
      syncRepository,
      item.id,
      buddyId: null,
      centerId: null,
      retailer: names[item.sellerBuddyId],
      now: now,
    );
  }
}

/// [clearEquipmentSellerBuddyLinks] for the dive centres [centerIds].
Future<void> clearEquipmentSellerCenterLinks(
  AppDatabase db,
  SyncRepository syncRepository,
  Iterable<String> centerIds, {
  required int now,
}) async {
  final names = <String, String>{};
  for (final chunk in centerIds.toSet().slices(_linkChunkSize)) {
    for (final row in await (db.select(
      db.diveCenters,
    )..where((t) => t.id.isIn(chunk))).get()) {
      names[row.id] = row.name;
    }
  }
  for (final item in await _soldBy(db, centerIds, buddies: false)) {
    await _write(
      db,
      syncRepository,
      item.id,
      buddyId: null,
      centerId: null,
      retailer: names[item.sellerDiveCenterId],
      now: now,
    );
  }
}

/// Moves every item sold by one of [fromBuddyIds] onto [toBuddyId], named
/// as the survivor, and stages it, for a buddy merge. Returns each moved
/// item's previous buddy and name, which [restoreEquipmentSellerBuddyLinks]
/// puts back on an undo. Run it inside the merge's transaction, before the
/// duplicates go.
Future<Map<String, SellerLinkSnapshot>> repointEquipmentSellerBuddyLinks(
  AppDatabase db,
  SyncRepository syncRepository, {
  required List<String> fromBuddyIds,
  required String toBuddyId,
  required int now,
}) async {
  final items = await _soldBy(db, fromBuddyIds, buddies: true);
  if (items.isEmpty) return const {};
  final survivor = (await _buddyNames(db, [toBuddyId]))[toBuddyId];
  final previous = <String, SellerLinkSnapshot>{};
  for (final item in items) {
    previous[item.id] = (
      buddyId: item.sellerBuddyId!,
      retailer: await _retailer(db, item.id),
    );
    await _write(
      db,
      syncRepository,
      item.id,
      buddyId: toBuddyId,
      centerId: null,
      retailer: survivor,
      now: now,
    );
  }
  return previous;
}

/// Puts each item in [previous] back on its buddy under its old name, for a
/// merge's undo. Run it after the merged buddies exist again.
Future<void> restoreEquipmentSellerBuddyLinks(
  AppDatabase db,
  SyncRepository syncRepository,
  Map<String, SellerLinkSnapshot> previous, {
  required int now,
}) async {
  for (final entry in previous.entries) {
    await _write(
      db,
      syncRepository,
      entry.key,
      buddyId: entry.value.buddyId,
      centerId: null,
      retailer: entry.value.retailer,
      now: now,
    );
  }
}

Future<Map<String, String>> _buddyNames(
  AppDatabase db,
  Iterable<String> buddyIds,
) async {
  final names = <String, String>{};
  for (final chunk in buddyIds.toSet().slices(_linkChunkSize)) {
    for (final row in await (db.select(
      db.buddies,
    )..where((t) => t.id.isIn(chunk))).get()) {
      names[row.id] = row.name;
    }
  }
  return names;
}

/// The items sold by one of [ids]: buddies, or dive centres.
Future<List<EquipmentData>> _soldBy(
  AppDatabase db,
  Iterable<String> ids, {
  required bool buddies,
}) async {
  final rows = <EquipmentData>[];
  for (final chunk in ids.toSet().slices(_linkChunkSize)) {
    rows.addAll(
      await (db.select(db.equipment)..where(
            (t) => buddies
                ? t.sellerBuddyId.isIn(chunk)
                : t.sellerDiveCenterId.isIn(chunk),
          ))
          .get(),
    );
  }
  return rows;
}

Future<String?> _retailer(AppDatabase db, String equipmentId) async {
  final row =
      await (db.select(db.equipmentAttributes)..where(
            (t) => t.id.equals(
              EquipmentAttribute.curatedId(
                equipmentId,
                EquipmentAttrKeys.retailer,
              ),
            ),
          ))
          .getSingleOrNull();
  return row?.valueText;
}

/// Sets item [equipmentId]'s links and its `retailer` row ([retailer] null
/// or blank removes it, with a tombstone), and stages what changed.
Future<void> _write(
  AppDatabase db,
  SyncRepository syncRepository,
  String equipmentId, {
  required String? buddyId,
  required String? centerId,
  required String? retailer,
  required int now,
}) async {
  await (db.update(db.equipment)..where((t) => t.id.equals(equipmentId))).write(
    EquipmentCompanion(
      sellerBuddyId: Value(buddyId),
      sellerDiveCenterId: Value(centerId),
      updatedAt: Value(now),
    ),
  );
  await syncRepository.markRecordPending(
    entityType: 'equipment',
    recordId: equipmentId,
    localUpdatedAt: now,
  );

  final attrId = EquipmentAttribute.curatedId(
    equipmentId,
    EquipmentAttrKeys.retailer,
  );
  final existing = await (db.select(
    db.equipmentAttributes,
  )..where((t) => t.id.equals(attrId))).getSingleOrNull();
  final name = retailer?.trim();
  if (name == null || name.isEmpty) {
    if (existing == null) return;
    await (db.delete(
      db.equipmentAttributes,
    )..where((t) => t.id.equals(attrId))).go();
    await syncRepository.logDeletion(
      entityType: 'equipmentAttributes',
      recordId: attrId,
    );
    return;
  }
  if (existing?.valueText == name) return;
  await db
      .into(db.equipmentAttributes)
      .insertOnConflictUpdate(
        EquipmentAttributesCompanion(
          id: Value(attrId),
          equipmentId: Value(equipmentId),
          attrKey: const Value(EquipmentAttrKeys.retailer),
          isCustom: const Value(false),
          valueText: Value(name),
          valueNum: const Value(null),
          valueUnit: const Value(null),
          sortOrder: Value(existing?.sortOrder ?? 0),
          createdAt: Value(existing?.createdAt ?? now),
          updatedAt: Value(now),
        ),
      );
  await syncRepository.markRecordPending(
    entityType: 'equipmentAttributes',
    recordId: attrId,
    localUpdatedAt: now,
  );
}
