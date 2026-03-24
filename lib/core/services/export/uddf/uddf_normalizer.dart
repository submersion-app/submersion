import 'package:xml/xml.dart';

import 'package:submersion/core/services/export/uddf/dialects/macdive_dialect.dart';
import 'package:submersion/core/services/export/uddf/uddf_dialect.dart';

/// Pre-processes UDDF content by applying whichever [UddfDialect] matches,
/// returning canonical UDDF that [UddfFullImportService] can parse without
/// any dialect-specific logic.
///
/// To support a new dialect, create a class extending [UddfDialect] and add
/// an instance to [_dialects]. More specific detectors must come before more
/// general ones to avoid false positives.
class UddfNormalizer {
  const UddfNormalizer._();

  /// Registered dialects in detection order. More specific detectors first.
  static final List<UddfDialect> _dialects = [
    MacDiveDialect(),
    // Add new dialects here (e.g. ShearwaterDialect(), SubsurfaceDialect()).
  ];

  /// Returns a normalized copy of [content], applying whichever dialect
  /// matches, or returns [content] unchanged if no dialect matches.
  static String normalize(String content) {
    final doc = XmlDocument.parse(content);
    for (final dialect in _dialects) {
      if (dialect.isMatch(doc)) {
        return dialect.normalizeXml(content);
      }
    }
    return content;
  }
}
