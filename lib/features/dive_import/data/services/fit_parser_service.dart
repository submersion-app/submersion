import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fit_tool/fit_tool.dart';
// ignore: implementation_imports
import 'package:fit_tool/src/utils/logger.dart' as fit_log;
import 'package:logger/logger.dart' show Level, Logger;
import 'package:submersion/features/dive_import/data/services/fit/fit_device_mapper.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_gas_extractor.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_profile_extractor.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_summary_extractor.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_tank_extractor.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_time_resolver.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';

/// Garmin FIT sport codes that represent dive activities.
const _diveSports = {Sport.diving};

/// Parses Garmin FIT binary files into enriched [ImportedDive] entities.
///
/// Orchestrates focused extractors (see `fit/`) to pull depth/temp/HR samples,
/// recorded deco (ceiling/TTS/NDL/CNS), air-integration tanks + pressure series,
/// gas mixes, GPS, and dive-level summary fields. Returns null for non-dive
/// activities, corrupt files, or files with no depth samples.
class FitParserService {
  const FitParserService();

  Future<ImportedDive?> parseFitFile(
    Uint8List bytes, {
    String? fileName,
  }) async {
    if (bytes.isEmpty) return null;

    // Suppress verbose warnings from fit_tool's outdated FIT SDK profile.
    fit_log.logger = Logger(level: Level.error);

    final FitFile fitFile;
    try {
      fitFile = FitFile.fromBytes(bytes);
    } catch (_) {
      return null;
    }

    final messages = fitFile.records
        .map((r) => r.message)
        .whereType<Message>()
        .toList();

    final session = _firstOfType<SessionMessage>(messages);
    if (session == null) return null;
    if (!_isDiveActivity(session)) return null;

    final sessionStartMs = session.startTime;
    if (sessionStartMs == null) return null;

    final records = messages.whereType<RecordMessage>().toList();
    final samples = FitProfileExtractor.extract(records);
    if (samples.isEmpty) return null;

    final fileId = _firstOfType<FileIdMessage>(messages);
    final activity = _firstOfType<ActivityMessage>(messages);
    final settings = _firstOfType<DiveSettingsMessage>(messages);
    final diveSummary = _bestDiveSummary(messages);

    final tankData = FitTankExtractor.extract(messages);
    // Drop air-integration summaries with no real pressure (a configured-but-
    // unused transmitter reports all-zero start/end).
    final realTanks = tankData.tanks
        .where(
          (t) => (t.startPressureBar ?? 0) > 0 || (t.endPressureBar ?? 0) > 0,
        )
        .toList();
    final gases = FitGasExtractor.extract(messages);
    final summary = FitSummaryExtractor.extract(
      summary: diveSummary,
      session: session,
      settings: settings,
    );

    // Wall-clock start (local time stored as UTC, per the app convention).
    // FitTimeResolver normalizes the mixed timestamp bases fit_tool returns.
    final startTime = FitTimeResolver.wallClockStart(
      utcStartMs: sessionStartMs,
      localStartMs: null,
      utcTimestampMs: activity?.timestamp,
      localTimestampMs: activity?.localTimestamp,
    );

    final totalElapsed = session.totalElapsedTime;
    final Duration elapsed;
    if (totalElapsed != null) {
      elapsed = Duration(seconds: totalElapsed.round());
    } else {
      final endMs = session.timestamp ?? sessionStartMs;
      elapsed = Duration(milliseconds: endMs - sessionStartMs);
    }
    final endTime = startTime.add(elapsed);

    // Profile (relative offsets use the raw UTC start; tank pressures merged in).
    final profile = _buildProfile(
      samples,
      sessionStartMs,
      tankData.pressures,
      realTanks,
    );

    // Summary stats derived from the samples.
    final depths = samples.map((s) => s.depth).toList();
    final maxDepth = depths.reduce(math.max);
    final avgDepth = depths.reduce((a, b) => a + b) / depths.length;

    final temps = samples
        .map((s) => s.temperature)
        .whereType<double>()
        .toList();
    final minTemperature = temps.isEmpty ? null : temps.reduce(math.min);
    final maxTemperature = temps.isEmpty ? null : temps.reduce(math.max);

    final heartRates = samples
        .map((s) => s.heartRate)
        .whereType<int>()
        .toList();
    final avgHeartRate = heartRates.isEmpty
        ? null
        : heartRates.reduce((a, b) => a + b) / heartRates.length;

    // Exit GPS: the last record carrying a position fix (often absent).
    double? exitLat;
    double? exitLong;
    for (final r in records.reversed) {
      final lat = r.positionLat;
      final long = r.positionLong;
      if (lat != null && long != null) {
        exitLat = lat;
        exitLong = long;
        break;
      }
    }

    final tanks = _buildImportedTanks(realTanks, gases);

    final serial = fileId?.serialNumber ?? 0;
    final sourceId = 'garmin-$serial-$sessionStartMs';
    final productCode = fileId?.garminProduct ?? fileId?.product;

    return ImportedDive(
      sourceId: sourceId,
      sourceUuid: sourceId,
      source: ImportSource.garmin,
      startTime: startTime,
      endTime: endTime,
      maxDepth: maxDepth,
      avgDepth: avgDepth,
      minTemperature: minTemperature,
      maxTemperature: maxTemperature,
      avgHeartRate: avgHeartRate,
      latitude: summary.entryLat,
      longitude: summary.entryLong,
      exitLatitude: exitLat,
      exitLongitude: exitLong,
      diveNumber: summary.diveNumber,
      bottomTimeSeconds: summary.bottomTime?.inSeconds,
      surfaceIntervalSeconds: summary.surfaceInterval?.inSeconds,
      cnsStart: summary.cnsStart,
      cnsEnd: summary.cnsEnd,
      otu: summary.otu,
      waterType: summary.waterType,
      decoModel: summary.decoModel,
      gfLow: summary.gfLow,
      gfHigh: summary.gfHigh,
      computerModel: FitDeviceMapper.modelName(productCode),
      computerSerial: serial != 0 ? '$serial' : null,
      tanks: tanks,
      profile: profile,
      sourceFileName: fileName,
      sourceFileFormat: 'fit',
    );
  }

