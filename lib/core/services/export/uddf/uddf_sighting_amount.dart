import 'package:xml/xml.dart';

import 'package:submersion/core/services/export/uddf/uddf_import_parsers.dart';
import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';

/// How a sighting's abundance crosses a UDDF `<sighting>` element (issue
/// #4337).
///
/// An exact count is written as `count`, as before. Seen and the REEF
/// groups are written as a Submersion `abundance` attribute with no `count`,
/// so another reader sees no number (which is the truth) and a Submersion
/// round trip keeps the value.
abstract final class UddfSightingAmount {
  /// The `<sighting>` attributes for [amount].
  static Map<String, String> attributes(SightingAmount amount) =>
      amount.abundance == SightingAbundance.exact
      ? {'count': '${amount.count}'}
      : {'abundance': amount.abundance.name};

  /// The importer-map keys for [sighting]: `abundance` for a value this
  /// build knows, else `count` when the element has a number, else none,
  /// which [amountOf] reads as Seen.
  static Map<String, Object> parse(XmlElement sighting) {
    final abundance = SightingAbundance.fromStorage(
      sighting.getAttribute('abundance'),
    );
    if (abundance != SightingAbundance.exact) {
      return {'abundance': abundance.name};
    }
    final count = UddfImportParsers.parseUddfInt(
      sighting.getAttribute('count'),
    );
    return count != null && count > 0 ? {'count': count} : const {};
  }

  /// The amount an importer-map sighting [entry] records: its `abundance`
  /// when known, an exact `count` when it has one, Seen otherwise (a
  /// source that gives no number recorded only that the species was seen).
  static SightingAmount amountOf(Map<dynamic, dynamic> entry) {
    final abundance = entry['abundance'];
    if (abundance is String) {
      final parsed = SightingAbundance.fromStorage(abundance);
      if (parsed != SightingAbundance.exact) {
        return (abundance: parsed, count: 1);
      }
    }
    final count = entry['count'];
    if (count is int && count > 0) {
      return (abundance: SightingAbundance.exact, count: count);
    }
    return (abundance: SightingAbundance.seen, count: 1);
  }
}
