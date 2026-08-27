import 'dart:convert';
import 'dart:typed_data';

import 'package:fit_tool/fit_tool.dart';

import 'package:submersion/features/dive_import/data/services/fit/fit_track_extractor.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/services/track_import/csv_track_parser.dart';
import 'package:submersion/features/gps_log/data/services/track_import/gpx_track_parser.dart';
import 'package:submersion/features/gps_log/data/services/track_import/kml_track_parser.dart';
import 'package:submersion/features/gps_log/data/services/track_import/parsed_track.dart';
import 'package:submersion/features/gps_log/data/services/track_import/track_timezone_resolver.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

/// Track file formats the importer understands.
enum TrackFileFormat { gpx, kml, csv, fit }

/// FIT files carry the ASCII bytes ".FIT" at offset 8.
bool _looksLikeFit(Uint8List bytes) {
  if (bytes.length < 12) return false;
  return bytes[8] == 0x2E && // .
      bytes[9] == 0x46 && //  F
      bytes[10] == 0x49 && // I
      bytes[11] == 0x54; //   T
}

/// Identifies a track file from its name and its bytes.
///
/// Checks the FIT magic FIRST: FIT is binary, and utf8.decode on arbitrary
/// bytes throws. Returns null rather than guessing when nothing matches.
TrackFileFormat? sniffFormat(String fileName, Uint8List bytes) {
  if (_looksLikeFit(bytes)) return TrackFileFormat.fit;

  final extension = fileName.toLowerCase().split('.').last;
  switch (extension) {
    case 'gpx':
      return TrackFileFormat.gpx;
    case 'kml':
      return TrackFileFormat.kml;
    case 'csv':
      return TrackFileFormat.csv;
    case 'fit':
      return TrackFileFormat.fit;
  }

  // Unknown extension: sniff the content, but only if it decodes as text.
  final String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    return null;
  }

  final head = text.trimLeft().toLowerCase();
  if (head.contains('<gpx')) return TrackFileFormat.gpx;
  if (head.contains('<kml')) return TrackFileFormat.kml;
  return null;
}

/// True when [a] and [b] overlap by more than [fraction] of the SHORTER span.
///
/// Comparing against the shorter span means a five-minute clip fully inside a
/// four-hour track counts as a duplicate of it, which is the case that
/// matters when someone re-imports a subset.
bool overlapsMoreThan(
  int aStart,
  int aEnd,
  int bStart,
  int bEnd,
  double fraction,
) {
  final overlapStart = aStart > bStart ? aStart : bStart;
  final overlapEnd = aEnd < bEnd ? aEnd : bEnd;
  final overlap = overlapEnd - overlapStart;
  if (overlap <= 0) return false;

  final aSpan = aEnd - aStart;
  final bSpan = bEnd - bStart;
  final shorter = aSpan < bSpan ? aSpan : bSpan;
  if (shorter <= 0) return false;

  return overlap / shorter > fraction;
}

/// A parsed file, resolved offset, and duplicate verdict - everything the
/// review step needs before anything is written.
class TrackImportCandidate {
  final ParsedTrack parsed;
  final TrackFileFormat format;
  final String sourceRef;
  final int tzOffsetMinutes;
  final String? duplicateOfTrackId;

  const TrackImportCandidate({
    required this.parsed,
    required this.format,
    required this.sourceRef,
    required this.tzOffsetMinutes,
    this.duplicateOfTrackId,
  });

  TrackImportCandidate copyWith({int? tzOffsetMinutes, ParsedTrack? parsed}) {
    return TrackImportCandidate(
      parsed: parsed ?? this.parsed,
      format: format,
      sourceRef: sourceRef,
      tzOffsetMinutes: tzOffsetMinutes ?? this.tzOffsetMinutes,
      duplicateOfTrackId: duplicateOfTrackId,
    );
  }
}

/// Parses track files and writes them as GPS tracks.
///
/// [prepare] and [commit] are separate so the review step can correct the
/// timezone offset before anything is persisted - a wrong offset silently
/// matches zero dives, and it is much cheaper to fix before the write.
class TrackImportService {
  final GpsTrackRepository _trackRepository;
  final DiveRepository _diveRepository;

  TrackImportService({
    GpsTrackRepository? trackRepository,
    DiveRepository? diveRepository,
  }) : _trackRepository = trackRepository ?? GpsTrackRepository(),
       _diveRepository = diveRepository ?? DiveRepository();

