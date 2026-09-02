import 'package:drift/drift.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/services/libdc_dive_mode.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart'
    as codec;
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart'
    show TankPressureSample;
import 'package:submersion/features/dive_log/domain/services/bottom_time_calculator.dart';
import 'package:submersion/features/dive_computer/data/services/parsed_tank_resolver.dart';
import 'package:submersion/features/dive_log/domain/services/tank_pressure_series.dart';
import 'package:submersion/features/dive_computer/data/services/libdc_sample_units.dart';

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

  ReparseService({
    required this.db,
    this.trimTankPressureAtSurfacing = true,
    ProfileSeriesRepository? profileSeries,
    TankPressureSeriesRepository? tankSeries,
  }) : _profileSeries =
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

  final ProfileSeriesRepository _profileSeries;
  final TankPressureSeriesRepository _tankSeries;

  /// Apply a freshly parsed dive to the database, updating only
  /// computer-authored fields and preserving user-authored fields.
  ///
  /// [rawData] and [rawFingerprint] use `Value.absent()` when null to avoid
  /// overwriting existing blobs during the re-parse path.
  ///
  /// Returns whether the dive's profile strand was left untouched because
  /// this source does not own it -- see [_sourceOwnsProfileStrand].
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
    return db.transaction(() async {
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
      final ownsStrand = _sourceOwnsProfileStrand(sourceRow, sourceRows);

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
        // non-primary, which _sourceOwnsProfileStrand already refuses.
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
      if (!isMultiSource && ownsStrand) {
        await (db.delete(
          db.diveProfileEvents,
        )..where((t) => t.diveId.equals(diveId))).go();
        await (db.delete(
          db.gasSwitches,
        )..where((t) => t.diveId.equals(diveId))).go();
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
      if (sourceRow.isPrimary && !isMultiSource) {
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

      return (profilePreserved: !ownsStrand);
    });
  }

  /// Whether [row] is the sole author of its `(dive_id, computer_id)` profile
  /// strand, with that strand still in [row]'s own parse frame.
  ///
  /// Re-parsing deletes the strand and re-inserts the parsed samples at their
  /// own `timeSeconds`, so it is only safe when both hold. A sequential
  /// combine breaks both: [DiveMergeService.apply] re-bases each segment onto
  /// the merged timeline and carries every original's source row over demoted
  /// to non-primary, so re-parsing one of them would drop half a dive back at
  /// the original download's timestamps and delete the synthesized
  /// surface-gap samples along the way (#1164).
  ///
  /// Two signals, either of which disqualifies the row:
  ///
  /// - **No row on the dive is primary.** That is exactly a combined dive:
  ///   the merge demotes all carried rows and the merged dive has no source
  ///   row of its own. [DiveConsolidationService] demotes only its
  ///   secondaries, so a consolidated dive keeps a primary row and its
  ///   per-computer strands stay re-parseable.
  /// - **A re-parseable sibling row shares this row's `computerId`** (null
  ///   counts as equal to null). The strand has more than one author, so
  ///   whichever source re-parses last would wipe out what the others wrote
  ///   -- true of same-computer halves regardless of the primary flag. Only
  ///   siblings carrying raw data count: deleting a computer nulls its
  ///   sources' `computerId` (FK `setNull`) and
  ///   `_backfillProvenanceSnapshots` adds rows with no `computerId` at all,
  ///   so sharing a null strand with a row that can never be re-parsed is an
  ///   ordinary shape, not contention.
  bool _sourceOwnsProfileStrand(
    DiveDataSourcesData row,
    List<DiveDataSourcesData> allRowsForDive,
  ) {
    if (!allRowsForDive.any((r) => r.isPrimary)) return false;
    return !allRowsForDive.any(
      (r) =>
          r.id != row.id && r.computerId == row.computerId && r.rawData != null,
    );
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
  /// [_sourceOwnsProfileStrand]. Callers surface that count so a re-parse on
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
    final bottomTimeSeconds = _calculateBottomTimeFromSamples(parsed.samples);
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
        final eventType = _mapEventTypeString(e.type);
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
    final existingByOrder = {for (final t in existingTanks) t.tankOrder: t};

    // Build a set of new tank orders from parsed
    final newTankOrders = <int>{};

    // Gas-mix linking and tankless synthesis (computers that report gas
    // mixes but no tank records) live in the shared resolver so this path
    // cannot drift from the live-download mapper.
    for (final tank in resolveParsedTanks(
      parsed,
      trimAtSurfacing: trimTankPressureAtSurfacing,
    )) {
      newTankOrders.add(tank.index);

      final existing = existingByOrder[tank.index];
      if (existing != null) {
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
            // tankName, presetName, equipmentId, tankRole, tankMaterial
            // are user-authored -- NOT touched
          ),
        );
      } else {
        // New tank: insert with defaults
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
                startPressure: Value(tank.startPressure),
                endPressure: Value(tank.endPressure),
                o2Percent: Value(tank.o2Percent),
                hePercent: Value(tank.hePercent),
                tankOrder: Value(tank.index),
                tankRole: Value(tank.role ?? 'backGas'),
              ),
            );
      }
    }

    // Delete tanks that exist in DB but not in parsed
    for (final existing in existingTanks) {
      if (!newTankOrders.contains(existing.tankOrder)) {
        await (db.delete(
          db.diveTanks,
        )..where((t) => t.id.equals(existing.id))).go();
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
  /// DiveComputerRepositoryImpl._calculateBottomTimeFromPoints: bottom time
  /// runs from surface departure to the start of the final ascent, so
  /// multilevel dives count their shallower segments. Returns null if
  /// insufficient data.
  static int? _calculateBottomTimeFromSamples(
    List<pigeon.ProfileSample> samples,
  ) {
    return BottomTimeCalculator.secondsFromSamples([
      for (final s in samples) (timestamp: s.timeSeconds, depth: s.depthMeters),
    ]);
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
  static String? _mapEventTypeString(String type) {
    switch (type) {
      case 'safetystop':
      case 'safetystop_voluntary':
      case 'safetystop_mandatory':
        return 'safetyStopStart';
      case 'deco':
      case 'deepstop':
        return 'decoStopStart';
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
        return 'warning';
      default:
        return 'info';
    }
  }
}
