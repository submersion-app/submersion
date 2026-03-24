import 'package:xml/xml.dart';

/// Abstract base class for UDDF dialect handlers.
///
/// A dialect encapsulates all vendor-specific deviations from the UDDF
/// standard and normalizes them into the canonical form expected by
/// [UddfFullImportService] before parsing begins. The parser is fully
/// dialect-unaware.
///
/// Implementors only need to override [isMatch] and [normalizeXml].
///
/// To add support for a new dialect:
///   1. Create a class extending [UddfDialect].
///   2. Override [isMatch] to detect the dialect's document signature.
///   3. Override [normalizeXml] to transform the XML into canonical form.
///   4. Register an instance in [UddfNormalizer._dialects].
///
/// Detection ordering in [UddfNormalizer._dialects] matters — more specific
/// detectors should be listed before more general ones.
abstract class UddfDialect {
  /// Returns true when [doc] is an export from the dialect this class handles.
  bool isMatch(XmlDocument doc);

  /// Transforms [rawContent] into the canonical UDDF form expected by the
  /// parser. The default implementation returns [rawContent] unchanged.
  ///
  /// Implementations typically handle three categories of deviation:
  ///   - Encoding quirks   (e.g. wrong namespaces, float-encoded integers)
  ///   - Structural quirks (e.g. misplaced or mis-nested elements)
  ///   - Missing elements  (e.g. injecting implied defaults as XML nodes)
  String normalizeXml(String rawContent) => rawContent;
}