  ParsedTrack _parse(
    TrackFileFormat format,
    Uint8List bytes,
    CsvColumnMapping? csvMapping,
  ) {
    if (format == TrackFileFormat.fit) {
      // FIT goes through the binary parser, never a text decode.
      final FitFile fitFile;
      try {
        fitFile = FitFile.fromBytes(bytes);
      } catch (e) {
        throw TrackParseException('Not a readable FIT file: $e');
      }
      final records = fitFile.records
          .map((r) => r.message)
          .whereType<RecordMessage>()
          .toList();
      final track = extractFitTrack(records);
      if (track == null) {
        throw const TrackParseException(
          'No GPS positions in that FIT file',
          reason: TrackParseReason.noPositions,
        );
      }
      return track;
    }

    final text = utf8.decode(bytes);
    switch (format) {
      case TrackFileFormat.gpx:
        return parseGpx(text);
      case TrackFileFormat.kml:
        return parseKml(text);
      case TrackFileFormat.csv:
        // The CSV reader takes bytes: it owns decoding and RFC-4180 quoting.
        final mapping = csvMapping ?? guessCsvMapping(readCsvHeaders(bytes));
        if (mapping == null) {
          throw const TrackParseException(
            'Could not identify the latitude, longitude, and time columns',
          );
        }
        return parseCsv(bytes, mapping);
      case TrackFileFormat.fit:
        throw StateError('handled above');
    }
  }

  /// Parses [bytes], resolves the recording timezone, and checks for a
  /// duplicate. Writes nothing.
  Future<TrackImportCandidate> prepare({
    required String fileName,
    required Uint8List bytes,
    CsvColumnMapping? csvMapping,
  }) async {
    final format = sniffFormat(fileName, bytes);
    if (format == null) {
      throw const TrackParseException(
        'Unrecognised file type',
        reason: TrackParseReason.unsupportedFormat,
      );
    }

    final parsed = _parse(format, bytes, csvMapping);
    if (parsed.fixes.isEmpty) {
      throw const TrackParseException(
        'No positions in that file',
        reason: TrackParseReason.noPositions,
      );
    }

    final dives = await _diveRepository.getAllDives();
    final deviceOffset = DateTime.now().timeZoneOffset.inMinutes;
    // A dive can only CONSTRAIN the offset, never determine it, so the device
    // zone stays the prior and the review step remains the real answer.
    final tzOffsetMinutes =
        resolveOffsetFromDives(
          firstFixUtc: parsed.fixes.first.utc,
          lastFixUtc: parsed.fixes.last.utc,
          dives: dives,
          deviceOffsetMinutes: deviceOffset,
        ) ??
        deviceOffset;

    final startMs =
        toWallClockEpochSecondsAt(parsed.fixes.first.utc, tzOffsetMinutes) *
        1000;
    final endMs =
        toWallClockEpochSecondsAt(parsed.fixes.last.utc, tzOffsetMinutes) *
        1000;

    // Same source only: a phone recording and a handheld recording of the
    // same boat day are two legitimate records, not a duplicate.
    String? duplicateOfTrackId;
    final existing = await _trackRepository.getCompletedTracks(
      includePoints: false,
    );
    for (final track in existing) {
      final trackEnd = track.endTime;
      if (trackEnd == null || track.source != format.name) continue;
      if (overlapsMoreThan(startMs, endMs, track.startTime, trackEnd, 0.8)) {
        duplicateOfTrackId = track.id;
        break;
      }
    }

    return TrackImportCandidate(
      parsed: parsed,
      format: format,
      sourceRef: fileName,
      tzOffsetMinutes: tzOffsetMinutes,
      duplicateOfTrackId: duplicateOfTrackId,
    );
  }

  /// Writes [candidate] as a track and returns its id.
  Future<String> commit(TrackImportCandidate candidate) async {
    final offset = candidate.tzOffsetMinutes;
    // A source with no zone designator already carries the recording
    // device's wall clock, which is exactly what we store. Applying the
    // offset again would shift it a second time.
    final shift = candidate.parsed.timesAreWallClock ? 0 : offset;
    final points = [
      for (final fix in candidate.parsed.fixes)
        GpsTrackPoint(
          timestamp: toWallClockEpochSecondsAt(fix.utc, shift),
          latitude: fix.lat,
          longitude: fix.lon,
          accuracy: fix.accuracy,
        ),
    ];

    return _trackRepository.insertImportedTrack(
      points: points,
      startTimeMs: points.first.timestamp * 1000,
      endTimeMs: points.last.timestamp * 1000,
      tzOffsetMinutes: offset,
      source: candidate.format.name,
      sourceRef: candidate.sourceRef,
      name: candidate.parsed.name,
    );
  }
}
