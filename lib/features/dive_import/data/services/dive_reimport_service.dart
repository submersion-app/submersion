import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_import/data/services/parsed_profile_event_mapper.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart'
    as codec;
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/dive_log/domain/services/bottom_time_calculator.dart';
import 'package:submersion/features/dive_import/domain/dive_resync_failure.dart';
import 'package:submersion/features/dive_log/domain/services/source_ownership.dart';

/// Outcome of one [DiveReimportService.applyReimport] call.
class DiveReimportResult {
  final bool updated;
  final DiveResyncFailure? skippedReason;

  /// True when the write went ahead but the dive's profile, gas switches and
  /// tank pressures were deliberately left alone because this source does not
  /// own them. The same signal `ReparseService` reports as `profilesPreserved`
  /// (#1164): callers must not tell the diver the dive was rewritten.
  final bool profilePreserved;

  const DiveReimportResult.updated({this.profilePreserved = false})
    : updated = true,
      skippedReason = null;

  const DiveReimportResult.skipped(this.skippedReason)
    : updated = false,
      profilePreserved = false;
}

/// Writes a freshly re-parsed file-import payload back onto an EXISTING
/// dive, touching only the data this source actually owns.
///
/// The boundary is the one `ReparseService` draws for a dive-computer
/// re-parse, and this path draws it identically on purpose. Diver-authored
/// fields are never read from the parse, let alone written: notes, buddy,
/// site, rating, tags, trip, course, equipment, weights, sightings, dive
/// types and the dive's name.
///
/// Everything the computer reported is rewritten from the fresh parse,
/// unconditionally -- summary depths, the clock, runtime, bottom time, dive
/// mode, O2 exposure, deco model and gradient factors, and the profile,
/// events, gas switches and tank pressures this source owns. A value the
/// fixed parse no longer reports is CLEARED rather than left to contradict
/// the rest of the dive, and a hand correction to one of those computer
/// values is overwritten with it. That is what a re-parse does, and replaying
/// the file is the same operation: the fix is the point, and a summary half
/// from the old parser is not a state the diver asked for.
///
/// `gas_switches`/`tank_pressure_series` both `ON DELETE CASCADE` off
/// `dive_tanks.id` (#276) -- tank ids must be preserved by `tankOrder`,
/// never delete+recreate.
class DiveReimportService {
  final AppDatabase db;
  final _uuid = const Uuid();
  static const _log = LoggerService('DiveReimportService');

  DiveReimportService({
    required this.db,
    SyncRepository? syncRepository,
    ProfileSeriesRepository? profileSeries,
    TankPressureRepository? tankPressureRepository,
  }) : _syncRepository = syncRepository ?? SyncRepository(database: db),
       _profileSeries = profileSeries ?? ProfileSeriesRepository(database: db),
       _tankPressureRepository =
           tankPressureRepository ?? TankPressureRepository(database: db);

  final SyncRepository _syncRepository;
  final ProfileSeriesRepository _profileSeries;
  final TankPressureRepository _tankPressureRepository;

