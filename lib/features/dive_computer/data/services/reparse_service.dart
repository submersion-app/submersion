import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_computer/data/services/libdc_dive_mode.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart'
    as codec;
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart'
    show TankPressureSample;
import 'package:submersion/features/dive_log/domain/services/bottom_time_calculator.dart';
import 'package:submersion/features/dive_log/domain/services/source_ownership.dart';
import 'package:submersion/features/dive_computer/data/services/parsed_tank_resolver.dart';
import 'package:submersion/features/dive_computer/data/services/dive_parser.dart';
import 'package:submersion/features/dive_computer/data/services/transmitter_registry_matcher.dart';
import 'package:submersion/features/dive_log/domain/services/tank_pressure_series.dart';
import 'package:submersion/features/dive_computer/data/services/libdc_sample_units.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';

/// Service responsible for applying re-parsed dive computer data back to the
/// database while respecting the computer-authored vs user-authored field
/// boundary.
///
/// This is the single point where the allowlist is enforced. Both the
/// `replaceSource` path and the manual re-parse path call through here.
class ReparseService {
  final AppDatabase db;
  final _uuid = const Uuid();

  /// The diver's preference for reading cylinder end pressure at the moment of
  /// surfacing rather than at the end of the recording (issue #1092). Reparse
  /// is how an already-imported dive picks the rule up, so it has to agree
  /// with the live download path.
  final bool trimTankPressureAtSurfacing;

  /// The diver's transmitter registry, read per re-parsed dive so an entry
  /// saved a moment ago applies. Null (or a failing load) means no mapping.
  final TransmitterMatcherLoader? _transmitterMatcherLoader;

  ReparseService({
    required this.db,
    this.trimTankPressureAtSurfacing = true,
    TransmitterMatcherLoader? transmitterMatcherLoader,
    ProfileSeriesRepository? profileSeries,
    TankPressureSeriesRepository? tankSeries,
  }) : _transmitterMatcherLoader = transmitterMatcherLoader,
       _sync = SyncRepository(database: db),
       _profileSeries =
           profileSeries ??
           ProfileSeriesRepository(
             database: db,
             syncRepository: SyncRepository(database: db),
           ),
       _tankSeries =
           tankSeries ??
           TankPressureSeriesRepository(
             database: db,
             syncRepository: SyncRepository(database: db),
           );

  final SyncRepository _sync;
  final ProfileSeriesRepository _profileSeries;
  final TankPressureSeriesRepository _tankSeries;

  Future<TransmitterMatcher> _loadMatcher() async {
    final loader = _transmitterMatcherLoader;
    if (loader == null) return const TransmitterMatcher.empty();
    try {
      return await loader();
    } catch (_) {
      return const TransmitterMatcher.empty();
    }
  }

