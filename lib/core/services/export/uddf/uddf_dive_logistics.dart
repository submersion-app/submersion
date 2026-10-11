import 'package:xml/xml.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// A dive's operator, boat, captain and surface conditions in UDDF (#3229).
///
/// UDDF has no elements for these. MacDive writes them as
/// `<diveoperator>`, `<boatname>`, `<boatcaptain>` and `<surfaceconditions>`
/// inside the dive's `<informationafterdive>`; both Submersion writers use
/// the same names, so a file round-trips through Submersion and MacDive.
abstract final class UddfDiveLogistics {
  /// Element name to dive map key, shared with the reader.
  static const elementToMapKey = {
    'surfaceconditions': 'surfaceConditions',
    'boatname': 'boatName',
    'boatcaptain': 'boatCaptain',
    'diveoperator': 'diveOperator',
  };

  /// Writes each of [dive]'s non-blank fields; writes nothing for the rest.
  static void write(XmlBuilder builder, Dive dive) {
    final values = {
      'surfaceconditions': dive.surfaceConditions,
      'boatname': dive.boatName,
      'boatcaptain': dive.boatCaptain,
      'diveoperator': dive.diveOperator,
    };
    for (final MapEntry(:key, :value) in values.entries) {
      final text = value?.trim();
      if (text == null || text.isEmpty) continue;
      builder.element(key, nest: text);
    }
  }
}
