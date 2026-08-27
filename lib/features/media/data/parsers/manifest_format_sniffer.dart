import 'package:submersion/features/media/data/parsers/manifest_format.dart';

/// Picks a [ManifestFormat] from response Content-Type and body shape.
///
/// Order: Content-Type first (it's authoritative when set correctly), then
/// body sniffing. Throws [FormatException] when neither yields a match —
/// the UI shows an "unrecognized manifest format" error and offers the
/// override dropdown.
class ManifestFormatSniffer {
  ManifestFormat sniff({required String? contentType, required String body}) {
    final fromType = _byContentType(contentType);
    if (fromType != null) return fromType;
    return _byBody(body);
  }

  static ManifestFormat? _byContentType(String? contentType) {
    if (contentType == null) return null;
    final lower = contentType.toLowerCase();
    if (lower.contains('json')) return ManifestFormat.json;
    if (lower.contains('atom') ||
        lower.contains('rss') ||
        lower.contains('xml')) {
      return ManifestFormat.atom;
    }
    if (lower.contains('csv')) return ManifestFormat.csv;
    return null;
  }

  static ManifestFormat _byBody(String body) {
    final trimmed = body.trimLeft();
    if (trimmed.isEmpty) {
      throw const FormatException('empty body');
    }
    final first = trimmed.codeUnitAt(0);
    if (first == 0x7B || first == 0x5B) {
      // '{' or '['
      return ManifestFormat.json;
    }
    if (first == 0x3C) {
      // '<'
      return ManifestFormat.atom;
    }
    // CSV heuristic: first line contains a comma AND a `url` substring
    // (case-insensitive).
    final firstLine = trimmed.split(RegExp(r'\r?\n')).first;
    if (firstLine.contains(',') && firstLine.toLowerCase().contains('url')) {
      return ManifestFormat.csv;
    }
    throw const FormatException(
      'Could not detect manifest format from Content-Type or body shape.',
    );
  }
}
