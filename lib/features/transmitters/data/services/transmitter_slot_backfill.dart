import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_computer/data/services/parsed_tank_resolver.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_batch_service.dart';
import 'package:submersion/features/dive_import/data/services/dive_resync_orchestrator.dart';
import 'package:submersion/features/dive_import/domain/dive_resync_failure.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_slot_backfill_memo.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';

export 'package:submersion/features/dive_computer/data/services/reparse_batch_service.dart'
    show RawDiveParseFn;

/// Fills `dive_tanks.transmitter_slot` for dives stored before slots were
/// kept (issue #4347): downloads from their raw bytes, Shearwater Cloud
/// imports from the original file the app stored. Writes only the slot, and
/// for a file import a serial the row lacks, staged for sync.
class TransmitterSlotBackfill {
  TransmitterSlotBackfill({
    required RawDiveParseFn parseRaw,
    DiveResyncOrchestrator? files,
    TransmitterSlotBackfillMemo? memo,
    AppDatabase? db,
  }) : _parseRaw = parseRaw,
       _files = files,
       _memo = memo ?? SharedPrefsSlotBackfillMemo(),
       _database = db;

  static final _log = LoggerService.forClass(TransmitterSlotBackfill);
  static const _fileFormats = [ImportFormat.uddf, ImportFormat.shearwaterDb];

  final RawDiveParseFn _parseRaw;
  final DiveResyncOrchestrator? _files;
  final TransmitterSlotBackfillMemo _memo;
  final AppDatabase? _database;

  AppDatabase get _db => _database ?? DatabaseService.instance.database;

  /// Every read keeps to one diver's dives when a diver is given: a
  /// transmitter is one diver's, and another's dives are not its to parse.
  static const _ofDiver = '(? IS NULL OR d.diver_id = ?)';
  static List<Variable<String>> _diverVars(String? diverId) => [
    Variable<String>(diverId),
    Variable<String>(diverId),
  ];

  /// Computers with a dive (of [diverId], when given) whose primary source
  /// is a stored Shearwater Cloud database. Its tanks gain serials from the
  /// file, which no other computer's downloads would bring into scope.
  Future<Set<String>> dbImportComputers({String? diverId}) async {
    final rows = await _db
        .customSelect(
          'SELECT DISTINCT d.computer_id AS c FROM dives d '
          'JOIN dive_data_sources s ON s.dive_id = d.id AND s.is_primary = 1 '
          'WHERE s.imported_file_id IS NOT NULL '
          'AND s.source_file_format = ? AND d.computer_id IS NOT NULL '
          'AND $_ofDiver',
          variables: [
            Variable<String>(ImportFormat.shearwaterDb.name),
            ..._diverVars(diverId),
          ],
          readsFrom: {_db.dives, _db.diveDataSources},
        )
        .get();
    return {for (final r in rows) r.read<String>('c')};
  }

  /// How many sources and dives on [computerIds] [run] would parse, so a
  /// caller shows progress only when there is work.
  Future<int> pendingCount(Set<String> computerIds, {String? diverId}) async {
    final (:sources, :dives) = await _pending(computerIds, diverId);
    return sources.length + dives.length;
  }

  Future<({List<String> sources, List<String> dives})> _pending(
    Set<String> computerIds,
    String? diverId,
  ) async {
    if (computerIds.isEmpty) return (sources: <String>[], dives: <String>[]);
    final done = await _memo.load();
    return (
      sources: [
        for (final id in await _rawSourceIds(computerIds, diverId))
          if (!done.contains('raw:$id')) id,
      ],
      dives: [
        for (final id in await _fileDiveIds(computerIds, diverId))
          if (!done.contains('file:$id')) id,
      ],
    );
  }

