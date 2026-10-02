import 'package:xml/xml.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// A dive's custom fields in UDDF.
///
/// UDDF has no element for user-defined key:value fields, so both writers
/// put them in an `<applicationdata>` block inside the dive's
/// `<informationafterdive>`:
///
/// ```xml
/// <applicationdata>
///   <name>Submersion</name>
///   <customfield key="boat">Ocean Explorer</customfield>
/// </applicationdata>
/// ```
///
/// The reader produces the dive map key `customFields`, a list of
/// `{'key': ..., 'value': ...}` in file order, which
/// `UddfEntityImporter` turns back into the dive's fields.
abstract final class UddfDiveCustomFields {
  /// Dive map key for the parsed fields.
  static const mapKey = 'customFields';

  static const _fieldElement = 'customfield';

  /// Writes [dive]'s fields, in order; writes nothing when it has none.
  static void write(XmlBuilder builder, Dive dive) {
    if (dive.customFields.isEmpty) return;
    builder.element(
      'applicationdata',
      nest: () {
        builder.element('name', nest: 'Submersion');
        for (final field in dive.customFields) {
          builder.element(
            _fieldElement,
            attributes: {'key': field.key},
            nest: field.value,
          );
        }
      },
    );
  }

  /// The fields in [informationAfterDive]'s `<applicationdata>` blocks, in
  /// file order. A field without a key, or with a blank one, is skipped.
  static List<Map<String, String>> parse(XmlElement informationAfterDive) => [
    for (final block in informationAfterDive.findElements('applicationdata'))
      for (final field in block.findElements(_fieldElement))
        if (field.getAttribute('key')?.trim() case final key?
            when key.isNotEmpty)
          {'key': key, 'value': field.innerText},
  ];
}
