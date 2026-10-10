import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/domain/visibility/visibility_range.dart';
import 'package:submersion/core/services/export/uddf/uddf_visibility_range.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:xml/xml.dart';

void main() {
  Dive dive(String id, {double? meters, double? min, double? max}) => Dive(
    id: id,
    dateTime: DateTime.utc(2026, 1, 1),
    visibilityMeters: meters,
    visibilityMinMeters: min,
    visibilityMaxMeters: max,
  );

  XmlElement written(List<Dive> dives) {
    final builder = XmlBuilder();
    builder.element(
      'root',
      nest: () => UddfVisibilityRange.write(builder, dives),
    );
    return builder.buildDocument().rootElement;
  }

  test('writes one dive ref per range dive, open ends omitted', () {
    final root = written([
      dive('a', min: 6, max: 12),
      dive('b', min: 12),
      dive('c', meters: 8),
      dive('d'),
    ]);
    final refs = root
        .findAllElements('dive')
        .map((e) => e.getAttribute('ref'))
        .toList();
    expect(refs, ['dive_a', 'dive_b']);
    final b = root.findAllElements('dive').last;
    expect(b.getAttribute('min'), '12.0');
    expect(b.getAttribute('max'), isNull);
  });

  test('writes nothing when no dive has a range', () {
    expect(written([dive('c', meters: 8)]).children, isEmpty);
  });

  test('parse round-trips and drops unreadable entries', () {
    final block = XmlDocument.parse(
      '<visibilityranges>'
      '<dive ref="dive_a" min="6.0" max="12.0"/>'
      '<dive ref="dive_b" min="12.0"/>'
      '<dive ref="dive_c" min="12" max="6"/>'
      '<dive ref="dive_d" min="-1"/>'
      '<dive ref="dive_e" min="abc" max="12"/>'
      '<dive min="1"/>'
      '</visibilityranges>',
    ).rootElement;
    expect(UddfVisibilityRange.parse(block), {
      'dive_a': const VisibilityRange(minM: 6, maxM: 12),
      'dive_b': const VisibilityRange(minM: 12),
    });
  });

  test('apply sets the importer keys unless the dive has a measurement', () {
    final plain = <String, dynamic>{};
    UddfVisibilityRange.apply(plain, const VisibilityRange(minM: 6, maxM: 12));
    expect(plain['visibilityMinMeters'], 6);
    expect(plain['visibilityMaxMeters'], 12);

    final measured = <String, dynamic>{'visibilityMeters': 8.0};
    UddfVisibilityRange.apply(measured, const VisibilityRange(minM: 6));
    expect(measured.containsKey('visibilityMinMeters'), isFalse);
  });
}
