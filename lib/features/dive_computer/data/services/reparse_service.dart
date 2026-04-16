import 'package:drift/drift.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';

/// Service responsible for applying re-parsed dive computer data back to the
/// database while respecting the computer-authored vs user-authored field
/// boundary.
///
/// This is the single point where the allowlist is enforced. Both the
/// `replaceSource` path and the manual re-parse path call through here.
class ReparseService {
  final AppDatabase db;
  final _uuid = const Uuid();

  ReparseService({required this.db});

  /// Apply a freshly parsed dive to the database, updating only
  /// computer-authored fields and preserving user-authored fields.
  ///
  /// [rawData] and [rawFingerprint] use `Value.absent()` when null to avoid
  /// overwriting existing blobs during the re-parse path.
  Future<void> applyParsedUpdate({
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
    await db.transaction(() async {
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

      // ------------------------------------------------------------------
      // 4. Replace DiveProfiles for this source's computerId
      // ------------------------------------------------------------------
      final computerId = sourceRow.computerId;
      await _replaceDiveProfiles(
        diveId: diveId,
        computerId: computerId,
        parsed: parsed,
        isPrimary: sourceRow.isPrimary,
      );

      // ------------------------------------------------------------------
      // 5. Replace DiveProfileEvents, GasSwitches, TankPressureProfiles
      //    These tables have no computerId column, so delete by diveId.
      // ------------------------------------------------------------------

      // Check if this is a multi-source dive
      final sourceRows = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(diveId))).get();
      final isMultiSource = sourceRows.length > 1;

      // Only replace events/switches/pressure for single-source dives.
      // Multi-source dives skip this to avoid destroying data from other
      // sources (these tables lack a computerId column for per-source
      // scoping).
      if (!isMultiSource) {
        await (db.delete(
          db.diveProfileEvents,
        )..where((t) => t.diveId.equals(diveId))).go();
        await (db.delete(
          db.gasSwitches,
        )..where((t) => t.diveId.equals(diveId))).go();
        await (db.delete(
          db.tankPressureProfiles,
        )..where((t) => t.diveId.equals(diveId))).go();

        // Re-insert events from parsed data
        await _insertEvents(diveId: diveId, parsed: parsed, now: now);
      }

      // ------------------------------------------------------------------
      // 6. DiveTanks carry-over (primary + single-source only)
      //    dive_tanks has no computerId, so skip for non-primary or
      //    multi-source dives to avoid overwriting data from other sources.
      // ------------------------------------------------------------------
      if (sourceRow.isPrimary && !isMultiSource) {
        await _carryOverTanks(diveId: diveId, parsed: parsed);
      }
    });
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
  /// Returns a list of error messages (empty on full success).
  Future<List<String>> reparseDive(
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
        await applyParsedUpdate(
          diveId: diveId,
          sourceRowId: source.id,
          parsed: parsed,
          descriptorVendor: source.descriptorVendor,
          descriptorProduct: source.descriptorProduct,
          descriptorModel: source.descriptorModel,
          libdivecomputerVersion: source.libdivecomputerVersion,
        );
      } catch (e) {
        errors.add(e.toString());
      }
    }

    return errors;
  }

  // ==========================================================================
  // Private helpers
  // ==========================================================================

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
    await (db.update(
      db.diveDataSources,
    )..where((t) => t.id.equals(sourceRowId))).write(
      DiveDataSourcesCompanion(
        maxDepth: Value(parsed.maxDepthMeters),
        avgDepth: Value(
          parsed.avgDepthMeters != 0.0 ? parsed.avgDepthMeters : null,
        ),
        duration: Value(parsed.durationSeconds),
        waterTemp: Value(parsed.minTemperatureCelsius),
        decoAlgorithm: Value(parsed.decoAlgorithm),
        gradientFactorLow: Value(parsed.gfLow),
        gradientFactorHigh: Value(parsed.gfHigh),
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
    // Build UTC DateTime from parsed components
    final diveDateTime = DateTime.utc(
      parsed.dateTimeYear,
      parsed.dateTimeMonth,
      parsed.dateTimeDay,
      parsed.dateTimeHour,
      parsed.dateTimeMinute,
      parsed.dateTimeSecond,
    );
    final diveDateTimeMs = diveDateTime.millisecondsSinceEpoch;
    final exitTimeMs = diveDateTimeMs + (parsed.durationSeconds * 1000);
    final bottomTimeSeconds = _calculateBottomTimeFromSamples(parsed.samples);

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
        waterTemp: Value(parsed.minTemperatureCelsius),
        diveMode: Value(_mapDiveMode(parsed.diveMode)),
        cnsEnd: Value(_extractMaxCns(parsed.samples)),
        otu: const Value.absent(), // OTU is not directly in ParsedDive
        gradientFactorLow: Value(parsed.gfLow),
        gradientFactorHigh: Value(parsed.gfHigh),
        decoAlgorithm: Value(parsed.decoAlgorithm),
        decoConservatism: Value(parsed.decoConservatism),
        updatedAt: Value(now.millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> _replaceDiveProfiles({
    required String diveId,
    required String? computerId,
    required pigeon.ParsedDive parsed,
    required bool isPrimary,
  }) async {
    // Delete existing profiles for this (diveId, computerId)
    if (computerId != null) {
      await (db.delete(db.diveProfiles)..where(
            (t) => t.diveId.equals(diveId) & t.computerId.equals(computerId),
          ))
          .go();
    } else {
      await (db.delete(
        db.diveProfiles,
      )..where((t) => t.diveId.equals(diveId) & t.computerId.isNull())).go();
    }

    // Re-insert from parsed samples
    await db.batch((batch) {
      for (final s in parsed.samples) {
        batch.insert(
          db.diveProfiles,
          DiveProfilesCompanion(
            id: Value(_uuid.v4()),
            diveId: Value(diveId),
            computerId: Value(computerId),
            isPrimary: Value(isPrimary),
            timestamp: Value(s.timeSeconds),
            depth: Value(s.depthMeters),
            temperature: Value(s.temperatureCelsius),
            heartRate: Value(s.heartRate),
            setpoint: Value(s.setpoint),
            ppO2: Value(s.ppo2),
            cns: Value(s.cns),
            ndl: Value(s.decoType == 0 ? s.decoTime : null),
            ceiling: Value(
              s.decoType != null && s.decoType != 0 ? s.decoDepth : null,
            ),
            rbt: Value(s.rbt),
            decoType: Value(s.decoType),
            tts: Value(s.tts),
          ),
        );
      }
    });
  }

  Future<void> _insertEvents({
    required String diveId,
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
            timestamp: Value(e.timeSeconds),
            eventType: Value(eventType),
            severity: Value(_eventSeverity(eventType)),
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

  Future<void> _carryOverTanks({
    required String diveId,
    required pigeon.ParsedDive parsed,
  }) async {
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

    for (final tank in parsed.tanks) {
      newTankOrders.add(tank.index);

      // Resolve gas mix
      final gasMix = parsed.gasMixes.firstWhere(
        (g) => g.index == tank.gasMixIndex,
        orElse: () => pigeon.GasMix(index: 0, o2Percent: 21.0, hePercent: 0.0),
      );

      final existing = existingByOrder[tank.index];
      if (existing != null) {
        // Update existing tank: overwrite computer fields, preserve user fields
        await (db.update(
          db.diveTanks,
        )..where((t) => t.id.equals(existing.id))).write(
          DiveTanksCompanion(
            volume: Value(tank.volumeLiters),
            workingPressure: const Value.absent(),
            startPressure: Value(tank.startPressureBar),
            endPressure: Value(tank.endPressureBar),
            o2Percent: Value(gasMix.o2Percent),
            hePercent: Value(gasMix.hePercent),
            // tankName, presetName, equipmentId, tankRole, tankMaterial
            // are user-authored -- NOT touched
          ),
        );
      } else {
        // New tank: insert with defaults
        await db
            .into(db.diveTanks)
            .insert(
              DiveTanksCompanion(
                id: Value(_uuid.v4()),
                diveId: Value(diveId),
                volume: Value(tank.volumeLiters),
                startPressure: Value(tank.startPressureBar),
                endPressure: Value(tank.endPressureBar),
                o2Percent: Value(gasMix.o2Percent),
                hePercent: Value(gasMix.hePercent),
                tankOrder: Value(tank.index),
                tankRole: const Value('backGas'),
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
  }

  // ==========================================================================
  // Static helpers
  // ==========================================================================

  /// Calculate bottom time from profile samples using the 85% depth threshold.
  ///
  /// Mirrors the logic in DiveComputerRepositoryImpl._calculateBottomTimeFromPoints:
  /// bottom time = time between first sample at 85% of max depth and the last
  /// sample at that depth. Returns null if insufficient data.
  static int? _calculateBottomTimeFromSamples(
    List<pigeon.ProfileSample> samples, {
    double depthThresholdPercent = 0.85,
  }) {
    if (samples.length < 3) return null;

    final sorted = List<pigeon.ProfileSample>.from(samples)
      ..sort((a, b) => a.timeSeconds.compareTo(b.timeSeconds));

    double maxDepth = 0;
    for (final s in sorted) {
      if (s.depthMeters > maxDepth) {
        maxDepth = s.depthMeters;
      }
    }

    if (maxDepth <= 0) return null;

    final bottomThreshold = maxDepth * depthThresholdPercent;

    // First sample at or above threshold = descent end
    int? descentEndTimestamp;
    for (final s in sorted) {
      if (s.depthMeters >= bottomThreshold) {
        descentEndTimestamp = s.timeSeconds;
        break;
      }
    }

    // Last sample at or above threshold = ascent start
    int? ascentStartTimestamp;
    for (int i = sorted.length - 1; i >= 0; i--) {
      if (sorted[i].depthMeters >= bottomThreshold) {
        ascentStartTimestamp = sorted[i].timeSeconds;
        break;
      }
    }

    if (descentEndTimestamp == null || ascentStartTimestamp == null) {
      return null;
    }
    if (ascentStartTimestamp <= descentEndTimestamp) return null;

    return ascentStartTimestamp - descentEndTimestamp;
  }

  /// Map dive mode strings from libdivecomputer to the app's enum values.
  static String _mapDiveMode(String? mode) {
    switch (mode) {
      case 'open_circuit':
        return 'oc';
      case 'ccr':
        return 'ccr';
      case 'scr':
        return 'scr';
      default:
        return 'oc';
    }
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