  /// Parse multiple FIT files, returning only valid dive activities.
  Future<List<ImportedDive>> parseFitFiles(
    List<Uint8List> fileBytes, {
    List<String>? fileNames,
  }) async {
    final results = <ImportedDive>[];
    for (var i = 0; i < fileBytes.length; i++) {
      final fileName = (fileNames != null && i < fileNames.length)
          ? fileNames[i]
          : null;
      final dive = await parseFitFile(fileBytes[i], fileName: fileName);
      if (dive != null) results.add(dive);
    }
    return results;
  }

  T? _firstOfType<T extends Message>(List<Message> messages) {
    for (final m in messages) {
      if (m is T) return m;
    }
    return null;
  }

  /// Prefers the dive summary that carries a dive number (the one referencing
  /// the session); falls back to the first if none do.
  DiveSummaryMessage? _bestDiveSummary(List<Message> messages) {
    final summaries = messages.whereType<DiveSummaryMessage>().toList();
    for (final s in summaries) {
      if (s.diveNumber != null) return s;
    }
    return summaries.isEmpty ? null : summaries.first;
  }

  bool _isDiveActivity(SessionMessage session) {
    final sport = session.sport;
    if (sport == null) return false;
    return _diveSports.contains(sport);
  }

  List<ImportedProfileSample> _buildProfile(
    List<FitSample> samples,
    int startMs,
    List<FitTankPressureSample> pressures,
    List<FitTank> tanks,
  ) {
    final orderBySensor = <int, int>{
      for (var i = 0; i < tanks.length; i++) tanks[i].sensorId: i,
    };
    // Bucket tank pressures by their whole-second offset from dive start, so
    // they can be attached to the contemporaneous depth sample.
    final pressuresByRelSec = <int, List<ImportedTankPressureSample>>{};
    for (final p in pressures) {
      final order = orderBySensor[p.sensorId];
      if (order == null) continue;
      final relSec = ((p.timestampMs - startMs) / 1000).round();
      (pressuresByRelSec[relSec] ??= []).add(
        ImportedTankPressureSample(
          tankIndex: order,
          pressureBar: p.pressureBar,
        ),
      );
    }

    return samples.map((s) {
      final relSec = ((s.timestampMs - startMs) / 1000).round();
      return ImportedProfileSample(
        timeSeconds: relSec < 0 ? 0 : relSec,
        depth: s.depth,
        temperature: s.temperature,
        heartRate: s.heartRate,
        cns: s.cns,
        ndlSeconds: s.ndlSeconds,
        ttsSeconds: s.ttsSeconds,
        ceiling: s.ceiling,
        tankPressures: pressuresByRelSec[relSec],
      );
    }).toList();
  }

  /// Builds the tank list, pairing air-integration pressure (when present) with
  /// gas mixes by order, and ensuring every enabled gas is represented even
  /// without a transmitter (or when there are more gases than transmitters).
  List<ImportedTank> _buildImportedTanks(
    List<FitTank> realTanks,
    List<FitGas> gases,
  ) {
    final count = realTanks.length > gases.length
        ? realTanks.length
        : gases.length;
    return [
      for (var i = 0; i < count; i++)
        ImportedTank(
          order: i,
          startPressureBar: i < realTanks.length
              ? realTanks[i].startPressureBar
              : null,
          endPressureBar: i < realTanks.length
              ? realTanks[i].endPressureBar
              : null,
          volumeUsedLiters: i < realTanks.length
              ? realTanks[i].volumeUsedLiters
              : null,
          o2Percent: i < gases.length ? gases[i].o2Percent : null,
          hePercent: i < gases.length ? gases[i].hePercent : null,
        ),
    ];
  }
}
