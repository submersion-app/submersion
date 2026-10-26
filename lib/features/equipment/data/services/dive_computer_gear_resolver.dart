import 'package:drift/drift.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/device_gear_heal.dart';
import 'package:submersion/core/database/dive_computer_gear_identity.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart'
    as domain;

/// Resolves the equipment row that represents a registered dive computer as
/// gear, creating one if the diver does not already have a suitable item.
///
/// Called where a `dive_computers` row is genuinely created. Since #3676 a
/// computer always has its item, so `ensureDeviceGearLinks` also mints one
/// for a computer left without; both share [matchComputerItem] and the
/// re-mint chain, so they never disagree.
class DiveComputerGearResolver {
  DiveComputerGearResolver({SyncRepository? syncRepository})
    : _syncRepository = syncRepository ?? SyncRepository();

  final SyncRepository _syncRepository;
  final _log = LoggerService.forClass(DiveComputerGearResolver);

  AppDatabase get _db => DatabaseService.instance.database;

  /// The equipment id representing [computer], minting one when needed.
  ///
  /// Resolution order, which is the design:
  ///   1. the stored link, when its equipment row still exists
  ///   2. the row already holding the derived id (or the next id in its
  ///      re-mint chain when the derived one was deleted, #3676), which
  ///      survives a rename
  ///   3. exactly one unambiguous identity match ([matchComputerItem]): any
  ///      status except wanted, not owned by another computer
  ///   4. mint at that id
  ///
  /// Returns null and logs on failure. A computer that fails to get a twin is
  /// still a correctly registered computer, so registration must not fail
  /// because gear seeding did.
  Future<String?> resolveGearTwin(domain.DiveComputer computer) async {
    try {
      final stored = computer.equipmentId;
      if (stored != null && stored.isNotEmpty) {
        final existing = await (_db.select(
          _db.equipment,
        )..where((t) => t.id.equals(stored))).getSingleOrNull();
        // Only a computer item is the computer's entry: a link to a mask
        // (an item retyped before #3676 locked the type) goes on to the
        // chain and the matching below, as the device gear heal repairs it.
        if (existing != null && existing.type == EquipmentType.computer.name) {
          return stored;
        }
      }

      // The derived id, or the next id in its chain when a peer deleted it
      // (#3676): a row minted at a tombstoned id would be deleted again.
      final derivedId = await liveGearId(
        _db,
        diveComputerGearId(computer.id),
        computer.id,
        type: EquipmentType.computer.name,
      );

      // The identity match below reads each row's CURRENT text while the id
      // derives from the computer id, so a renamed gear item makes the match
      // miss while the id still collides. Adopt the row holding it rather than
      // letting the insert throw SqliteException(1555).
      final byDerivedId = await (_db.select(
        _db.equipment,
      )..where((t) => t.id.equals(derivedId))).getSingleOrNull();
      if (byDerivedId != null) return derivedId;

      final match = await matchComputerItem(
        _db,
        manufacturer: computer.manufacturer,
        model: computer.model,
        serial: computer.serialNumber,
        diverId: computer.diverId,
      );
      if (match != null) {
        // Adopted through the blank-serial fallback: the item gains the
        // computer's serial, an edit of the diver's row, so it is staged.
        if (await fillBlankItemSerial(_db, match, computer.serialNumber)) {
          await _syncRepository.markRecordPending(
            entityType: 'equipment',
            recordId: match,
            localUpdatedAt: DateTime.now().millisecondsSinceEpoch,
          );
        }
        return match;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      // insertOrIgnore, never upsert. This is a seed: if a row already holds
      // the derived id, it is the twin and it belongs to the user. An upsert
      // would rewrite their name, brand, model and serial from the registry.
      // The step-2 check above normally prevents reaching here with a row
      // present, but the two are not atomic: sync applies equipment rows
      // concurrently, and this database is opened by two isolates, so a peer's
      // twin can land between the check and this write.
      await _db
          .into(_db.equipment)
          .insert(
            mode: InsertMode.insertOrIgnore,
            EquipmentCompanion.insert(
              id: derivedId,
              diverId: Value(computer.diverId),
              name: computer.name,
              type: EquipmentType.computer.name,
              brand: Value(computer.manufacturer),
              model: Value(computer.model),
              serialNumber: Value(computer.serialNumber),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Only mark pending when the insert actually inserted. If it was ignored
      // because a peer's twin or another isolate landed in the race window
      // above, this row is not our write: markRecordPending stamps an HLC on
      // the entity row, so marking it would bump someone else's row to our
      // clock and queue it for export, letting our unchanged copy win a later
      // conflict against a genuine edit from the device that created it.
      // Same `SELECT changes()` idiom the imported-computer heal uses.
      final inserted = await _db
          .customSelect('SELECT changes() AS changed')
          .getSingle();
      if (inserted.read<int>('changed') > 0) {
        await _syncRepository.markRecordPending(
          entityType: 'equipment',
          recordId: derivedId,
          localUpdatedAt: now,
        );
      }
      return derivedId;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to resolve a gear twin for computer ${computer.id}',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
