import 'package:xml/xml.dart';

import 'package:submersion/core/domain/visibility/visibility_range.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// A dive's visibility range in UDDF (issue #3226).
///
/// UDDF's `<visibility>` holds one distance, so a dive logged as a band
/// ("Good", saved as 6-12 m) writes nothing there rather than an invented
/// number. Both writers put the range in the private
/// `<applicationdata><submersion><visibilityranges>` block instead, one
/// `<dive ref>` per dive that has one, so a Submersion backup round-trips:
///
/// ```xml
/// <visibilityranges>
///   <dive ref="dive_ID" min="6.0" max="12.0"/>
/// </visibilityranges>
/// ```
///
/// An open end omits its attribute. Values are meters, unrounded.
abstract final class UddfVisibilityRange {
  static const sectionName = 'visibilityranges';

  /// Whether [dive] has a range to carry. A dive that also has a
  /// measurement is read as measured everywhere, so its range is not
  /// written.
  static bool hasData(Dive dive) =>
      dive.visibilityMeters == null && dive.visibilityRange != null;

  /// Writes the block for the [dives] that have a range; writes nothing when
  /// none has.
  static void write(XmlBuilder builder, Iterable<Dive> dives) {
    final withData = dives.where(hasData).toList();
    if (withData.isEmpty) return;
    builder.element(
      sectionName,
      nest: () {
        for (final dive in withData) {
          final range = dive.visibilityRange!;
          builder.element(
            'dive',
            attributes: {
              'ref': 'dive_${dive.id}',
              if (range.minM case final min?) 'min': min.toString(),
              if (range.maxM case final max?) 'max': max.toString(),
            },
          );
        }
      },
    );
  }

  /// Reads the block: per dive ref, its range. An entry with no ref, or
  /// whose range is unreadable ([VisibilityRange.tryParse]), is skipped.
  static Map<String, VisibilityRange> parse(XmlElement block) {
    final byDive = <String, VisibilityRange>{};
    for (final dive in block.findElements('dive')) {
      final ref = dive.getAttribute('ref');
      if (ref == null || ref.isEmpty) continue;
      final minText = dive.getAttribute('min');
      final maxText = dive.getAttribute('max');
      final min = minText == null ? null : double.tryParse(minText);
      final max = maxText == null ? null : double.tryParse(maxText);
      // A present but unreadable end makes the whole entry unreadable,
      // rather than an open range the diver never logged.
      if ((minText != null && min == null) ||
          (maxText != null && max == null)) {
        continue;
      }
      final range = VisibilityRange.tryParse(min, max);
      if (range != null) byDive[ref] = range;
    }
    return byDive;
  }

  /// Puts [range] on the parsed [dive] map under the keys
  /// `UddfEntityImporter` reads. A measurement on the same dive wins, as in
  /// the repository's one-shape rule, so nothing is applied then.
  static void apply(Map<String, dynamic> dive, VisibilityRange range) {
    if (dive['visibilityMeters'] != null) return;
    dive['visibilityMinMeters'] = range.minM;
    dive['visibilityMaxMeters'] = range.maxM;
  }
}