  /// Backfills the dives on [computerIds], only [diverId]'s when given.
  /// Returns the tanks written.
  Future<int> run(
    Set<String> computerIds, {
    void Function(int done, int total)? onProgress,
    String? diverId,
  }) async {
    final (:sources, :dives) = await _pending(computerIds, diverId);
    final total = sources.length + dives.length;
    if (total == 0) return 0;
    final sync = SyncRepository(database: _db);
    final finished = <String>[];
    var written = 0;
    var step = 0;

    var parserMissing = false;
    for (final id in sources) {
      if (!parserMissing) {
        try {
          written += await _fromRaw(id, sync);
          finished.add('raw:$id');
        } on MissingPluginException {
          parserMissing = true;
        } on PlatformException catch (e) {
          if (e.code == 'UNSUPPORTED' || e.code == 'channel-error') {
            parserMissing = true;
          } else {
            finished.add('raw:$id');
          }
        } catch (e, stackTrace) {
          _log.warning(
            'Slot backfill could not parse source $id',
            error: e,
            stackTrace: stackTrace,
          );
          finished.add('raw:$id');
        }
      }
      onProgress?.call(++step, total);
    }

    final files = _files ?? DiveResyncOrchestrator(db: _db);
    final payloads = <String, ImportPayload>{};
    for (final id in dives) {
      try {
        final count = await _fromFile(id, files, payloads, sync);
        // Null: the stored file has not reached this device yet; try again
        // on a later run.
        if (count != null) {
          written += count;
          finished.add('file:$id');
        }
      } on MissingPluginException {
        // A `.db` file needs the native parser; leave it for a device that
        // has one.
      } on PlatformException catch (e) {
        // The same missing parser, as the raw pass sees it on the web.
        if (e.code != 'UNSUPPORTED' && e.code != 'channel-error') {
          _log.warning('Slot backfill could not read the file of dive $id');
          finished.add('file:$id');
        }
      } catch (e, stackTrace) {
        _log.warning(
          'Slot backfill could not read the file of dive $id',
          error: e,
          stackTrace: stackTrace,
        );
        finished.add('file:$id');
      }
      onProgress?.call(++step, total);
    }

    await _memo.add(finished);
    if (written > 0) SyncEventBus.notifyLocalChange();
    return written;
  }

  /// Sources with raw bytes on [computerIds] whose dive has a tank with a
  /// serial and no slot.
  Future<List<String>> _rawSourceIds(
    Set<String> computerIds,
    String? diverId,
  ) async {
    final rows = await _db
        .customSelect(
          'SELECT DISTINCT s.id AS id FROM dive_data_sources s '
          'JOIN dives d ON d.id = s.dive_id '
          'JOIN dive_tanks dt ON dt.dive_id = s.dive_id '
          'WHERE s.raw_data IS NOT NULL '
          'AND s.computer_id IN (${_marks(computerIds.length)}) '
          'AND (dt.computer_id IS NULL OR dt.computer_id = s.computer_id) '
          'AND dt.transmitter_serial IS NOT NULL '
          'AND dt.transmitter_slot IS NULL '
          'AND $_ofDiver',
          variables: [
            for (final c in computerIds) Variable<String>(c),
            ..._diverVars(diverId),
          ],
          readsFrom: {_db.diveDataSources, _db.dives, _db.diveTanks},
        )
        .get();
    return [for (final r in rows) r.read<String>('id')];
  }

  /// Dives on [computerIds] whose primary source is a stored UDDF or
  /// Shearwater Cloud file and that have a slot-less tank with a series.
  Future<List<String>> _fileDiveIds(
    Set<String> computerIds,
    String? diverId,
  ) async {
    final rows = await _db
        .customSelect(
          'SELECT DISTINCT d.id AS id FROM dives d '
          'JOIN dive_data_sources s ON s.dive_id = d.id AND s.is_primary = 1 '
          'JOIN dive_tanks dt ON dt.dive_id = d.id '
          'WHERE s.imported_file_id IS NOT NULL '
          'AND s.source_file_format IN (${_marks(_fileFormats.length)}) '
          'AND COALESCE(dt.computer_id, d.computer_id) '
          'IN (${_marks(computerIds.length)}) '
          'AND dt.transmitter_slot IS NULL '
          'AND EXISTS (SELECT 1 FROM tank_pressure_series ps '
          'WHERE ps.tank_id = dt.id) '
          'AND $_ofDiver',
          variables: [
            for (final f in _fileFormats) Variable<String>(f.name),
            for (final c in computerIds) Variable<String>(c),
            ..._diverVars(diverId),
          ],
          readsFrom: {
            _db.dives,
            _db.diveDataSources,
            _db.diveTanks,
            _db.tankPressureSeries,
          },
        )
        .get();
    return [for (final r in rows) r.read<String>('id')];
  }

