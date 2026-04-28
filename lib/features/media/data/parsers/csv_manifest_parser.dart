import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';

import 'package:submersion/features/media/data/parsers/manifest_entry.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';

const _knownColumns = {
  'url',
  'id',
  'takenAt',
  'caption',
  'mediaType',
  'lat',
  'lon',
  'width',
  'height',
  'durationSeconds',
  'thumbnailUrl',
};

/// Parses a CSV manifest. Required header: `url` (anywhere). Recognized
/// columns: see [_knownColumns]. Unknown columns are ignored.
///
/// Per-row failures are appended to [ManifestParseResult.warnings] rather
/// than thrown. Top-level shape errors (no `url` column, empty document)
/// throw [FormatException].
class CsvManifestParser {
  ManifestParseResult parse(String body) {
    if (body.trim().isEmpty) {
      throw const FormatException('CSV manifest is empty');
    }

    final rows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(body);
    if (rows.isEmpty) {
      throw const FormatException('CSV manifest has no rows');
    }

    final header = rows.first.map((c) => c.toString().trim()).toList();
    final urlIdx = header.indexOf('url');
    if (urlIdx < 0) {
      throw const FormatException('CSV manifest must have a "url" column');
    }
    final colIdx = <String, int>{
      for (final col in _knownColumns)
        if (header.contains(col)) col: header.indexOf(col),
    };

    final entries = <ManifestEntry>[];
    final warnings = <String>[];
    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      try {
        final urlCell = _cell(row, urlIdx);
        if (urlCell == null || urlCell.isEmpty) {
          warnings.add('row $r: empty url');
          continue;
        }
        final takenAt = _parseTakenAt(_cell(row, colIdx['takenAt']));
        final id = _cell(row, colIdx['id']);
        final entryKey = (id != null && id.isNotEmpty)
            ? id
            : _shaFallback(urlCell, takenAt);
        entries.add(
          ManifestEntry(
            entryKey: entryKey,
            url: urlCell,
            takenAt: takenAt,
            caption: _cell(row, colIdx['caption']),
            thumbnailUrl: _cell(row, colIdx['thumbnailUrl']),
            mediaType: _cell(row, colIdx['mediaType']),
            latitude: _asDouble(_cell(row, colIdx['lat'])),
            longitude: _asDouble(_cell(row, colIdx['lon'])),
            width: _asInt(_cell(row, colIdx['width'])),
            height: _asInt(_cell(row, colIdx['height'])),
            durationSeconds: _asInt(_cell(row, colIdx['durationSeconds'])),
          ),
        );
      } catch (e) {
        warnings.add('row $r: $e');
      }
    }

    return ManifestParseResult(
      format: ManifestFormat.csv,
      entries: entries,
      warnings: warnings,
    );
  }

  static String? _cell(List<dynamic> row, int? idx) {
    if (idx == null || idx < 0 || idx >= row.length) return null;
    final raw = row[idx]?.toString().trim() ?? '';
    return raw.isEmpty ? null : raw;
  }

  // Matches a trailing `Z` or `+hh:mm` / `-hh:mm` / `+hhmm` / `-hhmm`
  // offset on an ISO-8601 timestamp. Used to detect "no offset given" so
  // we can reinterpret as UTC rather than shifting from local time.
  static final RegExp _isoOffset = RegExp(r'(Z|[+\-]\d{2}:?\d{2})$');

  /// Parses an ISO 8601 string and returns it as UTC.
  ///
  /// If the input has a zone designator (`Z` or `±HH:MM` / `±HHMM`),
  /// the result is converted to UTC, preserving the absolute moment.
  /// If the input has no offset, the wall-clock components are
  /// reinterpreted as UTC (matching the manifest_json_v1 spec — feeds
  /// without offsets are assumed to be local-time-as-UTC).
  static DateTime? _parseTakenAt(String? value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    if (parsed.isUtc) return parsed;
    if (_isoOffset.hasMatch(value)) {
      // Has a zone offset; convert to UTC.
      return parsed.toUtc();
    }
    // No offset: reinterpret wall-clock as UTC.
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }

  static double? _asDouble(String? v) => v == null ? null : double.tryParse(v);

  static int? _asInt(String? v) => v == null ? null : int.tryParse(v);

  static String _shaFallback(String url, DateTime? takenAt) {
    final basis = '$url${takenAt?.toIso8601String() ?? ''}';
    final digest = sha256.convert(utf8.encode(basis));
    return digest.toString().substring(0, 32);
  }
}

/// Top-level wrapper for `compute()` dispatch when the CSV body exceeds
/// 64 KB. Parser is stateless so this is safe.
// coverage:ignore-start
ManifestParseResult parseCsvManifestIsolate(String body) =>
    CsvManifestParser().parse(body);
// coverage:ignore-end
