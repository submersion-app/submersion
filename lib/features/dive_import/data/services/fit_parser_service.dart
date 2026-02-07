import 'dart:typed_data';

import 'package:fit_tool/fit_tool.dart';
// ignore: implementation_imports
import 'package:fit_tool/src/utils/logger.dart' as fit_log;
import 'package:logger/logger.dart' show Level, Logger;
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';

/// Garmin FIT sport codes that represent dive activities.
const _diveSports = {Sport.diving};

/// Parses Garmin FIT binary files into [ImportedDive] entities.
///
/// Extracts dive-specific data from FIT activity files:
/// - Session: sport type, start/end time, GPS coordinates
/// - Records: depth, temperature, heart rate time series
/// - FileId: device serial number for dedup sourceId generation
///
/// Returns null for non-dive activities, corrupt files, or empty data.
class FitParserService {
  const FitParserService();

  /// Parse a single FIT file into an [ImportedDive].
  ///
  /// Returns null if the file is not a dive activity, is corrupt,
  /// or contains no usable dive data.
  Future<ImportedDive?> parseFitFile(
    Uint8List bytes, {
    String? fileName,
  }) async {
    if (bytes.isEmpty) return null;

    // Suppress verbose warnings from fit_tool's outdated FIT SDK profile.
    // The library logs a warning for every unknown field in newer Garmin
    // firmware, but these fields are irrelevant to dive data extraction.
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

    // Extract key messages
    final session = _findSession(messages);
    if (session == null) return null;

    // Verify this is a dive activity
    if (!_isDiveActivity(session)) return null;

    final fileId = _findFileId(messages);
    final records = _extractRecords(messages);

    // Build profile samples
    final startTimeMs = session.startTime;
    if (startTimeMs == null) return null;

    final startTime = DateTime.fromMillisecondsSinceEpoch(startTimeMs);

    final profile = _buildProfile(records, startTime);

    // Compute summary stats from records
    final depths = records.map((r) => r.depth).whereType<double>().toList();

    if (depths.isEmpty) return null;

    final maxDepth = depths.reduce((a, b) => a > b ? a : b);
    final avgDepth = depths.reduce((a, b) => a + b) / depths.length;

    // Temperature stats
    final temperatures = records
        .map((r) => r.temperature)
        .whereType<int>()
        .map((t) => t.toDouble())
        .toList();

    final double? minTemperature;
    final double? maxTemperature;
    if (temperatures.isNotEmpty) {
      minTemperature = temperatures.reduce((a, b) => a < b ? a : b);
      maxTemperature = temperatures.reduce((a, b) => a > b ? a : b);
    } else {
      minTemperature = null;
      maxTemperature = null;
    }

    // Heart rate stats
    final heartRates = records
        .map((r) => r.heartRate)
        .whereType<int>()
        .toList();

    final double? avgHeartRate;
    if (heartRates.isNotEmpty) {
      avgHeartRate = heartRates.reduce((a, b) => a + b) / heartRates.length;
    } else {
      avgHeartRate = null;
    }

    // End time from session
    final totalElapsed = session.totalElapsedTime;
    final endTime = totalElapsed != null
        ? startTime.add(Duration(seconds: totalElapsed.round()))
        : DateTime.fromMillisecondsSinceEpoch(session.timestamp ?? startTimeMs);

    // GPS from session
    final latitude = session.startPositionLat;
    final longitude = session.startPositionLong;

    // Source ID for deduplication
    final serialNumber = fileId?.serialNumber ?? 0;
    final sourceId = 'garmin-$serialNumber-${startTime.millisecondsSinceEpoch}';

    return ImportedDive(
      sourceId: sourceId,
      source: ImportSource.garmin,
      startTime: startTime,
      endTime: endTime,
      maxDepth: maxDepth,
      avgDepth: avgDepth,
      minTemperature: minTemperature,
      maxTemperature: maxTemperature,
      avgHeartRate: avgHeartRate,
      latitude: latitude,
      longitude: longitude,
      profile: profile,
    );
  }

  /// Parse multiple FIT files, returning only valid dive activities.
  ///
  /// Non-dive files and corrupt files are silently filtered out.
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
      if (dive != null) {
        results.add(dive);
      }
    }

    return results;
  }

  SessionMessage? _findSession(List<Message> messages) {
    for (final msg in messages) {
      if (msg is SessionMessage) return msg;
    }
    return null;
  }

  FileIdMessage? _findFileId(List<Message> messages) {
    for (final msg in messages) {
      if (msg is FileIdMessage) return msg;
    }
    return null;
  }

  bool _isDiveActivity(SessionMessage session) {
    final sport = session.sport;
    if (sport == null) return false;
    return _diveSports.contains(sport);
  }

  List<RecordMessage> _extractRecords(List<Message> messages) {
    return messages.whereType<RecordMessage>().toList();
  }

  List<ImportedProfileSample> _buildProfile(
    List<RecordMessage> records,
    DateTime startTime,
  ) {
    final startMs = startTime.millisecondsSinceEpoch;
    final samples = <ImportedProfileSample>[];

    for (final record in records) {
      final depth = record.depth;
      if (depth == null) continue;

      final timestampMs = record.timestamp;
      final timeSeconds = timestampMs != null
          ? ((timestampMs - startMs) / 1000).round()
          : 0;

      samples.add(
        ImportedProfileSample(
          timeSeconds: timeSeconds < 0 ? 0 : timeSeconds,
          depth: depth,
          temperature: record.temperature?.toDouble(),
          heartRate: record.heartRate,
        ),
      );
    }

    return samples;
  }
}
