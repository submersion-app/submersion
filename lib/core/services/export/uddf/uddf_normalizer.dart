import 'package:xml/xml.dart';

import 'package:submersion/core/services/export/uddf/dialects/macdive_dialect_normalizer.dart';

/// Pre-processing normalizer that transforms dialect-specific UDDF content
/// into the canonical form expected by [UddfFullImportService].
///
/// New dialect handlers can be added here without touching the core parser.
///
/// Usage:
/// ```dart
/// final content = UddfNormalizer.normalize(rawContent);
/// ```
class UddfNormalizer {
  const UddfNormalizer._();

  /// Returns a normalized copy of [content], applying whichever dialect
  /// handler matches the document, or returns [content] unchanged if no
  /// handler matches.
  static String normalize(String content) {
    final doc = XmlDocument.parse(content);
    if (MacDiveDialectNormalizer.isMatch(doc)) {
      return MacDiveDialectNormalizer.normalize(doc);
    }
    // Future dialects (Shearwater, Subsurface) can be added here.
    return content;
  }
}
