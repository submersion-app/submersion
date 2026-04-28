import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';

import 'package:submersion/features/media/data/parsers/manifest_entry.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';

/// Parses Atom and RSS manifest feeds. Tolerant of:
/// - Atom feeds with `<feed>` root
/// - RSS feeds with `<rss><channel>` root
/// - Mixed feeds (RSS outer, Atom entries with namespace prefix)
///
/// Per-entry parse failures are appended to
/// [ManifestParseResult.warnings] rather than thrown.
class AtomManifestParser {
  ManifestParseResult parse(String body) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(body);
    } on XmlException catch (e) {
      throw FormatException('Invalid XML: ${e.message}');
    }

    final root = doc.rootElement;
    final isFeed = _localName(root) == 'feed';
    final isRss = _localName(root) == 'rss';
    if (!isFeed && !isRss) {
      throw FormatException(
        'XML root must be <feed> or <rss>, got: ${root.name.qualified}',
      );
    }

    final title =
        _firstText(root, 'title') ??
        (isRss ? _firstText(_rssChannel(root) ?? root, 'title') : null);

    // Both kinds of entry node — search the whole tree, since mixed feeds
    // nest Atom <entry> inside RSS <channel>.
    final entryNodes = doc.descendants.whereType<XmlElement>().where((el) {
      final ln = _localName(el);
      return ln == 'entry' || ln == 'item';
    }).toList();

    final entries = <ManifestEntry>[];
    final warnings = <String>[];
    for (var i = 0; i < entryNodes.length; i++) {
      final node = entryNodes[i];
      try {
        final url = _extractUrl(node);
        if (url == null || url.isEmpty) {
          final id = _extractEntryKey(node, null) ?? '<entry $i>';
          warnings.add('$id: no media url');
          continue;
        }
        final takenAt = _extractTakenAt(node);
        final entryKey =
            _extractEntryKey(node, null) ?? _shaFallback(url, takenAt);
        entries.add(
          ManifestEntry(
            entryKey: entryKey,
            url: url,
            takenAt: takenAt,
            caption: _firstText(node, 'title'),
            thumbnailUrl: _findUrlAttr(node, 'thumbnail'),
            latitude: _extractLat(node),
            longitude: _extractLon(node),
          ),
        );
      } catch (e) {
        warnings.add('entry $i: $e');
      }
    }

    return ManifestParseResult(
      format: ManifestFormat.atom,
      title: title,
      entries: entries,
      warnings: warnings,
    );
  }

  // --- helpers ---

  // Matches a trailing `Z` or `+hh:mm` / `-hh:mm` / `+hhmm` / `-hhmm`
  // offset on an ISO-8601 timestamp. Used to detect "no offset given" so
  // we can reinterpret as UTC rather than shifting from local time.
  static final RegExp _isoOffset = RegExp(r'(Z|[+\-]\d{2}:?\d{2})$');

  static String _localName(XmlElement el) => el.name.local;

  static XmlElement? _rssChannel(XmlElement rssRoot) =>
      rssRoot.childElements.firstWhere(
        (el) => _localName(el) == 'channel',
        orElse: () => XmlElement(XmlName('missing')),
      );

  /// First descendant element with the given local name, returning trimmed text.
  static String? _firstText(XmlElement scope, String localName) {
    for (final el in scope.descendants.whereType<XmlElement>()) {
      if (_localName(el) == localName) {
        final text = el.innerText.trim();
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  /// Extract a `url=` or `href=` attribute from a `<media:content>`,
  /// `<enclosure>`, or Atom `<link rel="enclosure">` descendant.
  static String? _extractUrl(XmlElement entry) {
    for (final el in entry.descendants.whereType<XmlElement>()) {
      final ln = _localName(el);
      if (ln == 'content' || ln == 'enclosure') {
        final attr = el.getAttribute('url') ?? el.getAttribute('href');
        if (attr != null && attr.isNotEmpty) return attr;
      }
      if (ln == 'link') {
        final rel = el.getAttribute('rel');
        if (rel == 'enclosure') {
          final attr = el.getAttribute('href') ?? el.getAttribute('url');
          if (attr != null && attr.isNotEmpty) return attr;
        }
      }
    }
    return null;
  }

  /// Extract `<media:thumbnail url="…">` (or similar) `url` attribute.
  static String? _findUrlAttr(XmlElement entry, String localName) {
    for (final el in entry.descendants.whereType<XmlElement>()) {
      if (_localName(el) == localName) {
        final attr = el.getAttribute('url') ?? el.getAttribute('href');
        if (attr != null && attr.isNotEmpty) return attr;
      }
    }
    return null;
  }

  static String? _extractEntryKey(XmlElement entry, String? fallback) {
    final id = _firstText(entry, 'id');
    if (id != null && id.isNotEmpty) return id;
    final guid = _firstText(entry, 'guid');
    if (guid != null && guid.isNotEmpty) return guid;
    return fallback;
  }

  static DateTime? _extractTakenAt(XmlElement entry) {
    final published = _firstText(entry, 'published');
    if (published != null) {
      final parsed = _parseIso8601AsUtc(published);
      if (parsed != null) return parsed;
    }
    final updated = _firstText(entry, 'updated');
    if (updated != null) {
      final parsed = _parseIso8601AsUtc(updated);
      if (parsed != null) return parsed;
    }
    final pubDate = _firstText(entry, 'pubDate');
    if (pubDate != null) {
      final parsed = _parseRfc822(pubDate);
      if (parsed != null) return parsed.toUtc();
    }
    return null;
  }

  /// Parses an ISO 8601 string and returns it as UTC.
  ///
  /// If the input has a zone designator (`Z` or `±HH:MM` / `±HHMM`),
  /// the result is converted to UTC, preserving the absolute moment.
  /// If the input has no offset, the wall-clock components are
  /// reinterpreted as UTC (matching the manifest_json_v1 spec — feeds
  /// without offsets are assumed to be local-time-as-UTC).
  static DateTime? _parseIso8601AsUtc(String value) {
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

  static double? _extractLat(XmlElement entry) {
    final pt = _firstText(entry, 'point');
    if (pt == null) return null;
    final parts = pt.split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    return double.tryParse(parts[0]);
  }

  static double? _extractLon(XmlElement entry) {
    final pt = _firstText(entry, 'point');
    if (pt == null) return null;
    final parts = pt.split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    return double.tryParse(parts[1]);
  }

  /// Minimal RFC 822 parser for `pubDate` (e.g. "Sat, 12 Apr 2024 14:32:00 +0000").
  static DateTime? _parseRfc822(String input) {
    final months = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };
    final m = RegExp(
      r'^(?:\w{3},\s+)?(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s+([+-]\d{4}|GMT|UT|Z|EST|EDT|CST|CDT|MST|MDT|PST|PDT)$',
    ).firstMatch(input.trim());
    if (m == null) return null;
    final day = int.parse(m.group(1)!);
    final mon = months[m.group(2)];
    if (mon == null) return null;
    final year = int.parse(m.group(3)!);
    final hour = int.parse(m.group(4)!);
    final min = int.parse(m.group(5)!);
    final sec = int.parse(m.group(6)!);
    final tz = m.group(7)!;
    int offsetMinutes = 0;
    if (tz.startsWith('+') || tz.startsWith('-')) {
      final sign = tz.startsWith('-') ? -1 : 1;
      final hh = int.parse(tz.substring(1, 3));
      final mm = int.parse(tz.substring(3, 5));
      offsetMinutes = sign * (hh * 60 + mm);
    }
    final dt = DateTime.utc(year, mon, day, hour, min, sec);
    return dt.subtract(Duration(minutes: offsetMinutes));
  }

  static String _shaFallback(String url, DateTime? takenAt) {
    final basis = '$url${takenAt?.toIso8601String() ?? ''}';
    final digest = sha256.convert(utf8.encode(basis));
    return digest.toString().substring(0, 32);
  }
}

/// Top-level wrapper for `compute()` dispatch when the XML body exceeds
/// 64 KB.
// coverage:ignore-start
ManifestParseResult parseAtomManifestIsolate(String body) =>
    AtomManifestParser().parse(body);
// coverage:ignore-end
