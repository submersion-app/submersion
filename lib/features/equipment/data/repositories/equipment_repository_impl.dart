import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/dive_sensor_summary_service.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/data/repositories/cylinder_gear_links.dart';
import 'package:submersion/features/safety/data/repositories/incident_repository.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';

class EquipmentRepository {
  /// Injectable seams mirror [SiteRepository]: tests hand in a coordinator
  /// over an in-memory queue, production builds the default. A redirecting
  /// GENERATIVE constructor (not a factory) so existing test fakes that
  /// `extends EquipmentRepository` keep their implicit super() call.
  EquipmentRepository({
    MediaRepository? mediaRepository,
    MediaDeletionCoordinator? mediaDeletionCoordinator,
  }) : this._(mediaRepository ?? MediaRepository(), mediaDeletionCoordinator);

  EquipmentRepository._(
    this._mediaRepository,
    MediaDeletionCoordinator? coordinator,
  ) : _mediaDeletionCoordinator =
          coordinator ??
          MediaDeletionCoordinator(
            mediaRepository: _mediaRepository,
            queue: () => MediaTransferQueueRepository(),
            // No worker kick from the data layer (provider cycles): queued
            // intents drain on the next connectivity event, app start, or
            // any other kick; the Verify Library sweep is the backstop.
          );

  final MediaRepository _mediaRepository;
  final MediaDeletionCoordinator _mediaDeletionCoordinator;
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(EquipmentRepository);