  Future<DiveReimportResult> applyReimport({
    required String diveId,
    required Map<String, dynamic> diveData,
    required DateTime now,
  }) async {
    final diveRow = await (db.select(
      db.dives,
    )..where((t) => t.id.equals(diveId))).getSingleOrNull();
    if (diveRow == null) {
      return const DiveReimportResult.skipped(DiveResyncFailure.diveMissing);
    }

    var profilePreserved = false;
    await db.transaction(() async {
      final sourceRows = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(diveId))).get();
      DiveDataSourcesData? primary;
      for (final row in sourceRows) {
        if (row.isPrimary) {
          primary = row;
          break;
        }
      }

      // Same ownership rule as `ReparseService` (#1164/#1177), and the same
      // multi-source gate it puts on events/switches/pressure -- extended
      // here to the profile too. A file import writes its samples with no
      // source_id and no computer_id, so unlike a computer re-parse there is
      // no identity to scope the delete by: on a dive with a second source
      // the only safe move is to leave the strand alone. A dive with no
      // provenance rows at all has nothing to protect.
      final isMultiSource = sourceRows.length > 1;
      final ownsStrand =
          primary != null && sourceOwnsProfileStrand(primary, sourceRows);
      final ownsEverything =
          sourceRows.isEmpty || (ownsStrand && !isMultiSource);
      profilePreserved = !ownsEverything;

      // Outside the ownership gate, inside a primary-source one: the dive's
      // summary belongs to whichever source is primary, which on a resync is
      // the row that names the stored file. `ReparseService` writes the dive
      // row on exactly this rule. A dive with no primary row has nobody
      // claiming to have authored the summary, so nothing overwrites it.
      if (primary != null || sourceRows.isEmpty) {
        await _updateDiveRow(diveId: diveId, diveData: diveData, now: now);
      }

      if (ownsEverything) {
        final tanks = await _carryOverTanks(
          diveId: diveId,
          diveData: diveData,
          now: now,
        );

        await _replaceGasSwitches(
          diveId: diveId,
          diveData: diveData,
          tanks: tanks,
          now: now,
        );

        await _replaceTankPressures(
          diveId: diveId,
          diveData: diveData,
          tanks: tanks,
        );

        await _replaceProfile(
          diveId: diveId,
          diveData: diveData,
          source: primary,
          now: now,
        );

        await _replaceProfileEvents(
          diveId: diveId,
          diveData: diveData,
          now: now,
        );
      }

      await _updateDataSourceSnapshot(
        primary: primary,
        diveData: diveData,
        now: now,
      );
    });

    SyncEventBus.notifyLocalChange();
    return DiveReimportResult.updated(profilePreserved: profilePreserved);
  }

  static double? _asDouble(Object? v) => v is num ? v.toDouble() : null;

  /// Every parser that emits `entryTime` (only `uddf_full_import_service.dart`
  /// does) hands over a real [DateTime]; no parser emits `exitTime` at all,
  /// but it shares the same shape when present.
  static DateTime? _asDateTime(Object? v) => v is DateTime ? v : null;

  static int? _asInt(Object? v) => v is int ? v : null;

  static String? _asString(Object? v) => v is String ? v : null;

  /// Total dive time exactly as `UddfEntityImporter` reads it: `runtime`, else
  /// the `duration` the parsers that fill only that one emit.
  static Duration? _parsedRuntime(Map<String, dynamic> diveData) {
    final runtime = diveData['runtime'];
    if (runtime is Duration) return runtime;
    final duration = diveData['duration'];
    return duration is Duration ? duration : null;
  }

  /// Dive mode when the parse states one, else null. UDDF, FIT and MacDive
  /// state none, and defaulting those to open circuit would push a CCR dive
  /// back to OC on every resync.
  static DiveMode? _parsedDiveModeOrNull(Object? v) {
    if (v is DiveMode) return v;
    if (v is String) {
      final lower = v.toLowerCase();
      for (final mode in DiveMode.values) {
        if (mode.name.toLowerCase() == lower) return mode;
      }
    }
    return null;
  }

  static List<Map<String, dynamic>>? _profileOf(Map<String, dynamic> diveData) {
    final raw = diveData['profile'];
    return raw is List ? raw.cast<Map<String, dynamic>>() : null;
  }

  /// Bottom time exactly as `UddfEntityImporter` derives it on first import:
  /// trust `duration` only when it differs from `runtime`, otherwise measure
  /// the fresh profile, otherwise fall back to `duration`. Without this a
  /// resync that replaces the profile leaves the summary duration describing
  /// the profile it just deleted.
  static int? _deriveBottomTimeSeconds(Map<String, dynamic> diveData) {
    final duration = diveData['duration'];
    final durationValue = duration is Duration ? duration : null;
    final runtimeRaw = diveData['runtime'];
    final runtime = runtimeRaw is Duration ? runtimeRaw : durationValue;
    if (durationValue != null && durationValue != runtime) {
      return durationValue.inSeconds;
    }
    final profile = _profileOf(diveData);
    if (profile != null) {
      final fromProfile = BottomTimeCalculator.secondsFromSamples([
        for (final p in profile)
          (
            timestamp: p['timestamp'] as int? ?? 0,
            depth: _asDouble(p['depth']) ?? 0.0,
          ),
      ]);
      if (fromProfile != null) return fromProfile;
    }
    return durationValue?.inSeconds;
  }

  /// Rewrites the computer-reported summary from the fresh parse, column for
  /// column with `ReparseService._updateDiveRow`: the values below belong to
  /// the parse, so one that no longer reports a value clears it rather than
  /// leaving the dive contradicting its own profile. Water temp and GPS are
  /// the two exceptions a re-parse makes, because another source or the diver
  /// may have stamped them and the source snapshot still records what this
  /// parse had to say.
  ///
  /// `diveDateTime` is the one column that cannot be cleared: it is NOT NULL,
  /// and a candidate without a clock never reaches here from the orchestrator.
  Future<void> _updateDiveRow({
    required String diveId,
    required Map<String, dynamic> diveData,
    required DateTime now,
  }) async {
    final dateTime = _asDateTime(diveData['dateTime']);
    final runtime = _parsedRuntime(diveData);
    final entryTime = _asDateTime(diveData['entryTime']) ?? dateTime;
    final exitTime = dateTime != null && runtime != null
        ? dateTime.add(runtime)
        : null;
    final avgDepth = _asDouble(diveData['avgDepth']);
    final waterTemp = _asDouble(diveData['waterTemp']);
    final bottomTime = _deriveBottomTimeSeconds(diveData) ?? runtime?.inSeconds;
    final entryLatitude = _asDouble(diveData['latitude']);
    final entryLongitude = _asDouble(diveData['longitude']);
    final exitLatitude = _asDouble(diveData['exitLatitude']);
    final exitLongitude = _asDouble(diveData['exitLongitude']);

    final maxDepth = _asDouble(diveData['maxDepth']);
    final diveMode = _parsedDiveModeOrNull(diveData['diveMode']);
    final decoAlgorithm = _asString(diveData['decoAlgorithm']);
    final decoConservatism = _asInt(diveData['decoConservatism']);
    final gfLow = _asInt(diveData['gradientFactorLow']);
    final gfHigh = _asInt(diveData['gradientFactorHigh']);

    await (db.update(db.dives)..where((t) => t.id.equals(diveId))).write(
      DivesCompanion(
        maxDepth: Value(maxDepth),
        avgDepth: Value(avgDepth == 0.0 ? null : avgDepth),
        runtime: Value(runtime?.inSeconds),
        diveDateTime: dateTime != null
            ? Value(dateTime.millisecondsSinceEpoch)
            : const Value.absent(),
        entryTime: Value(entryTime?.millisecondsSinceEpoch),
        exitTime: Value(exitTime?.millisecondsSinceEpoch),
        bottomTime: Value(bottomTime),
        waterTemp: waterTemp != null ? Value(waterTemp) : const Value.absent(),
        diveMode: diveMode != null
            ? Value(diveMode.code)
            : const Value.absent(),
        cnsEnd: Value(_asDouble(diveData['cnsEnd'])),
        otu: Value(_asDouble(diveData['otu'])),
        decoAlgorithm: Value(decoAlgorithm),
        decoConservatism: Value(decoConservatism),
        gradientFactorLow: Value(gfLow),
        gradientFactorHigh: Value(gfHigh),
        entryLatitude: entryLatitude != null
            ? Value(entryLatitude)
            : const Value.absent(),
        entryLongitude: entryLongitude != null
            ? Value(entryLongitude)
            : const Value.absent(),
        exitLatitude: exitLatitude != null
            ? Value(exitLatitude)
            : const Value.absent(),
        exitLongitude: exitLongitude != null
            ? Value(exitLongitude)
            : const Value.absent(),
        updatedAt: Value(now.millisecondsSinceEpoch),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'dives',
      recordId: diveId,
      localUpdatedAt: now.millisecondsSinceEpoch,
    );
  }

  /// Matches the fresh parse's tanks onto the existing `dive_tanks` rows and
  /// inserts the ones nothing matches, then hands back the identity the
  /// gas-switch and tank-pressure rebuilds below resolve against (see class
  /// doc re #276).
  ///
  /// Matching runs in two passes because `order` is not an identity every
  /// parser supplies: an explicit `order` claims the row with that
  /// `tank_order` first, and whatever is left is paired by list position --
  /// which is how the import path wrote the rows in the first place.
  ///
  /// An existing tank the fresh parse no longer reports is KEPT. `dive_tanks`
  /// carries no provenance, so a stage cylinder the diver added by hand is
  /// indistinguishable from one the old parse invented, and the #276 cascade
  /// makes a wrong delete take its pressures and gas switches with it. A
  /// stale extra tank is visible and the diver can remove it; a deleted real
  /// one is silent and gone.
  Future<_ParsedTanks> _carryOverTanks({
    required String diveId,
    required Map<String, dynamic> diveData,
    required DateTime now,
  }) async {
    final tanksData =
        (diveData['tanks'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];

    // tank_order ties are real: a parser that emits no `order` had every one
    // of its tanks written at 0, so insertion order is the only thing left to
    // tell them apart, and it is the order the import wrote them in.
    final existing =
        await (db.select(db.diveTanks)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([
                (t) => OrderingTerm.asc(t.tankOrder),
                (t) => OrderingTerm.asc(db.diveTanks.rowId),
              ]))
            .get();

    final matched = List<DiveTank?>.filled(tanksData.length, null);
    final claimed = <String>{};

    for (var i = 0; i < tanksData.length; i++) {
      final order = tanksData[i]['order'];
      if (order is! int) continue;
      for (final row in existing) {
        if (row.tankOrder != order || claimed.contains(row.id)) continue;
        matched[i] = row;
        claimed.add(row.id);
        break;
      }
    }

    final unclaimed = [
      for (final row in existing)
        if (!claimed.contains(row.id)) row,
    ];
    var nextUnclaimed = 0;
    for (var i = 0; i < tanksData.length; i++) {
      if (matched[i] != null || nextUnclaimed >= unclaimed.length) continue;
      matched[i] = unclaimed[nextUnclaimed++];
    }

    final idsByIndex = <String>[];
    for (var i = 0; i < tanksData.length; i++) {
      final t = tanksData[i];
      final startPressure = _asDouble(t['startPressure']);
      final endPressure = _asDouble(t['endPressure']);
      final gasMix = t['gasMix'];
      final o2Percent = gasMix is GasMix ? gasMix.o2 : null;
      final hePercent = gasMix is GasMix ? gasMix.he : null;

      final row = matched[i];
      if (row != null) {
        idsByIndex.add(row.id);
        await (db.update(
          db.diveTanks,
        )..where((tank) => tank.id.equals(row.id))).write(
          DiveTanksCompanion(
            startPressure: startPressure != null
                ? Value(startPressure)
                : const Value.absent(),
            endPressure: endPressure != null
                ? Value(endPressure)
                : const Value.absent(),
            o2Percent: o2Percent != null
                ? Value(o2Percent)
                : const Value.absent(),
            hePercent: hePercent != null
                ? Value(hePercent)
                : const Value.absent(),
          ),
        );
        await _syncRepository.markRecordPending(
          entityType: 'diveTanks',
          recordId: row.id,
          localUpdatedAt: now.millisecondsSinceEpoch,
        );
      } else {
        final newId = _uuid.v4();
        idsByIndex.add(newId);
        await db
            .into(db.diveTanks)
            .insert(
              DiveTanksCompanion.insert(
                id: newId,
                diveId: diveId,
                tankOrder: Value(t['order'] as int? ?? i),
                startPressure: Value(startPressure),
                endPressure: Value(endPressure),
                o2Percent: Value(o2Percent ?? 21.0),
                hePercent: Value(hePercent ?? 0.0),
              ),
            );
        await _syncRepository.markRecordPending(
          entityType: 'diveTanks',
          recordId: newId,
          localUpdatedAt: now.millisecondsSinceEpoch,
        );
      }
    }

    return _ParsedTanks.from(tanksData: tanksData, idsByIndex: idsByIndex);
  }

  /// Full replace when `gasSwitches` is present (no stable key to match
  /// individual switches against); absent means untouched, same rule as
  /// [_replaceTankPressures]/[_replaceProfile].
  Future<void> _replaceGasSwitches({
    required String diveId,
    required Map<String, dynamic> diveData,
    required _ParsedTanks tanks,
    required DateTime now,
  }) async {
    final switchesRaw = diveData['gasSwitches'];
    if (switchesRaw is! List) return;
    final switchesData = switchesRaw.cast<Map<String, dynamic>>();

    final existing = await (db.select(
      db.gasSwitches,
    )..where((t) => t.diveId.equals(diveId))).get();
    await (db.delete(
      db.gasSwitches,
    )..where((t) => t.diveId.equals(diveId))).go();
    for (final row in existing) {
      await _syncRepository.logDeletion(
        entityType: 'gasSwitches',
        recordId: row.id,
      );
    }

    for (final gs in switchesData) {
      final timestamp = gs['timestamp'] as int?;
      if (timestamp == null) continue;
      final tankId = tanks.idForSwitch(gs);
      if (tankId == null) continue;
      final id = _uuid.v4();
      await db
          .into(db.gasSwitches)
          .insert(
            GasSwitchesCompanion.insert(
              id: id,
              diveId: diveId,
              tankId: tankId,
              timestamp: timestamp,
              depth: Value(_asDouble(gs['depth'])),
              createdAt: now.millisecondsSinceEpoch,
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'gasSwitches',
        recordId: id,
        localUpdatedAt: now.millisecondsSinceEpoch,
      );
    }
  }

  /// Rebuilds per-tank pressure series from `diveData['profile']`'s
  /// `allTankPressures` entries. Skipped entirely when the fresh parse
  /// carries no pressure sample at all, so neither a metadata-only reparse
  /// nor a profile without air integration can blank out existing history.
  ///
  /// Scoped to the tanks the fresh samples actually cover, not every tank the
  /// parse reports: [_carryOverTanks] keeps a tank the parse no longer
  /// mentions, and a parsed tank can have no pressure sample of its own (only
  /// one cylinder carried a transmitter), so a wider delete scope takes a
  /// history nothing replaces.
  Future<void> _replaceTankPressures({
    required String diveId,
    required Map<String, dynamic> diveData,
    required _ParsedTanks tanks,
  }) async {
    final profileData = _profileOf(diveData);
    if (profileData == null) return;

    final pressuresByTank =
        <String, List<({int timestamp, double pressure})>>{};
    for (final p in profileData) {
      final timestamp = p['timestamp'] as int? ?? 0;
      final allTankPressures = (p['allTankPressures'] as List?)
          ?.cast<Map<String, dynamic>>();
      if (allTankPressures == null) continue;
      for (final tp in allTankPressures) {
        final pressure = _asDouble(tp['pressure']);
        final tankId = tanks.idAt(tp['tankIndex'] as int? ?? 0);
        if (tankId == null || pressure == null) continue;
        pressuresByTank.putIfAbsent(tankId, () => []).add((
          timestamp: timestamp,
          pressure: pressure,
        ));
      }
    }
    if (pressuresByTank.isEmpty) return;

    await _tankPressureRepository.replaceTankPressuresForTanks(
      diveId,
      pressuresByTank.keys,
      pressuresByTank,
    );
  }

  /// Rebuilds `dive_profile_series` from `diveData['profile']`, attributed to
  /// the source the samples came from. Same skip-if-absent rule as
  /// [_replaceTankPressures].
  ///
  /// `source_id` only, never `computer_id`: that is the identity a fresh
  /// import of the same file writes, and a file source routinely carries a
  /// physical computer's id (`matchImportedComputer` matches on serial) whose
  /// own re-parse deletes by `computer_id` alone.
  ///
  /// The delete is the file-side twin of the `deleteByComputer(diveId,
  /// computerId)` a re-parse runs: the null-computer strands, which is what a
  /// file parse writes, minus the diver's manual edit. `saveEditedProfile`
  /// leaves that edit as the primary null-computer series over the demoted
  /// generation it corrects -- the shape `relinkComputer` already spares --
  /// so where one exists the fresh parse lands demoted beneath it and
  /// `restoreOriginalProfile` promotes it if the diver drops the edit.
  Future<void> _replaceProfile({
    required String diveId,
    required Map<String, dynamic> diveData,
    required DiveDataSourcesData? source,
    required DateTime now,
  }) async {
    final profileData = _profileOf(diveData);
    if (profileData == null) return;

    final identities = await _profileSeries.getIdentitiesForDive(diveId);
    final hasDemoted = identities.any((s) => !s.isPrimary);
    final editIds = hasDemoted
        ? {
            for (final s in identities)
              if (s.isPrimary && s.computerId == null) s.id,
          }
        : const <String>{};

    await _profileSeries.deleteByIds([
      for (final s in identities)
        if (s.computerId == null && !editIds.contains(s.id)) s.id,
    ]);
    if (profileData.isEmpty) return;

    await _profileSeries.insertSeries(
      diveId: diveId,
      sourceId: source?.id,
      isPrimary: editIds.isEmpty,
      samples: [
        for (final p in profileData)
          codec.ProfileSample(
            timestamp: p['timestamp'] as int? ?? 0,
            depth: _asDouble(p['depth']) ?? 0.0,
            temperature: _asDouble(p['temperature']),
            heartRate: p['heartRate'] as int?,
            cns: _asDouble(p['cns']),
            ndl: p['ndl'] as int?,
            tts: p['tts'] as int?,
            ceiling: _asDouble(p['ceiling']),
          ),
      ],
      now: now.millisecondsSinceEpoch,
    );
  }

  /// Full replace when `events` is present: the file-side twin of the event
  /// delete-and-re-insert a computer re-parse runs inside the same ownership
  /// gate, converted through the very function the first import converts with.
  /// Absent means untouched, the rule [_replaceProfile] and
  /// [_replaceGasSwitches] follow -- a parse that says nothing about events is
  /// not a parse reporting there are none, and several formats carry their
  /// events under a key the import path does not read.
  Future<void> _replaceProfileEvents({
    required String diveId,
    required Map<String, dynamic> diveData,
    required DateTime now,
  }) async {
    // Both keys, as the importer reads them: SSRF and DL7 fill `events`, the
    // UDDF path fills `profileEvents`. Reading only the first would leave a
    // UDDF resync -- the commonest one -- never replacing an event at all.
    final eventsRaw = diveData['events'] ?? diveData['profileEvents'];
    if (eventsRaw is! List) return;

    final existing = await (db.select(
      db.diveProfileEvents,
    )..where((t) => t.diveId.equals(diveId))).get();
    await (db.delete(
      db.diveProfileEvents,
    )..where((t) => t.diveId.equals(diveId))).go();
    for (final row in existing) {
      await _syncRepository.logDeletion(
        entityType: 'diveProfileEvents',
        recordId: row.id,
      );
    }

    final events = profileEventsFromParsed(
      diveId: diveId,
      eventMaps: eventsRaw.cast<Map<String, dynamic>>(),
      now: now,
      onSkipped: _log.warning,
    );
    for (final event in events) {
      await db
          .into(db.diveProfileEvents)
          .insert(
            DiveProfileEventsCompanion.insert(
              id: event.id,
              diveId: diveId,
              timestamp: event.timestamp,
              eventType: event.eventType.name,
              severity: Value(event.severity.name),
              description: Value(event.description),
              depth: Value(event.depth),
              value: Value(event.value),
              tankId: Value(event.tankId),
              source: Value(event.source.name),
              createdAt: event.createdAt.millisecondsSinceEpoch,
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'diveProfileEvents',
        recordId: event.id,
        localUpdatedAt: now.millisecondsSinceEpoch,
      );
    }
  }

  /// Refreshes the primary `dive_data_sources` row's computer-authored
  /// snapshot so the Sources panel doesn't show pre-resync numbers. No-op
  /// if there is no primary source row.
  ///
  /// Written unconditionally, as `ReparseService._updateSourceRow` writes it:
  /// these columns record what this parse reported, so a value it stops
  /// reporting has to go. The window and the duration are derived the way the
  /// first import derived them for the row it synthesised -- `duration` holds
  /// the bottom time, and UDDF never sets the `duration` key at all.
  Future<void> _updateDataSourceSnapshot({
    required DiveDataSourcesData? primary,
    required Map<String, dynamic> diveData,
    required DateTime now,
  }) async {
    if (primary == null) return;

    final dateTime = _asDateTime(diveData['dateTime']);
    final runtime = _parsedRuntime(diveData);
    final avgDepth = _asDouble(diveData['avgDepth']);
    final entryTime = _asDateTime(diveData['entryTime']) ?? dateTime;
    final exitTime = dateTime != null && runtime != null
        ? dateTime.add(runtime)
        : _asDateTime(diveData['exitTime']);

    await (db.update(
      db.diveDataSources,
    )..where((t) => t.id.equals(primary.id))).write(
      DiveDataSourcesCompanion(
        maxDepth: Value(_asDouble(diveData['maxDepth'])),
        avgDepth: Value(avgDepth == 0.0 ? null : avgDepth),
        duration: Value(_deriveBottomTimeSeconds(diveData)),
        waterTemp: Value(_asDouble(diveData['waterTemp'])),
        entryTime: Value(entryTime),
        exitTime: Value(exitTime),
        decoAlgorithm: Value(_asString(diveData['decoAlgorithm'])),
        gradientFactorLow: Value(_asInt(diveData['gradientFactorLow'])),
        gradientFactorHigh: Value(_asInt(diveData['gradientFactorHigh'])),
        cns: Value(_asDouble(diveData['cnsEnd'])),
        otu: Value(_asDouble(diveData['otu'])),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'diveDataSources',
      recordId: primary.id,
      localUpdatedAt: now.millisecondsSinceEpoch,
    );
  }
}

/// The tank identity of one fresh parse: the persisted `dive_tanks.id` behind
/// every entry of `diveData['tanks']`, indexed and keyed exactly as
/// `UddfEntityImporter` indexes and keys the rows it writes on first import.
/// Resolving a resync any other way makes it lossier than the import it
/// replays -- UDDF, Subsurface and DAN DL7 gas switches name a tank by
/// `tankRef`/`gasMixRef` and never by `tankIndex`.
class _ParsedTanks {
  const _ParsedTanks._({
    required this.idsByIndex,
    required this.idByTankRef,
    required this.idByGasMixRef,
  });

  factory _ParsedTanks.from({
    required List<Map<String, dynamic>> tanksData,
    required List<String> idsByIndex,
  }) {
    final idByTankRef = <String, String>{};
    final idByGasMixRef = <String, String>{};
    for (var i = 0; i < idsByIndex.length && i < tanksData.length; i++) {
      final ref = (tanksData[i]['uddfTankId'] as String?)?.trim();
      if (ref != null && ref.isNotEmpty) idByTankRef[ref] = idsByIndex[i];
      // First tank on a given gas wins, matching the import path: several
      // tanks routinely share one mix.
      final mixRef = (tanksData[i]['uddfGasMixRef'] as String?)?.trim();
      if (mixRef != null &&
          mixRef.isNotEmpty &&
          !idByGasMixRef.containsKey(mixRef)) {
        idByGasMixRef[mixRef] = idsByIndex[i];
      }
    }
    return _ParsedTanks._(
      idsByIndex: idsByIndex,
      idByTankRef: idByTankRef,
      idByGasMixRef: idByGasMixRef,
    );
  }

  final List<String> idsByIndex;
  final Map<String, String> idByTankRef;
  final Map<String, String> idByGasMixRef;

  /// `tankIndex` is a position in `diveData['tanks']`, never a `tank_order`.
  String? idAt(int? index) =>
      index != null && index >= 0 && index < idsByIndex.length
      ? idsByIndex[index]
      : null;

  String? idForSwitch(Map<String, dynamic> gasSwitch) {
    final tankRef = (gasSwitch['tankRef'] as String?)?.trim();
    if (tankRef != null && tankRef.isNotEmpty) {
      final id = idByTankRef[tankRef];
      if (id != null && id.isNotEmpty) return id;
    }
    final gasMixRef = (gasSwitch['gasMixRef'] as String?)?.trim();
    if (gasMixRef != null && gasMixRef.isNotEmpty) {
      final id = idByGasMixRef[gasMixRef];
      if (id != null && id.isNotEmpty) return id;
    }
    return idAt(gasSwitch['tankIndex'] as int?);
  }
}
