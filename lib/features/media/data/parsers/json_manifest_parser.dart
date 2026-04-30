import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/media/data/parsers/manifest_entry.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';

/// Parses a Submersion JSON manifest v1 document. See
/// `docs/superpowers/specs/manifest_json_v1.md` for the schema.
///
/// Per-item parse failures are reported in
/// [ManifestParseResult.warnings] rather than thrown. Top-level shape
/// errors (`version != 1`, missing `items`) throw [FormatException] so
/// the caller can show a friendly "this isn't a Submersion JSON manifest"
/// banner.
class JsonManifestParser {
  ManifestParseResult parse(String body) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException catch (e) {
      throw FormatException('Invalid JSON: ${e.message}');
    }
    if (decoded is! Map) {
      throw const FormatException('JSON manifest root must be an object');
    }
    final version = decoded['version'];
    if (version != 1) {
      throw FormatException('JSON manifest version must be 1, got: $version');
    }
    final itemsRaw = decoded['items'];
    if (itemsRaw is! List) {
      throw const FormatException('JSON manifest "items" must be a list');
    }
    final title = decoded['title'] is String
        ? decoded['title'] as String
        : null;

    final entries = <ManifestEntry>[];
    final warnings = <String>[];
    for (var i = 0; i < itemsRaw.length; i++) {
      final raw = itemsRaw[i];
      try {
        if (raw is! Map) {
          warnings.add('item $i: not an object');
          continue;
        }
        final url = raw['url'];
        if (url is! String || url.isEmpty) {
          warnings.add('item $i: missing or empty url');
          continue;
        }
        final takenAt = _parseTakenAt(raw['takenAt']);
        final id = raw['id'];
        final entryKey = (id is String && id.isNotEmpty)
            ? id
            : _shaFallback(url, takenAt);
        entries.add(
          ManifestEntry(
            entryKey: entryKey,
            url: url,
            takenAt: takenAt,
            caption: raw['caption'] is String ? raw['caption'] as String : null,
            thumbnailUrl: raw['thumbnailUrl'] is String
                ? raw['thumbnailUrl'] as String
                : null,
            mediaType: raw['mediaType'] is String
                ? raw['mediaType'] as String
                : null,
            latitude: _asDouble(raw['lat']),
            longitude: _asDouble(raw['lon']),
            width: _asInt(raw['width']),
            height: _asInt(raw['height']),
            durationSeconds: _asInt(raw['durationSeconds']),
          ),
        );
      } catch (e) {
        warnings.add('item $i: $e');
      }
    }

    return ManifestParseResult(
      format: ManifestFormat.json,
      title: title,
      entries: entries,
      warnings: warnings,
    );
  }

  static DateTime? _parseTakenAt(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return parseExternalDateAsWallClockUtc(value);
  }

  static double? _asDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static String _shaFallback(String url, DateTime? takenAt) {
    final basis = '$url${takenAt?.toIso8601String() ?? ''}';
    final digest = sha256.convert(utf8.encode(basis));
    return digest.toString().substring(0, 32);
  }
}

/// Top-level wrapper for `compute()` dispatch when the JSON body exceeds
/// 64 KB. Parser is stateless so this is safe.
// coverage:ignore-start
ManifestParseResult parseJsonManifestIsolate(String body) =>
    JsonManifestParser().parse(body);
// coverage:ignore-end