  /// Get all active equipment
  Future<List<EquipmentItem>> getActiveEquipment({String? diverId}) async {
    try {
      final query = _db.select(_db.equipment)
        // status is the user-visible retirement flag; legacy rows can carry
        // status=retired with isActive still true, so filter on both (#636).
        // "Sold" is the same kind of terminal status -- gear that has left
        // the kit -- so it drops out of the active list the same way.
        ..where(
          (t) =>
              t.isActive.equals(true) &
              t.status.isNotValue(EquipmentStatus.retired.name) &
              t.status.isNotValue(EquipmentStatus.sold.name),
        )
        ..orderBy([
          (t) => OrderingTerm.asc(t.type),
          (t) => OrderingTerm.asc(t.name),
        ]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return await _mapRowsWithAttributes(rows);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get active equipment',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get all retired equipment
  Future<List<EquipmentItem>> getRetiredEquipment({String? diverId}) async {
    try {
      // Either retirement marker counts, so items retired before the two
      // fields were kept in sync are still listed (#636). Sold gear is also
      // isActive=false but is not retired -- keep it out of this list so the
      // Sold status stays distinct.
      final query = _db.select(_db.equipment)
        ..where(
          (t) =>
              (t.isActive.equals(false) |
                  t.status.equals(EquipmentStatus.retired.name)) &
              t.status.isNotValue(EquipmentStatus.sold.name),
        )
        ..orderBy([(t) => OrderingTerm.asc(t.name)]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return await _mapRowsWithAttributes(rows);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get retired equipment',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Emits whenever the `equipment` table changes so list providers can
  /// refresh after a sync or any other write.
  ///
  /// Deliberately NOT the assembly template: every clock evaluation hangs
  /// off this stream, and a membership edit changes no schedule or record.
  /// Assembly-aware providers follow
  /// EquipmentComponentRepository.watchComponentEdgeChanges instead.
  Stream<void> watchEquipmentChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.equipment));

  /// Ticks when any item's attributes change (a cell slot, an install
  /// date). `saveAttributes` and a sync pull write only
  /// `equipment_attributes`, which [watchEquipmentChanges] does not see.
  Stream<void> watchAttributeChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.equipmentAttributes));

  /// Get all equipment
  Future<List<EquipmentItem>> getAllEquipment({String? diverId}) async {
    try {
      final query = _db.select(_db.equipment)
        ..orderBy([
          (t) => OrderingTerm.asc(t.type),
          (t) => OrderingTerm.asc(t.name),
        ]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return await _mapRowsWithAttributes(rows);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get all equipment',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get equipment by status
  Future<List<EquipmentItem>> getEquipmentByStatus(
    EquipmentStatus status, {
    String? diverId,
  }) async {
    try {
      // The Retired filter also matches legacy rows that only ever had
      // isActive flipped, so nothing becomes unreachable in the UI (#636) --
      // but not sold gear, which is isActive=false yet has its own status.
      final query = _db.select(_db.equipment)
        ..where(
          (t) => status == EquipmentStatus.retired
              ? (t.status.equals(status.name) | t.isActive.equals(false)) &
                    t.status.isNotValue(EquipmentStatus.sold.name)
              : t.status.equals(status.name),
        )
        ..orderBy([
          (t) => OrderingTerm.asc(t.type),
          (t) => OrderingTerm.asc(t.name),
        ]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return await _mapRowsWithAttributes(rows);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get equipment by status: ${status.name}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get equipment by ID
  Future<EquipmentItem?> getEquipmentById(String id) async {
    try {
      final query = _db.select(_db.equipment)..where((t) => t.id.equals(id));

      final row = await query.getSingleOrNull();
      if (row == null) return null;
      return _mapRowToEquipment(
        row,
        attributes: await getAttributesForEquipment(id),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get equipment by id: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Active items installed in [parentId] (O2 cells, batteries).
  Future<List<EquipmentItem>> getChildEquipment(
    String parentId, {
    bool includeRetired = false,
  }) async {
    final rows =
        await (_db.select(_db.equipment)
              ..where(
                (t) =>
                    t.parentEquipmentId.equals(parentId) &
                    (includeRetired
                        ? const Constant(true)
                        : t.isActive.equals(true)),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .get();
    return _mapRowsWithAttributes(rows);
  }

  /// Get multiple equipment items by IDs
  Future<List<EquipmentItem>> getEquipmentByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    try {
      final query = _db.select(_db.equipment)..where((t) => t.id.isIn(ids));

      final rows = await query.get();
      return await _mapRowsWithAttributes(rows);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get equipment by ids',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Create new equipment
  Future<EquipmentItem> createEquipment(EquipmentItem equipment) async {
    try {
      _log.info('Creating equipment: ${equipment.name}');
      final id = equipment.id.isEmpty ? _uuid.v4() : equipment.id;
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db
          .into(_db.equipment)
          .insert(
            EquipmentCompanion(
              id: Value(id),
              diverId: Value(equipment.diverId),
              name: Value(equipment.name),
              type: Value(equipment.type.name),
              brand: Value(equipment.brand),
              model: Value(equipment.model),
              serialNumber: Value(equipment.serialNumber),
              status: Value(equipment.status.name),
              purchaseDate: Value(
                equipment.purchaseDate?.millisecondsSinceEpoch,
              ),
              purchasePrice: Value(equipment.purchasePrice),
              purchaseCurrency: Value(equipment.purchaseCurrency),
              lastServiceDate: Value(
                equipment.lastServiceDate?.millisecondsSinceEpoch,
              ),
              serviceIntervalDays: Value(equipment.serviceIntervalDays),
              notes: Value(equipment.notes),
              isActive: Value(equipment.isActive),
              customReminderEnabled: Value(equipment.customReminderEnabled),
              customReminderDays: Value(
                equipment.customReminderDays != null
                    ? jsonEncode(equipment.customReminderDays)
                    : null,
              ),
              parentEquipmentId: Value(equipment.parentEquipmentId),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await saveAttributes(id, equipment.attributes);

      await _syncRepository.markRecordPending(
        entityType: 'equipment',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();

      // Seed service clocks for kinds flagged auto-attach (hydro/VIP for
      // tanks, reg service for regulators, ...). Best-effort: the equipment
      // row is already committed and marked pending above, so a failure here
      // must not rethrow and make the caller treat the whole create as failed
      // (which could prompt a retry and duplicate the item). The clocks can be
      // added manually later; log and continue.
      // Each step is caught on its own so one failing does not skip the
      // other, and so the log names the step that actually failed.
      try {
        await ServiceScheduleRepository().autoAttachForEquipment(
          equipmentId: id,
          type: equipment.type,
          diverId: equipment.diverId,
        );
      } catch (e, stackTrace) {
        _log.error(
          'Auto-attach of default service clocks failed for equipment $id; '
          'the equipment was still created',
          error: e,
          stackTrace: stackTrace,
        );
      }
      try {
        await _attachLegacyIntervalClock(id, equipment);
      } catch (e, stackTrace) {
        _log.error(
          'Mirroring the legacy service interval onto the ledger failed for '
          'equipment $id; the equipment was still created',
          error: e,
          stackTrace: stackTrace,
        );
      }

      _log.info('Created equipment with id: $id');
      return equipment.copyWith(
        id: id,
        attributes: await getAttributesForEquipment(id),
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create equipment: ${equipment.name}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Mirror a legacy single-clock interval onto the service ledger.
  ///
  /// The ledger is the only source the due-service surfaces read, and the
  /// legacy `serviceIntervalDays` column has no editor left in the app -- but
  /// UDDF import still carries one, so an imported item would otherwise land
  /// with an interval nothing evaluates. The deterministic
  /// `legacy-svc-<equipment id>` id and General service kind match the v122
  /// and v131 migrations, so an item that arrives by import and the same item
  /// that arrives by migration or sync converge on one clock, not two.
  Future<void> _attachLegacyIntervalClock(
    String id,
    EquipmentItem equipment,
  ) async {
    final intervalDays = equipment.serviceIntervalDays;
    if (intervalDays == null) return;
    final scheduleId = 'legacy-svc-$id';
    final repository = ServiceScheduleRepository();
    final existing = await repository.getSchedulesForEquipment(id);
    if (existing.any((s) => s.id == scheduleId)) return;
    final now = DateTime.now();
    await repository.createSchedule(
      ServiceSchedule(
        id: scheduleId,
        equipmentId: id,
        serviceKindId: 'general-service',
        intervalDays: intervalDays,
        anchorDate: equipment.lastServiceDate,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Update equipment
  Future<void> updateEquipment(EquipmentItem equipment) async {
    try {
      _log.info('Updating equipment: ${equipment.id}');
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(
        _db.equipment,
      )..where((t) => t.id.equals(equipment.id))).write(
        EquipmentCompanion(
          name: Value(equipment.name),
          type: Value(equipment.type.name),
          brand: Value(equipment.brand),
          model: Value(equipment.model),
          serialNumber: Value(equipment.serialNumber),
          status: Value(equipment.status.name),
          purchaseDate: Value(equipment.purchaseDate?.millisecondsSinceEpoch),
          purchasePrice: Value(equipment.purchasePrice),
          purchaseCurrency: Value(equipment.purchaseCurrency),
          lastServiceDate: Value(
            equipment.lastServiceDate?.millisecondsSinceEpoch,
          ),
          serviceIntervalDays: Value(equipment.serviceIntervalDays),
          notes: Value(equipment.notes),
          isActive: Value(equipment.isActive),
          customReminderEnabled: Value(equipment.customReminderEnabled),
          customReminderDays: Value(
            equipment.customReminderDays != null
                ? jsonEncode(equipment.customReminderDays)
                : null,
          ),
          parentEquipmentId: Value(equipment.parentEquipmentId),
          updatedAt: Value(now),
        ),
      );
      await saveAttributes(equipment.id, equipment.attributes);
      await _syncRepository.markRecordPending(
        entityType: 'equipment',
        recordId: equipment.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Updated equipment: ${equipment.id}');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update equipment: ${equipment.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Splits a dying item's attachments (issue #1517): rows only this item
  /// referenced die with it, rows a dive or site still needs survive with
  /// equipment_id cleared and an HLC stamp -- which a silent FK SET NULL
  /// never produces, so without this the unlink would not propagate to the
  /// diver's other devices.
  Future<void> _cascadeMediaForEquipmentDeletion(List<String> ids) async {
    final split = await _mediaRepository.partitionMediaForEquipmentDeletion(
      ids,
    );
    if (split.doomed.isNotEmpty) {
      await _mediaDeletionCoordinator.deleteMediaItems(split.doomed);
    }
    if (split.unlinkIds.isNotEmpty) {
      await _mediaRepository.unlinkMediaFromDeletedEquipment(split.unlinkIds);
    }
  }

  /// Delete equipment. Service schedules, service records, and assembly
  /// component rows are first-class synced children cascade-deleted by
  /// SQLite, but cascades emit no deletion-log entries, so each is
  /// tombstoned explicitly (mirrors EquipmentSetRepository.deleteSet).
  /// Cylinders linked to the item are cleared and staged for sync.
  Future<void> deleteEquipment(String id) async {
    try {
      _log.info('Deleting equipment: $id');
      // Attachments first, outside the transaction: the coordinator's queue
      // writes live in another database, so no cross-DB transaction exists
      // and every step is individually idempotent/tombstoned. Same shape and
      // same reasoning as SiteRepository's media cascade.
      await _cascadeMediaForEquipmentDeletion([id]);
      await _db.transaction(() async {
        final schedules = await (_db.select(
          _db.serviceSchedules,
        )..where((t) => t.equipmentId.equals(id))).get();
        final records = await (_db.select(
          _db.serviceRecords,
        )..where((t) => t.equipmentId.equals(id))).get();
        // Assembly rows in both directions: this item as a parent and as a
        // part (issue #1487). Cascaded away by SQLite, so tombstoned here.
        final componentRows =
            await (_db.select(_db.equipmentComponents)..where(
                  (t) =>
                      t.parentEquipmentId.equals(id) |
                      t.componentEquipmentId.equals(id),
                ))
                .get();
        // Gear check-ins are a synced root of their own, also cascaded
        // away by SQLite (condition phase 3a), so tombstoned here too.
        final observations = await (_db.select(
          _db.equipmentObservations,
        )..where((t) => t.equipmentId.equals(id))).get();
        // Condition findings sync too and go by the same cascade (condition
        // phase 3b); the device-local review marker needs no tombstone.
        final findings = await (_db.select(
          _db.equipmentFindings,
        )..where((t) => t.equipmentId.equals(id))).get();
        // Incidents naming the item stay; their gear link is staged, not
        // just nulled by SQLite.
        await IncidentRepository().unlinkFromDeletedEquipment(id);
        // Registry rows naming the item (as a cylinder or a transmitter)
        // stay; the link is staged, not just nulled.
        await TransmitterRepository().unlinkFromDeletedEquipment(id);
        // Cylinders linked to this item, as their own gear or the regulator
        // they were breathed from: cleared, and each tank staged for sync.
        await clearCylinderGearLinks(_db, _syncRepository, [
          id,
        ], now: DateTime.now().millisecondsSinceEpoch);
        await (_db.delete(_db.equipment)..where((t) => t.id.equals(id))).go();
        for (final s in schedules) {
          await _syncRepository.logDeletion(
            entityType: 'serviceSchedules',
            recordId: s.id,
          );
        }
        for (final r in records) {
          await _syncRepository.logDeletion(
            entityType: 'serviceRecords',
            recordId: r.id,
          );
        }
        for (final c in componentRows) {
          await _syncRepository.logDeletion(
            entityType: 'equipmentComponents',
            recordId: c.id,
          );
        }
        for (final o in observations) {
          await _syncRepository.logDeletion(
            entityType: 'equipmentObservations',
            recordId: o.id,
          );
        }
        for (final f in findings) {
          await _syncRepository.logDeletion(
            entityType: 'equipmentFindings',
            recordId: f.id,
          );
        }
        await _syncRepository.logDeletion(
          entityType: 'equipment',
          recordId: id,
        );
      });
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted equipment: $id');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete equipment: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Mark equipment as serviced
  Future<void> markAsServiced(String id) async {
    try {
      final now = DateTime.now();
      await (_db.update(_db.equipment)..where((t) => t.id.equals(id))).write(
        EquipmentCompanion(
          lastServiceDate: Value(now.millisecondsSinceEpoch),
          updatedAt: Value(now.millisecondsSinceEpoch),
        ),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to mark equipment as serviced: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Retire equipment
  Future<void> retireEquipment(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      // Write BOTH retirement fields: status is the user-visible flag and
      // what the Retired filter and getActiveEquipment read, isActive is
      // the legacy one. Flipping only isActive left items invisible under
      // the Retired filter (#636).
      await (_db.update(_db.equipment)..where((t) => t.id.equals(id))).write(
        EquipmentCompanion(
          isActive: const Value(false),
          status: Value(EquipmentStatus.retired.name),
          updatedAt: Value(now),
        ),
      );
      // Retiring is a real edit to the row, so it has to be staged for sync
      // like create/update -- otherwise the item stays active on every other
      // device, which now also hides it from the active-gear queries.
      await _syncRepository.markRecordPending(
        entityType: 'equipment',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to retire equipment: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Retires [old] and creates its successor in the same parent and slot
  /// (condition phase 4a): same diver, type, name, brand and model, the
  /// `cell_slot` attribute when present, `installed_date` set to [now];
  /// serial, notes and purchase details start empty because it is a new
  /// part. Both rows are staged for sync. Returns the new item.
  ///
  /// The stored row decides, not the caller's copy: an item that no longer
  /// exists or has no parent throws [ArgumentError], one already retired
  /// throws [StateError], and nothing is written. The create and the retire
  /// share one transaction, so a failure in either leaves neither behind
  /// and watchers see the swap as one change, never two active parts in
  /// the slot.
  ///
  /// [now] is only the successor's install date, which the diver may
  /// backdate. The rows' own timestamps stay on the real clock, since the
  /// sync clock must never move backwards.
  Future<EquipmentItem> replaceChild(EquipmentItem old, {DateTime? now}) async {
    final stamp = now ?? DateTime.now();
    return _db.transaction(() async {
      final current = await getEquipmentById(old.id);
      if (current == null) {
        throw ArgumentError.value(old.id, 'old', 'No such equipment');
      }
      final parentId = current.parentEquipmentId;
      if (parentId == null) {
        throw ArgumentError.value(old.id, 'old', 'Not a child part');
      }
      // isFitted, not isActive: a legacy row can be retired or sold with
      // isActive left true, and the repository treats both as gone.
      if (!current.isFitted) {
        throw StateError('Equipment ${old.id} is already retired');
      }
      // The successor is the same kind of part, so its physical spec carries
      // over (a cell's slot, a battery's chemistry and rechargeability).
      // Its install date and purchase record are its own.
      final specKeys = {
        for (final def in EquipmentAttributeCatalog.attributesFor(current.type))
          if (def.group == AttributeGroup.spec &&
              def.key != EquipmentAttrKeys.installedDate)
            def.key,
      };
      final successor = EquipmentItem(
        id: '',
        diverId: current.diverId,
        name: current.name,
        type: current.type,
        brand: current.brand,
        model: current.model,
        parentEquipmentId: parentId,
        attributes: [
          for (final a in current.attributes)
            if (!a.isCustom && specKeys.contains(a.key))
              EquipmentAttribute.curated(
                equipmentId: '',
                key: a.key,
                valueText: a.valueText,
                valueNum: a.valueNum,
              ),
          EquipmentAttribute.curated(
            equipmentId: '',
            key: EquipmentAttrKeys.installedDate,
            valueNum: stamp.millisecondsSinceEpoch.toDouble(),
          ),
        ],
      );
      final created = await createEquipment(successor);
      await retireEquipment(current.id);
      return created;
    });
  }

  /// Reactivate equipment
  Future<void> reactivateEquipment(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      // Clear a terminal status (retired / sold) on the way back in, but
      // leave any other status (needsService, inService, loaned) alone --
      // reactivating is not the same as declaring the item serviceable
      // (#636). Left as-is, a reactivated sold/retired row would stay
      // hidden from the active list, which reads the status too.
      final current = await (_db.select(
        _db.equipment,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      final clearsTerminalStatus =
          current?.status == EquipmentStatus.retired.name ||
          current?.status == EquipmentStatus.sold.name;
      await (_db.update(_db.equipment)..where((t) => t.id.equals(id))).write(
        EquipmentCompanion(
          isActive: const Value(true),
          status: clearsTerminalStatus
              ? Value(EquipmentStatus.active.name)
              : const Value.absent(),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'equipment',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to reactivate equipment: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get all active equipment with service due dates for notification scheduling
  Future<List<EquipmentItem>> getEquipmentWithServiceDates({
    String? diverId,
  }) async {
    try {
      final query = _db.select(_db.equipment)
        ..where((t) => t.isActive.equals(true))
        ..where((t) => t.lastServiceDate.isNotNull())
        ..where((t) => t.serviceIntervalDays.isNotNull());

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return await _mapRowsWithAttributes(rows);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get equipment with service dates',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Search equipment by name, brand, model, or serial number
  Future<List<EquipmentItem>> searchEquipment(
    String query, {
    String? diverId,
  }) async {
    try {
      final searchTerm = '%${query.toLowerCase()}%';
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final variables = [
        Variable.withString(searchTerm),
        Variable.withString(searchTerm),
        Variable.withString(searchTerm),
        Variable.withString(searchTerm),
        if (diverId != null) Variable.withString(diverId),
      ];

      final results = await _db.customSelect('''
        SELECT * FROM equipment
        WHERE (LOWER(name) LIKE ?
           OR LOWER(brand) LIKE ?
           OR LOWER(model) LIKE ?
           OR LOWER(serial_number) LIKE ?)
        $diverFilter
        ORDER BY is_active DESC, type ASC, name ASC
      ''', variables: variables).get();

      final items = results.map((row) {
        return EquipmentItem(
          id: row.data['id'] as String,
          name: row.data['name'] as String,
          type: EquipmentType.values.firstWhere(
            (t) => t.name == row.data['type'],
            orElse: () => EquipmentType.other,
          ),
          brand: row.data['brand'] as String?,
          model: row.data['model'] as String?,
          serialNumber: row.data['serial_number'] as String?,
          status: EquipmentStatus.values.firstWhere(
            (s) => s.name == (row.data['status'] as String? ?? 'active'),
            orElse: () => EquipmentStatus.active,
          ),
          purchaseDate: row.data['purchase_date'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  row.data['purchase_date'] as int,
                )
              : null,
          purchasePrice: (row.data['purchase_price'] as num?)?.toDouble(),
          purchaseCurrency: (row.data['purchase_currency'] as String?) ?? 'USD',
          lastServiceDate: row.data['last_service_date'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  row.data['last_service_date'] as int,
                )
              : null,
          serviceIntervalDays: row.data['service_interval_days'] as int?,
          notes: (row.data['notes'] as String?) ?? '',
          isActive: row.data['is_active'] == 1,
          customReminderEnabled: row.data['custom_reminder_enabled'] == 1
              ? true
              : row.data['custom_reminder_enabled'] == 0
              ? false
              : null,
          customReminderDays: row.data['custom_reminder_days'] != null
              ? (jsonDecode(row.data['custom_reminder_days'] as String)
                        as List<dynamic>)
                    .cast<int>()
              : null,
          parentEquipmentId: row.data['parent_equipment_id'] as String?,
        );
      }).toList();
      final attrsById = await getAttributesForEquipmentIds(
        items.map((i) => i.id).toList(),
      );
      return items
          .map((i) => i.copyWith(attributes: attrsById[i.id] ?? const []))
          .toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to search equipment: $query',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get dive count for equipment item
  /// Deliberately does NOT apply DiveStatsScope. A dive the diver excluded
  /// from statistics still physically happened: it cycled this gear and put
  /// hours on it. Suppressing it here would push a real service interval
  /// later than it should be, a safety-relevant error rather than a cosmetic
  /// one. Do not "fix" this.
  // stats-scope-exempt: gear wear is physical, not descriptive
  Future<int> getDiveCountForEquipment(String equipmentId) async {
    try {
      final result = await _db
          .customSelect(
            '''
        SELECT COUNT(*) as count
        FROM dive_equipment
        WHERE equipment_id = ?
      ''',
            variables: [Variable.withString(equipmentId)],
          )
          .getSingle();

      return result.data['count'] as int? ?? 0;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dive count for equipment: $equipmentId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Every dive this item was on, with what it was exposed to. One SQL union
  /// over the link paths (junction, cylinder, regulator, a transmitter's
  /// registered serials, parent),
  /// left-joined to the sensor summary so profile extremes win over the dive
  /// header when a summary exists.
  ///
  /// [parentEquipmentId] and [installedSince] make a child inherit its
  /// parent's dives from its install date. [rebreatherContact] enables the
  /// diluent and oxygen-supply cylinder path and the CCR fallback (a CCR
  /// dive with no supply cylinder recorded is still 100 percent O2 contact
  /// for the unit).
  ///
  /// Deliberately does NOT apply DiveStatsScope. A dive the diver excluded
  /// from statistics still physically happened: it cycled this gear and put
  /// hours on it. Suppressing it here would push a real service interval
  /// later than it should be, a safety-relevant error rather than a cosmetic
  /// one. Do not "fix" this.
  // stats-scope-exempt: gear wear is physical, not descriptive
  Future<List<EquipmentExposureSample>> getExposureSamplesForEquipment(
    String equipmentId, {
    String? parentEquipmentId,
    DateTime? installedSince,
    bool rebreatherContact = false,
    DateTime? since,
  }) async {
    try {
      final rows = await _db
          .customSelect(
            '''
        SELECT d.id AS dive_id,
               d.updated_at AS updated_at,
               d.dive_date_time AS date_ms,
               -- The first positive length: a manual zero runtime beside
               -- a real bottom time is no figure, and must not count the
               -- dive as zero hours (or subtract any).
               CASE
                 WHEN d.runtime > 0 THEN d.runtime
                 WHEN d.bottom_time > 0 THEN d.bottom_time
                 ELSE 0
               END AS duration_sec,
               d.dive_mode AS dive_mode,
               d.water_type AS water_type,
               COALESCE(s.max_depth, d.max_depth) AS max_depth,
               COALESCE(s.min_temperature, d.water_temp) AS min_temp,
               MAX(je.contact_o2) AS contact_o2
        FROM (
          SELECT dive_id, NULL AS contact_o2, 0 AS via_parent
            FROM dive_equipment WHERE equipment_id = ?1
          UNION ALL
          SELECT dive_id, o2_percent, 0 FROM dive_tanks
            WHERE equipment_id = ?1 OR regulator_equipment_id = ?1
          UNION ALL
          SELECT de.dive_id, t.o2_percent, 0
            FROM dive_equipment de
            JOIN dive_tanks t ON t.dive_id = de.dive_id
              AND t.tank_role IN ('diluent', 'oxygenSupply')
            WHERE de.equipment_id = ?1 AND ?5 = 1
          UNION ALL
          -- A transmitter item: the tanks that carried a serial the
          -- registry assigns to it. That link writes no dive_equipment
          -- row. Only the entry's diver, and a blank or all-zero serial
          -- (normalizeTransmitterSerial) names no transmitter.
          SELECT t.dive_id, NULL, 0
            FROM transmitters r
            JOIN dive_tanks t
              ON TRIM(t.transmitter_serial) = TRIM(r.transmitter_serial)
            JOIN dives rd ON rd.id = t.dive_id
            WHERE r.transmitter_equipment_id = ?1
              AND LTRIM(TRIM(r.transmitter_serial), '0') <> ''
              AND (r.diver_id IS NULL OR rd.diver_id IS NULL
                OR rd.diver_id = r.diver_id)
          UNION ALL
          SELECT dive_id, NULL, 1 FROM dive_equipment WHERE equipment_id = ?2
          UNION ALL
          SELECT dive_id, o2_percent, 1 FROM dive_tanks
            WHERE equipment_id = ?2 OR regulator_equipment_id = ?2
          UNION ALL
          SELECT de.dive_id, t.o2_percent, 1
            FROM dive_equipment de
            JOIN dive_tanks t ON t.dive_id = de.dive_id
              AND t.tank_role IN ('diluent', 'oxygenSupply')
            WHERE de.equipment_id = ?2 AND ?5 = 1
        ) je
        JOIN dives d ON d.id = je.dive_id
        LEFT JOIN dive_sensor_summaries s ON s.dive_id = d.id
          AND s.source_updated_at = d.updated_at
          AND s.engine_version >= ?6
        WHERE (je.via_parent = 0 OR ?3 IS NULL OR d.dive_date_time >= ?3)
          AND (?4 IS NULL OR d.dive_date_time >= ?4)
        GROUP BY d.id
        ORDER BY d.dive_date_time
      ''',
            variables: [
              Variable.withString(equipmentId),
              // An empty string never matches an id, so "no parent" needs
              // no second query shape.
              Variable.withString(parentEquipmentId ?? ''),
              Variable(installedSince?.millisecondsSinceEpoch),
              Variable(since?.millisecondsSinceEpoch),
              Variable.withInt(rebreatherContact ? 1 : 0),
              // Only a current summary: one built from an older version of
              // the dive, or by an older algorithm, is stale until the
              // sweep rebuilds it, and the header is the truth till then.
              Variable.withInt(DiveSensorSummaryService.version),
            ],
          )
          .get();
      return rows.map((r) {
        final mode = DiveMode.values.firstWhere(
          (m) => m.name == r.data['dive_mode'],
          orElse: () => DiveMode.oc,
        );
        final waterName = r.data['water_type'] as String?;
        final water = waterName == null
            ? null
            : WaterType.values.where((w) => w.name == waterName).firstOrNull;
        final o2Percent = (r.data['contact_o2'] as num?)?.toDouble();
        final contact = o2Percent != null
            ? o2Percent / 100.0
            : (rebreatherContact && mode == DiveMode.ccr ? 1.0 : null);
        return EquipmentExposureSample(
          diveId: r.data['dive_id'] as String,
          updatedAt: (r.data['updated_at'] as num).toInt(),
          // dives.dive_date_time is epoch millis with wall-clock-as-UTC
          // semantics (see dive_filter_sql.dart); decode with isUtc: true
          // like the other dive-date mappers so the engine's
          // date.isAfter(anchor) usage comparison is not shifted by the
          // local offset around day boundaries.
          date: DateTime.fromMillisecondsSinceEpoch(
            r.data['date_ms'] as int,
            isUtc: true,
          ),
          durationSeconds: (r.data['duration_sec'] as num).toInt(),
          diveMode: mode,
          maxDepth: (r.data['max_depth'] as num?)?.toDouble(),
          minTemperature: (r.data['min_temp'] as num?)?.toDouble(),
          waterType: water,
          contactO2Fraction: contact,
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get exposure samples for equipment: $equipmentId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// [item]'s exposure, wired one way for every surface that reads it: the
  /// service clocks, the reminder scheduler, the condition engine and the
  /// item page's exposure card and trend. Samples come from the item's own
  /// dives plus, for a part, its parent's dives from its install date; a
  /// part no longer fitted stops at the install date of the next part of
  /// its type in the same slot, so a replaced cell's history does not keep
  /// growing with its successor's dives. [fittedChildren] leaves out parts
  /// retired or sold (even with isActive left true), which must not switch
  /// the parent's battery cycles off.
  ///
  /// [siblings] is the active gear list when the caller already has it, so
  /// the parent and children lookups cost no query per item.
  Future<
    ({
      EquipmentItem? parent,
      List<EquipmentItem> fittedChildren,
      bool isRebreather,
      List<EquipmentExposureSample> samples,
    })
  >
  getItemExposure(EquipmentItem item, {List<EquipmentItem>? siblings}) async {
    final parentId = item.parentEquipmentId;
    final parent = parentId == null
        ? null
        : siblings?.where((s) => s.id == parentId).firstOrNull ??
              await getEquipmentById(parentId);
    final fittedChildren = [
      for (final c
          in siblings != null
              ? siblings.where((s) => s.parentEquipmentId == item.id)
              : await getChildEquipment(item.id))
        if (c.isFitted) c,
    ];
    final isRebreather =
        item.type == EquipmentType.rebreather ||
        parent?.type == EquipmentType.rebreather;
    final samples = await getExposureSamplesForEquipment(
      item.id,
      parentEquipmentId: parentId,
      installedSince: item.parentDivesFrom,
      rebreatherContact: isRebreather,
    );
    // Only a part no longer fitted can have a successor.
    final until = parentId == null || item.isFitted
        ? null
        : successorStart(
            item,
            await getChildEquipment(parentId, includeRetired: true),
          );
    return (
      parent: parent,
      fittedChildren: fittedChildren,
      isRebreather: isRebreather,
      samples: until == null
          ? samples
          : [
              for (final s in samples)
                if (s.date.isBefore(until)) s,
            ],
    );
  }

  /// When the next part of [item]'s type went into the same slot after it,
  /// or null when none has (or when a cell carries no slot to match).
  /// Batteries carry no slot, so the next battery of the same parent is
  /// the successor.
  static DateTime? successorStart(
    EquipmentItem item,
    List<EquipmentItem> siblings,
  ) {
    final from = item.parentDivesFrom;
    if (from == null) return null;
    final slot = item.cellSlot;
    // A slot is what says which later part took this one's place. Only
    // batteries succeed without one; a slotless cell has no successor.
    if (slot == null && item.type != EquipmentType.battery) return null;
    DateTime? earliest;
    for (final s in siblings) {
      if (s.id == item.id || s.type != item.type) continue;
      if (s.cellSlot != slot) continue;
      final start = s.parentDivesFrom;
      if (start == null || !start.isAfter(from)) continue;
      if (earliest == null || start.isBefore(earliest)) earliest = start;
    }
    return earliest;
  }

  /// The regulator last paired with a cylinder preset, for prefilling the
  /// tank editor: the newest dive whose tank of that preset names one.
  /// Operational, not descriptive: an excluded dive still tells us which
  /// regulator the diver hangs on that cylinder.
  // stats-scope-exempt: editor prefill, not a statistic
  Future<String?> getLastRegulatorForPreset(String presetName) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT t.regulator_equipment_id AS reg
      FROM dive_tanks t
      JOIN dives d ON d.id = t.dive_id
      WHERE t.preset_name = ?1 AND t.regulator_equipment_id IS NOT NULL
      ORDER BY d.dive_date_time DESC
      LIMIT 1
    ''',
          variables: [Variable.withString(presetName)],
        )
        .get();
    return rows.isEmpty ? null : rows.first.data['reg'] as String?;
  }

  /// Get trip count for equipment item (unique trips from dives using this equipment)
  /// Deliberately does NOT apply DiveStatsScope. A dive the diver excluded
  /// from statistics still physically happened: it cycled this gear and put
  /// hours on it. Suppressing it here would push a real service interval
  /// later than it should be, a safety-relevant error rather than a cosmetic
  /// one. Do not "fix" this.
  // stats-scope-exempt: gear wear is physical, not descriptive
  Future<int> getTripCountForEquipment(String equipmentId) async {
    try {
      final result = await _db
          .customSelect(
            '''
        SELECT COUNT(DISTINCT d.trip_id) as count
        FROM dive_equipment de
        INNER JOIN dives d ON de.dive_id = d.id
        WHERE de.equipment_id = ? AND d.trip_id IS NOT NULL
      ''',
            variables: [Variable.withString(equipmentId)],
          )
          .getSingle();

      return result.data['count'] as int? ?? 0;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get trip count for equipment: $equipmentId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get trip IDs for equipment item
  // stats-scope-exempt: gear usage is physical, not descriptive
  Future<List<String>> getTripIdsForEquipment(String equipmentId) async {
    try {
      final result = await _db
          .customSelect(
            '''
        SELECT DISTINCT d.trip_id
        FROM dive_equipment de
        INNER JOIN dives d ON de.dive_id = d.id
        WHERE de.equipment_id = ? AND d.trip_id IS NOT NULL
        ORDER BY d.dive_date_time DESC
      ''',
            variables: [Variable.withString(equipmentId)],
          )
          .get();

      return result.map((row) => row.data['trip_id'] as String).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get trip IDs for equipment: $equipmentId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  EquipmentItem _mapRowToEquipment(
    EquipmentData row, {
    List<EquipmentAttribute> attributes = const [],
  }) {
    return EquipmentItem(
      id: row.id,
      diverId: row.diverId,
      name: row.name,
      type: EquipmentType.values.firstWhere(
        (t) => t.name == row.type,
        orElse: () => EquipmentType.other,
      ),
      brand: row.brand,
      model: row.model,
      serialNumber: row.serialNumber,
      status: EquipmentStatus.values.firstWhere(
        (s) => s.name == row.status,
        orElse: () => EquipmentStatus.active,
      ),
      purchaseDate: row.purchaseDate != null
          ? DateTime.fromMillisecondsSinceEpoch(row.purchaseDate!)
          : null,
      purchasePrice: row.purchasePrice,
      purchaseCurrency: row.purchaseCurrency,
      lastServiceDate: row.lastServiceDate != null
          ? DateTime.fromMillisecondsSinceEpoch(row.lastServiceDate!)
          : null,
      serviceIntervalDays: row.serviceIntervalDays,
      notes: row.notes,
      isActive: row.isActive,
      attributes: attributes,
      customReminderEnabled: row.customReminderEnabled,
      customReminderDays: row.customReminderDays != null
          ? (jsonDecode(row.customReminderDays!) as List<dynamic>).cast<int>()
          : null,
      parentEquipmentId: row.parentEquipmentId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    );
  }

  /// Maps rows to entities with attributes hydrated in ONE batched query
  /// (list reads must not pay a per-item join).
  Future<List<EquipmentItem>> _mapRowsWithAttributes(
    List<EquipmentData> rows,
  ) async {
    final attrsById = await getAttributesForEquipmentIds(
      rows.map((r) => r.id).toList(),
    );
    return rows
        .map(
          (row) => _mapRowToEquipment(
            row,
            attributes: attrsById[row.id] ?? const [],
          ),
        )
        .toList();
  }

  EquipmentAttribute _mapAttributeRow(EquipmentAttributeRow row) =>
      EquipmentAttribute(
        id: row.id,
        equipmentId: row.equipmentId,
        key: row.attrKey,
        isCustom: row.isCustom,
        valueText: row.valueText,
        valueNum: row.valueNum,
        sortOrder: row.sortOrder,
      );

  Future<List<EquipmentAttribute>> getAttributesForEquipment(
    String equipmentId,
  ) async {
    final rows =
        await (_db.select(_db.equipmentAttributes)
              ..where((t) => t.equipmentId.equals(equipmentId))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    return rows.map(_mapAttributeRow).toList();
  }

  Future<Map<String, List<EquipmentAttribute>>> getAttributesForEquipmentIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const {};
    final rows =
        await (_db.select(_db.equipmentAttributes)
              ..where((t) => t.equipmentId.isIn(ids))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    final byEquipment = <String, List<EquipmentAttribute>>{};
    for (final row in rows) {
      byEquipment
          .putIfAbsent(row.equipmentId, () => [])
          .add(_mapAttributeRow(row));
    }
    return byEquipment;
  }

  /// Writes the desired end state of [equipmentId]'s attributes: inserts and
  /// updates changed rows, deletes (with a tombstone) rows no longer present.
  /// Curated ids are normalized to the deterministic form here so callers
  /// building attributes before the equipment id exists still converge.
  Future<void> saveAttributes(
    String equipmentId,
    List<EquipmentAttribute> desired,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final normalized = desired.where((a) => a.hasValue).map((a) {
      if (a.isCustom) {
        return a.copyWith(
          equipmentId: equipmentId,
          id: a.id.isNotEmpty ? a.id : _uuid.v4(),
        );
      }
      return a.copyWith(
        equipmentId: equipmentId,
        id: EquipmentAttribute.curatedId(equipmentId, a.key),
      );
    }).toList();

    final existingRows = await (_db.select(
      _db.equipmentAttributes,
    )..where((t) => t.equipmentId.equals(equipmentId))).get();
    final existingById = {for (final r in existingRows) r.id: r};
    final desiredIds = normalized.map((a) => a.id).toSet();
    final pendingIds = <String>[];

    await _db.transaction(() async {
      for (final row in existingRows) {
        if (desiredIds.contains(row.id)) continue;
        await (_db.delete(
          _db.equipmentAttributes,
        )..where((t) => t.id.equals(row.id))).go();
        await _syncRepository.logDeletion(
          entityType: 'equipmentAttributes',
          recordId: row.id,
        );
      }

      for (final attr in normalized) {
        final existing = existingById[attr.id];
        final unchanged =
            existing != null &&
            existing.attrKey == attr.key &&
            existing.valueText == attr.valueText &&
            existing.valueNum == attr.valueNum &&
            existing.sortOrder == attr.sortOrder;
        if (unchanged) continue;

        await _db
            .into(_db.equipmentAttributes)
            .insertOnConflictUpdate(
              EquipmentAttributesCompanion(
                id: Value(attr.id),
                equipmentId: Value(equipmentId),
                attrKey: Value(attr.key),
                isCustom: Value(attr.isCustom),
                valueText: Value(attr.valueText),
                valueNum: Value(attr.valueNum),
                sortOrder: Value(attr.sortOrder),
                createdAt: Value(existing?.createdAt ?? now),
                updatedAt: Value(now),
              ),
            );
        pendingIds.add(attr.id);
      }
    });

    for (final id in pendingIds) {
      await _syncRepository.markRecordPending(
        entityType: 'equipmentAttributes',
        recordId: id,
        localUpdatedAt: now,
      );
    }
  }
}