  /// Apply a freshly parsed dive to the database, updating only
  /// computer-authored fields and preserving user-authored fields.
  ///
  /// [rawData] and [rawFingerprint] use `Value.absent()` when null to avoid
  /// overwriting existing blobs during the re-parse path.
  ///
  /// Returns whether the dive's profile strand was left untouched because
  /// this source does not own it -- see [sourceOwnsProfileStrand].
  Future<({bool profilePreserved})> applyParsedUpdate({
    required String diveId,
    required String sourceRowId,
    required pigeon.ParsedDive parsed,
    required String? descriptorVendor,
    required String? descriptorProduct,
    required int? descriptorModel,
    required String? libdivecomputerVersion,
    Uint8List? rawData,
    Uint8List? rawFingerprint,
  }) async {
    final outcome = await db.transaction(() async {
      final now = DateTime.now();

      // ------------------------------------------------------------------
      // 1. Update DiveDataSources snapshot fields
      // ------------------------------------------------------------------
      await (_updateSourceRow(
        sourceRowId: sourceRowId,
        parsed: parsed,
        descriptorVendor: descriptorVendor,
        descriptorProduct: descriptorProduct,
        descriptorModel: descriptorModel,
        libdivecomputerVersion: libdivecomputerVersion,
        rawData: rawData,
        rawFingerprint: rawFingerprint,
        now: now,
      ));

      // ------------------------------------------------------------------
      // 2. Check isPrimary -- only update Dives row if the source is primary
      // ------------------------------------------------------------------
      final sourceRow = await (db.select(
        db.diveDataSources,
      )..where((t) => t.id.equals(sourceRowId))).getSingle();

      if (sourceRow.isPrimary) {
        // ----------------------------------------------------------------
        // 3. Update Dives row (allowlisted columns only)
        // ----------------------------------------------------------------
        await _updateDiveRow(diveId: diveId, parsed: parsed, now: now);
      }

      final sourceRows = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(diveId))).get();
      final isMultiSource = sourceRows.length > 1;
      final ownsStrand = sourceOwnsProfileStrand(sourceRow, sourceRows);

      // ------------------------------------------------------------------
      // 4. Replace DiveProfiles for this source's computerId -- but only
      //    when this source actually authored that strand in its own parse
      //    frame (#1164).
      // ------------------------------------------------------------------
      final computerId = sourceRow.computerId;
      if (ownsStrand) {
        // Parsed times are on this computer's own clock. Multi-computer
        // consolidation re-based the folded-in strand onto the dive's clock
        // and recorded the shift on the source row; the raw bytes carry no
        // trace of it, so re-applying it is the only way the re-parsed strand
        // still lines up with the primary's (#1177). Zero for every
        // unconsolidated source, which is the overwhelming majority.
        //
        // Only this strand needs it. The event/gas-switch/tank-pressure
        // re-inserts below are gated on `!isMultiSource`, and a consolidated
        // dive is always multi-source: apply() backfills a primary source row
        // on the target before folding anything in, so the offset-bearing row
        // never arrives alone. A row that did arrive alone would be
        // non-primary, which sourceOwnsProfileStrand already refuses.
        await _replaceDiveProfiles(
          diveId: diveId,
          computerId: computerId,
          sourceId: sourceRow.id,
          parsed: parsed,
          isPrimary: sourceRow.isPrimary,
          timeOffset: sourceRow.timeOffsetSeconds ?? 0,
        );
      }

      // ------------------------------------------------------------------
      // 5. Replace DiveProfileEvents, GasSwitches, TankPressureProfiles
      //    GasSwitches has no computerId column, so it is always deleted by
      //    diveId; events and tank pressure carry computerId and are stamped
      //    with this source's computer below.
      // ------------------------------------------------------------------

      // Only replace events/switches/pressure for single-source dives.
      // Multi-source dives skip this to avoid destroying data from other
      // sources (gas_switches lacks a computerId column for per-source
      // scoping). A combined dive can carry a single source row when only
      // one original had one, so the ownership guard applies here too --
      // otherwise the merge's own surface-gap markers are deleted (#1164).
      final rewritesEvents = !isMultiSource && ownsStrand;
      if (rewritesEvents) {
        // Tombstoned: a peer's import only upserts these, so a row removed
        // here without one would linger there beside its re-inserted copy.
        await _deleteAndTombstone(
          'diveProfileEvents',
          await _idsOf(db.diveProfileEvents, diveId),
        );
        await _deleteAndTombstone(
          'gasSwitches',
          await _idsOf(db.gasSwitches, diveId),
        );
        await _tankSeries.deleteForDive(diveId);

        // Re-insert events from parsed data
        await _insertEvents(
          diveId: diveId,
          computerId: computerId,
          parsed: parsed,
          now: now,
        );
      }

      // ------------------------------------------------------------------
      // 6. DiveTanks carry-over (primary + single-source only)
      //    Skip for non-primary or multi-source dives to avoid overwriting
      //    tank data owned by other sources.
      // ------------------------------------------------------------------
      final rewritesTanks = sourceRow.isPrimary && !isMultiSource;
      if (rewritesTanks) {
        final tankIdsByIndex = await _carryOverTanks(
          diveId: diveId,
          computerId: computerId,
          parsed: parsed,
        );
        await _replaceTankPressureProfiles(
          diveId: diveId,
          computerId: computerId,
          parsed: parsed,
          tankIdsByIndex: tankIdsByIndex,
        );
        await _insertGasSwitches(
          diveId: diveId,
          parsed: parsed,
          tankIdsByIndex: tankIdsByIndex,
          now: now,
        );
      }

      // ------------------------------------------------------------------
      // 7. Stage what this re-parse wrote. Each rewritten child is staged
      //    itself and travels without the dive
      //    (SyncDataSerializer.parentGatedChildEntities). The dive row is
      //    staged only when it changed (the primary path): re-stamping an
      //    unchanged dive would let this device's copy win over a newer edit
      //    to it made on another device.
      // ------------------------------------------------------------------
      final stagedAt = now.millisecondsSinceEpoch;
      Future<void> stage(String entityType, Iterable<String> ids) async {
        for (final id in ids) {
          await _sync.markRecordPending(
            entityType: entityType,
            recordId: id,
            localUpdatedAt: stagedAt,
          );
        }
      }

      await stage('diveDataSources', [sourceRowId]);
      if (rewritesEvents) {
        await stage(
          'diveProfileEvents',
          await _idsOf(db.diveProfileEvents, diveId),
        );
      }
      if (rewritesTanks) {
        await stage('diveTanks', await _idsOf(db.diveTanks, diveId));
      }
      if (rewritesEvents || rewritesTanks) {
        await stage('gasSwitches', await _idsOf(db.gasSwitches, diveId));
      }
      if (sourceRow.isPrimary) await stage('dives', [diveId]);

      return (profilePreserved: !ownsStrand);
    });
    // After commit, so an auto-sync publishes it. A non-primary re-parse
    // writes no series, whose repositories otherwise announce the change.
    SyncEventBus.notifyLocalChange();
    return outcome;
  }

  /// The ids of [table]'s rows on [diveId].
  Future<List<String>> _idsOf(TableInfo<Table, dynamic> table, String diveId) {
    return db
        .customSelect(
          'SELECT id FROM ${table.actualTableName} WHERE dive_id = ?',
          variables: [Variable<String>(diveId)],
          readsFrom: {table},
        )
        .map((row) => row.read<String>('id'))
        .get();
  }

  /// Deletes the [entityType] rows [ids] and logs a tombstone for each.
  Future<void> _deleteAndTombstone(String entityType, List<String> ids) async {
    if (ids.isEmpty) return;
    final table = switch (entityType) {
      'diveProfileEvents' => 'dive_profile_events',
      'gasSwitches' => 'gas_switches',
      _ => throw ArgumentError.value(entityType, 'entityType'),
    };
    // In chunks: a long dive's events can outnumber SQLite's ~999
    // variables in one statement.
    for (var i = 0; i < ids.length; i += 900) {
      final chunk = ids.sublist(i, math.min(i + 900, ids.length));
      await db.customStatement(
        'DELETE FROM $table WHERE id IN (${List.filled(chunk.length, '?').join(', ')})',
        chunk,
      );
    }
    for (final id in ids) {
      await _sync.logDeletion(entityType: entityType, recordId: id);
    }
  }

  /// Count how many sources for a given computer have raw data vs not.
  Future<({int withRawData, int withoutRawData})> getRawDataCounts(
    String computerId,
  ) async {
    final withData = await db
        .customSelect(
          'SELECT COUNT(*) AS cnt FROM dive_data_sources '
          'WHERE computer_id = ? AND raw_data IS NOT NULL',
          variables: [Variable(computerId)],
        )
        .getSingle();
    final withoutData = await db
        .customSelect(
          'SELECT COUNT(*) AS cnt FROM dive_data_sources '
          'WHERE computer_id = ? AND raw_data IS NULL',
          variables: [Variable(computerId)],
        )
        .getSingle();

    return (
      withRawData: withData.data['cnt'] as int,
      withoutRawData: withoutData.data['cnt'] as int,
    );
  }

  /// Check whether any DiveDataSources row for a dive has raw data.
  Future<bool> hasRawData(String diveId) async {
    final result = await db
        .customSelect(
          'SELECT COUNT(*) AS cnt FROM dive_data_sources '
          'WHERE dive_id = ? AND raw_data IS NOT NULL',
          variables: [Variable(diveId)],
        )
        .getSingle();
    return (result.data['cnt'] as int) > 0;
  }

  /// Get all DiveDataSources rows with raw data for a given computer.
  Future<List<DiveDataSourcesData>> getSourcesForComputerReparse(
    String computerId,
  ) async {
    return (db.select(db.diveDataSources)..where(
          (t) => t.computerId.equals(computerId) & t.rawData.isNotNull(),
        ))
        .get();
  }

  /// Get all DiveDataSources rows with raw data for a given dive.
  Future<List<DiveDataSourcesData>> getSourcesForDiveReparse(
    String diveId,
  ) async {
    return (db.select(
      db.diveDataSources,
    )..where((t) => t.diveId.equals(diveId) & t.rawData.isNotNull())).get();
  }

  /// Re-parse all sources with raw data for a given computer.
  ///
  /// [parseFn] is the function that calls the native Pigeon API to parse raw
  /// bytes. Accepting it as a parameter makes this method testable without
  /// requiring a live native bridge.
  ///
  /// Returns a record with the count of succeeded and failed re-parses.
  Future<({int succeeded, int failed})> reparseAllForComputer(
    String computerId, {
    required Future<pigeon.ParsedDive> Function(
      String vendor,
      String product,
      int model,
      Uint8List rawData,
    )
    parseFn,
  }) async {
    final sources = await getSourcesForComputerReparse(computerId);

    int succeeded = 0;
    int failed = 0;

    for (final source in sources) {
      if (source.descriptorVendor == null ||
          source.descriptorProduct == null ||
          source.descriptorModel == null) {
        failed++;
        continue;
      }
      try {
        final parsed = await parseFn(
          source.descriptorVendor!,
          source.descriptorProduct!,
          source.descriptorModel!,
          source.rawData!,
        );
        await applyParsedUpdate(
          diveId: source.diveId,
          sourceRowId: source.id,
          parsed: parsed,
          descriptorVendor: source.descriptorVendor,
          descriptorProduct: source.descriptorProduct,
          descriptorModel: source.descriptorModel,
          libdivecomputerVersion: source.libdivecomputerVersion,
        );
        succeeded++;
      } catch (e) {
        failed++;
      }
    }

    return (succeeded: succeeded, failed: failed);
  }

  /// Re-parse all sources with raw data for a single dive.
  ///
  /// [parseFn] is the function that calls the native Pigeon API.
  ///
  /// Returns the error messages (empty on full success) alongside the number
  /// of sources whose profile strand was deliberately left alone -- see
  /// [sourceOwnsProfileStrand]. Callers surface that count so a re-parse on
  /// a combined dive does not look like an unexplained no-op (#1164).
  Future<({List<String> errors, int profilesPreserved})> reparseDive(
    String diveId, {
    required Future<pigeon.ParsedDive> Function(
      String vendor,
      String product,
      int model,
      Uint8List rawData,
    )
    parseFn,
  }) async {
    final sources = await getSourcesForDiveReparse(diveId);
    final errors = <String>[];
    var profilesPreserved = 0;

    for (final source in sources) {
      if (source.descriptorVendor == null ||
          source.descriptorProduct == null ||
          source.descriptorModel == null) {
        continue;
      }
      try {
        final parsed = await parseFn(
          source.descriptorVendor!,
          source.descriptorProduct!,
          source.descriptorModel!,
          source.rawData!,
        );
        final outcome = await applyParsedUpdate(
          diveId: diveId,
          sourceRowId: source.id,
          parsed: parsed,
          descriptorVendor: source.descriptorVendor,
          descriptorProduct: source.descriptorProduct,
          descriptorModel: source.descriptorModel,
          libdivecomputerVersion: source.libdivecomputerVersion,
        );
        if (outcome.profilePreserved) profilesPreserved++;
      } catch (e) {
        errors.add(e.toString());
      }
    }

    // The re-parse rewrote the profile strands; the sensor summary is
    // derived from them (condition phase 2).
    if (sources.isNotEmpty) scheduleSensorSummaryRefresh([diveId]);
    return (errors: errors, profilesPreserved: profilesPreserved);
  }

  // ==========================================================================
  // Private helpers
  // ==========================================================================

  /// The dive's start instant as this parse reports it, in the source's own
  /// time frame.
  ///
  /// Both the source row's provenance window and the dive row's own clock
  /// derive from this one expression so they cannot drift apart across a
  /// re-parse (#1207).
  static DateTime _parsedEntryTime(pigeon.ParsedDive parsed) => DateTime.utc(
    parsed.dateTimeYear,
    parsed.dateTimeMonth,
    parsed.dateTimeDay,
    parsed.dateTimeHour,
    parsed.dateTimeMinute,
    parsed.dateTimeSecond,
  );

  Future<void> _updateSourceRow({
    required String sourceRowId,
    required pigeon.ParsedDive parsed,
    required String? descriptorVendor,
    required String? descriptorProduct,
    required int? descriptorModel,
    required String? libdivecomputerVersion,
    required Uint8List? rawData,
    required Uint8List? rawFingerprint,
    required DateTime now,
  }) async {
    final entryTime = _parsedEntryTime(parsed);
    await (db.update(
      db.diveDataSources,
    )..where((t) => t.id.equals(sourceRowId))).write(
      DiveDataSourcesCompanion(
        maxDepth: Value(parsed.maxDepthMeters),
        avgDepth: Value(
          parsed.avgDepthMeters != 0.0 ? parsed.avgDepthMeters : null,
        ),
        duration: Value(parsed.durationSeconds),
        waterTemp: Value(_minWaterTemp(parsed)),
        // Derived from the samples, matching how the download path fills this
        // column. Written unconditionally so a parser change that drops CNS
        // clears the old value instead of leaving a stale one behind.
        cns: Value(_extractMaxCns(parsed.samples)),
        decoAlgorithm: Value(parsed.decoAlgorithm),
        gradientFactorLow: Value(parsed.gfLow),
        gradientFactorHigh: Value(parsed.gfHigh),
        entryLatitude: Value(parsed.entryLatitude),
        entryLongitude: Value(parsed.entryLongitude),
        exitLatitude: Value(parsed.exitLatitude),
        exitLongitude: Value(parsed.exitLongitude),
        // The download path stamps this window when it inserts the row, so a
        // re-parse has to refresh it or the source keeps advertising the
        // original download's clock while the dive itself moves (#1207).
        // These are load-bearing: DiveSplitService dates a split-out dive
        // from them and DiveConsolidationService carries them onto the
        // target.
        //
        // Raw parse frame, deliberately unshifted by timeOffsetSeconds. The
        // samples in _replaceDiveProfiles are re-based onto the dive's
        // timeline; this window is not, because consolidation copies a
        // folded-in source's entry/exit across untouched and records the
        // shift in timeOffsetSeconds instead.
        entryTime: Value(entryTime),
        exitTime: Value(
          entryTime.add(Duration(seconds: parsed.durationSeconds)),
        ),
        descriptorVendor: Value(descriptorVendor),
        descriptorProduct: Value(descriptorProduct),
        descriptorModel: Value(descriptorModel),
        libdivecomputerVersion: Value(libdivecomputerVersion),
        lastParsedAt: Value(now),
        // Only update rawData/rawFingerprint when caller provides non-null
        // values. Value.absent() tells Drift to leave the column untouched.
        rawData: rawData != null ? Value(rawData) : const Value.absent(),
        rawFingerprint: rawFingerprint != null
            ? Value(rawFingerprint)
            : const Value.absent(),
      ),
    );
  }

  Future<void> _updateDiveRow({
    required String diveId,
    required pigeon.ParsedDive parsed,
    required DateTime now,
  }) async {
    final diveDateTimeMs = _parsedEntryTime(parsed).millisecondsSinceEpoch;
    final exitTimeMs = diveDateTimeMs + (parsed.durationSeconds * 1000);
    final bottomTimeSeconds = _calculateBottomTimeFromSamples(
      parsed.samples,
      totalDurationSeconds: parsed.durationSeconds,
    );
    final waterTemp = _minWaterTemp(parsed);

    await (db.update(db.dives)..where((t) => t.id.equals(diveId))).write(
      DivesCompanion(
        maxDepth: Value(parsed.maxDepthMeters),
        avgDepth: Value(
          parsed.avgDepthMeters != 0.0 ? parsed.avgDepthMeters : null,
        ),
        runtime: Value(parsed.durationSeconds),
        diveDateTime: Value(diveDateTimeMs),
        entryTime: Value(diveDateTimeMs),
        exitTime: Value(exitTimeMs),
        bottomTime: Value(bottomTimeSeconds ?? parsed.durationSeconds),
        // Only overwrite the dive's water temp when this parse produced one,
        // for the same reason as the GPS fields below: Value.absent() keeps a
        // temperature stamped by hand or by another source, while the
        // dive_data_sources row above still records the computer's own answer.
        waterTemp: waterTemp != null ? Value(waterTemp) : const Value.absent(),
        diveMode: Value(mapLibdcDiveModeCode(parsed.diveMode)),
        cnsEnd: Value(_extractMaxCns(parsed.samples)),
        otu: const Value.absent(), // OTU is not directly in ParsedDive
        gradientFactorLow: Value(parsed.gfLow),
        gradientFactorHigh: Value(parsed.gfHigh),
        decoAlgorithm: Value(parsed.decoAlgorithm),
        decoConservatism: Value(parsed.decoConservatism),
        // Only overwrite dive GPS when the computer actually parsed a fix.
        // Value.absent() preserves positions stamped from other sources
        // (GPS track logs, manual entry); the dive_data_sources row above
        // still records exactly what the computer provided.
        entryLatitude: parsed.entryLatitude != null
            ? Value(parsed.entryLatitude)
            : const Value.absent(),
        entryLongitude: parsed.entryLongitude != null
            ? Value(parsed.entryLongitude)
            : const Value.absent(),
        exitLatitude: parsed.exitLatitude != null
            ? Value(parsed.exitLatitude)
            : const Value.absent(),
        exitLongitude: parsed.exitLongitude != null
            ? Value(parsed.exitLongitude)
            : const Value.absent(),
        updatedAt: Value(now.millisecondsSinceEpoch),
      ),
    );
  }

  /// [timeOffset] shifts every re-inserted sample onto the dive's timeline;
  /// see the note at the call site (issue #1177).
  Future<void> _replaceDiveProfiles({
    required String diveId,
    required String? computerId,
    required String sourceId,
    required pigeon.ParsedDive parsed,
    required bool isPrimary,
    required int timeOffset,
  }) async {
    // Delete existing profiles for this (diveId, computerId)
    await _profileSeries.deleteByComputer(diveId, computerId);

    // Re-insert from parsed samples
    if (parsed.samples.isNotEmpty) {
      await _profileSeries.insertSeries(
        diveId: diveId,
        computerId: computerId,
        sourceId: sourceId,
        isPrimary: isPrimary,
        samples: [
          for (final s in parsed.samples) _sampleFromParsed(s, timeOffset),
        ],
      );
    }
  }

  codec.ProfileSample _sampleFromParsed(
    pigeon.ProfileSample s,
    int timeOffset,
  ) => codec.ProfileSample(
    timestamp: s.timeSeconds + timeOffset,
    depth: s.depthMeters,
    temperature: s.temperatureCelsius,
    heartRate: s.heartRate,
    heading: s.heading,
    setpoint: s.setpoint,
    ppO2: s.ppo2,
    cns: s.cns,
    ndl: s.decoType == 0 ? s.decoTime : null,
    ceiling: s.decoType != null && s.decoType != 0 ? s.decoDepth : null,
    rbt: libdcRbtToSeconds(s.rbt),
    decoType: s.decoType,
    tts: s.tts,
    o2Sensor1: s.o2Sensor1,
    o2Sensor2: s.o2Sensor2,
    o2Sensor3: s.o2Sensor3,
    o2Sensor4: s.o2Sensor4,
    o2Sensor5: s.o2Sensor5,
    o2Sensor6: s.o2Sensor6,
    o2SensorMv1: s.o2SensorMv1,
    o2SensorMv2: s.o2SensorMv2,
    o2SensorMv3: s.o2SensorMv3,
    o2SensorMv4: s.o2SensorMv4,
    o2SensorMv5: s.o2SensorMv5,
    o2SensorMv6: s.o2SensorMv6,
  );

  Future<void> _insertEvents({
    required String diveId,
    required String? computerId,
    required pigeon.ParsedDive parsed,
    required DateTime now,
  }) async {
    if (parsed.events.isEmpty) return;

    final nowMs = now.millisecondsSinceEpoch;

    await db.batch((batch) {
      for (final e in parsed.events) {
        final eventType = _mapEventTypeString(
          e.type,
          flags: int.tryParse(e.data?['flags'] ?? ''),
        );
        if (eventType == null) continue;

        batch.insert(
          db.diveProfileEvents,
          DiveProfileEventsCompanion(
            id: Value(_uuid.v4()),
            diveId: Value(diveId),
            computerId: Value(computerId),
            timestamp: Value(e.timeSeconds),
            eventType: Value(eventType),
            severity: Value(_eventSeverity(eventType)),
            source: const Value('imported'), // native DC events are imports
            depth: const Value(null),
            value: Value(
              e.data != null ? double.tryParse(e.data!['value'] ?? '') : null,
            ),
            createdAt: Value(nowMs),
          ),
        );
      }
    });
  }

  /// Re-inserts gas switches derived from per-sample gas-mix transitions.
  ///
  /// The gas-usage timeline is driven solely by the `gas_switches` table; the
  /// switches were cleared by the single-source replace step above, so without
  /// this the dive would show the starting gas for its whole duration even when
  /// the diver switched mixes. Each switch maps its cylinder index (assigned by
  /// the shared resolver) to the freshly carried-over tank id.
  Future<void> _insertGasSwitches({
    required String diveId,
    required pigeon.ParsedDive parsed,
    required Map<int, String> tankIdsByIndex,
    required DateTime now,
  }) async {
    final switches = resolveGasSwitches(parsed);
    if (switches.isEmpty) return;

    final nowMs = now.millisecondsSinceEpoch;

    await db.batch((batch) {
      for (final sw in switches) {
        final tankId = tankIdsByIndex[sw.toTankIndex];
        if (tankId == null) continue;
        batch.insert(
          db.gasSwitches,
          GasSwitchesCompanion(
            id: Value(_uuid.v4()),
            diveId: Value(diveId),
            timestamp: Value(sw.timeSeconds),
            tankId: Value(tankId),
            depth: Value(sw.depth),
            createdAt: Value(nowMs),
          ),
        );
      }
    });
  }

  /// Re-creates/updates dive_tanks from parsed data and returns a map of
  /// tank index -> tank row id, used to attach tank pressure profiles.
  Future<Map<int, String>> _carryOverTanks({
    required String diveId,
    required String? computerId,
    required pigeon.ParsedDive parsed,
  }) async {
    final tankIdsByIndex = <int, String>{};
    // Get existing tanks
    final existingTanks =
        await (db.select(db.diveTanks)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([(t) => OrderingTerm.asc(t.tankOrder)]))
            .get();

    // Build a map of existing tanks by tankOrder
    final matcher = await _loadMatcher();
    final parsedTanks = applyTransmitterRegistry(
      resolveParsedTanks(
        parsed,
        trimAtSurfacing: trimTankPressureAtSurfacing,
      ).map(DiveParser.tankDataFrom).toList(),
      matcher,
      computerId: computerId,
    );

    // Which existing row takes parsed tank [index]. A row's source index wins
    // (a reassignment, issue #1314); rows from before v200 carry null and
    // fall back to their order, as the old path did. The fallback accepts
    // rows attributed to this computer or to none (legacy and manual rows),
    // never another computer's row on a multi-source dive. A row marked
    // kNoSourceTankIndex takes nothing.
    final matchedIds = <String>{};
    DiveTank? existingFor(int index) {
      for (final t in existingTanks) {
        if (matchedIds.contains(t.id)) continue;
        if (t.computerId != computerId) continue;
        if (t.sourceTankIndex == index) return t;
      }
      for (final t in existingTanks) {
        if (matchedIds.contains(t.id)) continue;
        if (t.computerId != null && t.computerId != computerId) continue;
        if (t.sourceTankIndex == null && t.tankOrder == index) return t;
      }
      return null;
    }

    final newTankOrders = <int>{};
    for (final tank in parsedTanks) {
      newTankOrders.add(tank.index);
      final existing = existingFor(tank.index);
      if (existing != null) {
        matchedIds.add(existing.id);
        tankIdsByIndex[tank.index] = existing.id;
        // Update existing tank: overwrite computer fields, preserve user fields
        await (db.update(
          db.diveTanks,
        )..where((t) => t.id.equals(existing.id))).write(
          DiveTanksCompanion(
            // Computers report pressure, not cylinder size: a volume the
            // parse lacks was entered by the diver (or filled from the
            // default preset), so only overwrite it with a reported one.
            // Zero means "unreported" throughout the tank code.
            volume: (tank.volumeLiters ?? 0) > 0
                ? Value(tank.volumeLiters)
                : const Value.absent(),
            workingPressure: const Value.absent(),
            startPressure: Value(tank.startPressure),
            endPressure: Value(tank.endPressure),
            o2Percent: Value(tank.o2Percent),
            hePercent: Value(tank.hePercent),
            // The transmitter serial is computer-owned and written
            // unconditionally, so a re-parse is how a tank downloaded
            // before the serial was stored gains it (and a parse that stops
            // reporting one clears the stale value).
            transmitterSerial: Value(tank.transmitterSerial),
            // A legacy row gains its explicit source index here; a row that
            // already has one keeps it.
            sourceTankIndex: existing.sourceTankIndex == null
                ? Value(tank.index)
                : const Value.absent(),
            // tankName, presetName, equipmentId, tankRole, tankMaterial
            // are user-authored -- NOT touched, so the registry is not
            // applied to an existing row either.
          ),
        );
      } else {
        // New tank: insert with defaults, registry applied.
        final newTankId = _uuid.v4();
        tankIdsByIndex[tank.index] = newTankId;
        await db
            .into(db.diveTanks)
            .insert(
              DiveTanksCompanion(
                id: Value(newTankId),
                diveId: Value(diveId),
                computerId: Value(computerId),
                volume: Value(tank.volumeLiters),
                workingPressure: Value.absentIfNull(tank.workingPressure),
                tankMaterial: Value.absentIfNull(tank.material),
                presetName: Value.absentIfNull(tank.presetName),
                equipmentId: Value.absentIfNull(tank.equipmentId),
                tankName: Value.absentIfNull(tank.tankName),
                startPressure: Value(tank.startPressure),
                endPressure: Value(tank.endPressure),
                o2Percent: Value(tank.o2Percent),
                hePercent: Value(tank.hePercent),
                tankOrder: Value(tank.index),
                tankRole: Value(tank.role ?? 'backGas'),
                transmitterSerial: Value(tank.transmitterSerial),
                sourceTankIndex: Value(tank.index),
              ),
            );
      }
    }

    // Delete tanks that exist in DB but were neither matched nor kept by
    // order (the pre-v200 rule, so manual rows on a re-parsed dive behave as
    // before).
    for (final existing in existingTanks) {
      if (matchedIds.contains(existing.id)) continue;
      if (!newTankOrders.contains(existing.tankOrder)) {
        await (db.delete(
          db.diveTanks,
        )..where((t) => t.id.equals(existing.id))).go();
        await _sync.logDeletion(entityType: 'diveTanks', recordId: existing.id);
      }
    }

    return tankIdsByIndex;
  }

  /// Re-inserts per-tank pressure time-series from parsed samples, and backfills
  /// each tank's start/end pressure from the profile when the parsed tank
  /// summary lacks explicit values (air-integrated transmitters store pressure
  /// in the sample stream, not the tank header). Mirrors the download path so
  /// re-parsing does not drop tank pressure. tankPressureProfiles for this dive
  /// were already cleared by the single-source replace step above.
  Future<void> _replaceTankPressureProfiles({
    required String diveId,
    required String? computerId,
    required pigeon.ParsedDive parsed,
    required Map<int, String> tankIdsByIndex,
  }) async {
    if (tankIdsByIndex.isEmpty) return;

    // Group sample pressures by tank index. A sample can carry a reading per
    // air-integrated transmitter (issue #1223), so this walks tankPressuresBar
    // rather than the single pressureBar/tankIndex pair.
    final pressuresByTank = groupPressuresByTank([
      for (final s in parsed.samples)
        (
          timeSeconds: s.timeSeconds,
          pressureBar: s.pressureBar,
          tankIndex: s.tankIndex,
          tankPressuresBar: s.tankPressuresBar,
        ),
    ]);
    if (pressuresByTank.isEmpty) return;

    // Insert the pressure time-series for each known tank.
    for (final entry in pressuresByTank.entries) {
      final tankId = tankIdsByIndex[entry.key];
      if (tankId == null || entry.value.isEmpty) continue;
      await _tankSeries.insertSeries(
        diveId: diveId,
        tankId: tankId,
        computerId: computerId,
        samples: [
          for (final point in entry.value)
            TankPressureSample(
              timestamp: point.timestamp,
              pressure: point.pressure,
            ),
        ],
      );
    }

    // Backfill start/end pressure from the profile when the parsed tank summary
    // didn't provide explicit values.
    for (final entry in pressuresByTank.entries) {
      final tankId = tankIdsByIndex[entry.key];
      if (tankId == null) continue;

      pigeon.TankInfo? parsedTank;
      for (final t in parsed.tanks) {
        if (t.index == entry.key) {
          parsedTank = t;
          break;
        }
      }
      final needStart = parsedTank?.startPressureBar == null;
      final needEnd = parsedTank?.endPressureBar == null;
      if (!needStart && !needEnd) continue;

      final sorted = [...entry.value]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      await (db.update(db.diveTanks)..where((t) => t.id.equals(tankId))).write(
        DiveTanksCompanion(
          startPressure: needStart
              ? Value(sorted.first.pressure)
              : const Value.absent(),
          endPressure: needEnd
              ? Value(sorted.last.pressure)
              : const Value.absent(),
        ),
      );
    }
  }

  // ==========================================================================
  // Static helpers
  // ==========================================================================

  /// Calculate bottom time from profile samples.
  ///
  /// Delegates to [BottomTimeCalculator], mirroring
  /// DiveComputerRepository._calculateBottomTimeFromPoints: bottom time
  /// runs from surface departure to the start of the final ascent, so
  /// multilevel dives count their shallower segments, and never exceeds
  /// [totalDurationSeconds], the computer's own reported runtime. Returns
  /// null if insufficient data.
  static int? _calculateBottomTimeFromSamples(
    List<pigeon.ProfileSample> samples, {
    required int totalDurationSeconds,
  }) {
    return BottomTimeCalculator.secondsFromSamples([
      for (final s in samples) (timestamp: s.timeSeconds, depth: s.depthMeters),
    ], totalDurationSeconds: totalDurationSeconds);
  }

  /// Minimum water temperature for this parse, in Celsius.
  ///
  /// Some computers (Shearwater among them) report no top-level minimum and
  /// carry temperature only in the per-sample stream, so the download path
  /// derives the minimum from the samples when the header value is missing
  /// (`parsed_dive_mapper.dart`, and the profile import in
  /// `dive_computer_repository_impl.dart`). Re-parse mirrors that path; taking
  /// `minTemperatureCelsius` at face value here blanked the water temp of any
  /// already-downloaded dive from such a computer.
  static double? _minWaterTemp(pigeon.ParsedDive parsed) {
    final headerTemp = parsed.minTemperatureCelsius;
    if (headerTemp != null) return headerTemp;
    double? minTemp;
    for (final s in parsed.samples) {
      final t = s.temperatureCelsius;
      if (t == null) continue;
      if (minTemp == null || t < minTemp) minTemp = t;
    }
    return minTemp;
  }

  /// Extract maximum CNS percentage from profile samples.
  static double? _extractMaxCns(List<pigeon.ProfileSample> samples) {
    double? maxCns;
    for (final s in samples) {
      if (s.cns != null) {
        maxCns = maxCns == null ? s.cns! : (s.cns! > maxCns ? s.cns! : maxCns);
      }
    }
    return maxCns;
  }

  /// Map libdivecomputer event type strings to ProfileEventType enum names.
  static String? _mapEventTypeString(String type, {int? flags}) {
    switch (type) {
      case 'safetystop':
      case 'safetystop_voluntary':
      case 'safetystop_mandatory':
        return 'safetyStopStart';
      case 'deco':
      case 'deepstop':
        // libdivecomputer reports the two ends of a stop as one event type
        // with SAMPLE_FLAGS_BEGIN (1) or SAMPLE_FLAGS_END (2); an event with
        // neither is a bare marker and reads as the start. Mirrors the
        // download path in dive_computer_repository_impl.dart.
        return flags == kLibdcSampleFlagsEnd ? 'decoStopEnd' : 'decoStopStart';
      case 'violation':
        return 'decoViolation';
      case 'gaschange':
      case 'gaschange2':
        return 'gasSwitch';
      case 'bookmark':
        return 'bookmark';
      case 'ascent':
        return 'ascentRateWarning';
      case 'ceiling':
      case 'ceiling_safetystop':
        return 'decoViolation';
      case 'PO2':
        return 'ppO2High';
      case 'rbt':
      case 'airtime':
        // Remaining bottom time (Uwatec) and air time (Suunto) alarms both
        // mean the gas supply is running short at the current rate.
        return 'lowGas';
      default:
        return null;
    }
  }

  /// Determine severity for a mapped event type.
  static String _eventSeverity(String eventType) {
    switch (eventType) {
      case 'decoViolation':
      case 'ppO2High':
        return 'alert';
      case 'ascentRateWarning':
      case 'lowGas':
        return 'warning';
      default:
        return 'info';
    }
  }
}