  Future<int> _fromRaw(String sourceId, SyncRepository sync) async {
    final source = await (_db.select(
      _db.diveDataSources,
    )..where((s) => s.id.equals(sourceId))).getSingleOrNull();
    final vendor = source?.descriptorVendor;
    final product = source?.descriptorProduct;
    final model = source?.descriptorModel;
    final raw = source?.rawData;
    if (source == null ||
        vendor == null ||
        product == null ||
        model == null ||
        raw == null) {
      return 0;
    }
    final parsed = resolveParsedTanks(
      await _parseRaw(vendor, product, model, raw),
      vendor: vendor,
    );
    final rows =
        await (_db.select(_db.diveTanks)..where(
              (t) =>
                  t.diveId.equals(source.diveId) &
                  t.transmitterSlot.isNull() &
                  t.transmitterSerial.isNotNull(),
            ))
            .get();
    var written = 0;
    for (final row in rows) {
      if (row.computerId != null && row.computerId != source.computerId) {
        continue;
      }
      final index = row.sourceTankIndex ?? row.tankOrder;
      final tank = parsed.firstWhereOrNull((t) => t.index == index);
      final slot = tank?.transmitterSlot;
      if (slot == null ||
          normalizeTransmitterSerial(tank!.transmitterSerial) !=
              normalizeTransmitterSerial(row.transmitterSerial)) {
        continue;
      }
      await _write(row.id, sync, slot: slot);
      written++;
    }
    return written;
  }

  Future<int?> _fromFile(
    String diveId,
    DiveResyncOrchestrator files,
    Map<String, ImportPayload> payloads,
    SyncRepository sync,
  ) async {
    final found = await files.sourceEntryFor(diveId, payloads: payloads);
    if (found.failure == DiveResyncFailure.storedFileMissing) return null;
    final tanksData =
        (found.entry?['tanks'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    // Tanks a file import wrote share tank_order 0, so the order they were
    // written in pairs them with the file's (as DiveReimportService does).
    final rows =
        await (_db.select(_db.diveTanks)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([
                (t) => OrderingTerm.asc(t.tankOrder),
                (t) => OrderingTerm.asc(_db.diveTanks.rowId),
              ]))
            .get();
    if (tanksData.isEmpty || rows.length != tanksData.length) return 0;
    // An edit can reorder the rows or swap one for a hand-added tank while
    // the count still matches, so each pair must show the same readings.
    for (var i = 0; i < rows.length; i++) {
      if (!_sameReadings(rows[i], tanksData[i])) return 0;
    }
    var written = 0;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final slot = tanksData[i]['transmitterSlot'] as int?;
      final serial = normalizeTransmitterSerial(
        tanksData[i]['transmitterSerial'] as String?,
      );
      final fillsSlot = row.transmitterSlot == null && slot != null;
      final fillsSerial =
          normalizeTransmitterSerial(row.transmitterSerial) == null &&
          serial != null;
      if (!fillsSlot && !fillsSerial) continue;
      await _write(
        row.id,
        sync,
        slot: fillsSlot ? slot : null,
        serial: fillsSerial ? serial : null,
      );
      written++;
    }
    return written;
  }

  /// Whether stored [row] and the file's [tank] report the same start and
  /// end pressure (within 1 bar), with at least one of the two present on
  /// both sides.
  static bool _sameReadings(DiveTank row, Map<String, dynamic> tank) {
    var compared = 0;
    for (final (stored, filed) in [
      (row.startPressure, tank['startPressure']),
      (row.endPressure, tank['endPressure']),
    ]) {
      if (stored == null || filed is! num) continue;
      if ((stored - filed.toDouble()).abs() > 1.0) return false;
      compared++;
    }
    return compared > 0;
  }

  Future<void> _write(
    String tankId,
    SyncRepository sync, {
    int? slot,
    String? serial,
  }) async {
    await (_db.update(_db.diveTanks)..where((t) => t.id.equals(tankId))).write(
      DiveTanksCompanion(
        transmitterSlot: slot != null ? Value(slot) : const Value.absent(),
        transmitterSerial: serial != null
            ? Value(serial)
            : const Value.absent(),
        // A fresh clock, so a peer's older copy cannot take the value back
        // (#2644).
        hlc: Value(await sync.issueRowClock()),
      ),
    );
    await sync.markRecordPending(
      entityType: 'diveTanks',
      recordId: tankId,
      localUpdatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static String _marks(int n) => List.filled(n, '?').join(', ');
}
