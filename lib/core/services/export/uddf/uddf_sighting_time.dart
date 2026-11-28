import 'package:xml/xml.dart';

import 'package:submersion/core/services/export/uddf/uddf_import_parsers.dart';

/// When in the dive a sighting was seen, across a UDDF `<sighting>` element
/// (issue #5092).
///
/// UDDF has no place for it, so it is a Submersion `seenat` attribute in
/// seconds from the dive start: a Submersion round trip keeps it, and
/// another reader ignores it.
abstract final class UddfSightingTime {
  /// The `<sighting>` attributes for [seconds]: none when there is no time.
  static Map<String, String> attributes(int? seconds) =>
      seconds == null ? const {} : {'seenat': '$seconds'};

  /// The importer-map key for [sighting]: `seenAtSeconds` when it carries a
  /// time from 0 to a day, else none.
  static Map<String, Object> parse(XmlElement sighting) {
    final seconds = UddfImportParsers.parseUddfInt(
      sighting.getAttribute('seenat'),
    );
    if (seconds == null || seconds < 0 || seconds > Duration.secondsPerDay) {
      return const {};
    }
    return {'seenAtSeconds': seconds};
  }

  /// The time an importer-map sighting [entry] records, or null.
  static int? of(Map<dynamic, dynamic> entry) {
    final seconds = entry['seenAtSeconds'];
    return seconds is int ? seconds : null;
  }
}
