import 'package:drift/drift.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_computer_gear_identity.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart'
    as domain;

/// Resolves the equipment row that represents a registered dive computer as
/// gear, creating one if the diver does not already have a suitable item.
///
/// Called only where a `dive_computers` row is genuinely created. That single
/// rule is what makes deleting a gear twin permanent: nothing else mints, so a
/// cleared `dive_computers.equipment_id` stays cleared.
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
  ///   2. the row already holding the derived id, which survives a rename
  ///   3. exactly one unambiguous identity match among active computer gear
  ///   4. mint at the derived id
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
        if (existing != null) return stored;
      }

      final derivedId = diveComputerGearId(computer.id);

      // The identity match below reads each row's CURRENT text while the id
      // derives from the computer id, so a renamed gear item makes the match
      // miss while the id still collides. Adopt the row holding it rather than
      // letting the insert throw SqliteException(1555).
      final byDerivedId = await (_db.select(
        _db.equipment,
      )..where((t) => t.id.equals(derivedId))).getSingleOrNull();
      if (byDerivedId != null) return derivedId;

      final rows =
          await (_db.select(_db.equipment)
                ..where((t) => t.type.equals(EquipmentType.computer.name))
                ..where((t) => t.isActive.equals(true)))
              .get();
      final match = matchGearTwin(
        manufacturer: computer.manufacturer,
        model: computer.model,
        serialNumber: computer.serialNumber,
        diverId: computer.diverId,
        candidates: rows.map(
          (r) => GearTwinCandidate(
            id: r.id,
            diverId: r.diverId,
            brand: r.brand,
            model: r.model,
            serialNumber: r.serialNumber,
          ),
        ),
      );
      if (match != null) return match.id;

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
