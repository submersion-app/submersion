import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_fill_writers.dart';
import 'package:submersion/features/cylinder_passports/data/services/csv_fill_importer.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:xml/xml.dart';

/// The `<cylinderfills>` section of a full UDDF backup (issue #2651).
void main() {
  final full = CylinderFill(
    id: '3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11',
    diverId: 'd1',
    passportId: 'pp-al80',
    equipmentId: 'tank-1',
    filledAt: DateTime(2025, 3, 15, 9, 5),
    o2Percent: 32,
    pressureBar: 206.843,
    temperatureC: 22,
    analyzer: 'Analox O2EII',
    stationName: 'Blue Hole Dive Center',
    stationKey: 'reserved-key',
    signedRecord: 'reserved-token',
    source: FillSource.qr,
    notes: 'Topped off',
    createdAt: DateTime(2025, 3, 15, 9, 6),
    updatedAt: DateTime(2025, 3, 15, 9, 6),
  );
  final bare = CylinderFill(
    id: '8a1d4c47-9e2a-4b7d-8c9e-0f113f0c2b8e',
    passportId: 'pp-foreign',
    filledAt: DateTime(2025, 3, 16, 14, 30),
    o2Percent: 18,
    hePercent: 45,
    createdAt: DateTime(2025, 3, 16),
    updatedAt: DateTime(2025, 3, 16),
  );

  XmlElement submersion(List<CylinderFill> fills) {
    final builder = XmlBuilder();
    builder.element(
      'submersion',
      nest: () => UddfFillWriters.writeFills(builder, fills),
    );
    return builder.buildDocument().rootElement;
  }

  XmlElement wrap(String fillsXml) =>
      XmlDocument.parse('<submersion>$fillsXml</submersion>').rootElement;

  test('writes one fill element per fill in SI, in the given order', () {
    final root = submersion([full, bare]);
    final fills = root
        .findElements('cylinderfills')
        .single
        .findElements('fill')
        .toList();
    expect(fills.map((f) => f.getAttribute('id')), [
      'fill_${full.id}',
      'fill_${bare.id}',
    ]);
    String text(XmlElement e, String name) =>
        e.findElements(name).single.innerText;
    final first = fills.first;
    expect(text(first, 'passportid'), 'pp-al80');
    expect(text(first, 'datetime'), full.filledAt.toUtc().toIso8601String());
    expect(text(first, 'o2'), '0.32');
    expect(text(first, 'he'), '0');
    expect(text(first, 'pressure'), '20684300');
    expect(text(first, 'temperature'), '295.15');
    expect(text(first, 'analyzer'), 'Analox O2EII');
    expect(text(first, 'filledby'), 'Blue Hole Dive Center');
    expect(text(first, 'source'), 'qr');
    expect(text(first, 'notes'), 'Topped off');
    // Reserved for signing; never written, like the fills CSV.
    expect(root.toXmlString(), isNot(contains('reserved')));
  });

  test('optional values are omitted when absent', () {
    final fill = submersion([bare]).findAllElements('fill').single;
    for (final name in [
      'pressure',
      'temperature',
      'analyzer',
      'filledby',
      'notes',
    ]) {
      expect(fill.findElements(name), isEmpty, reason: name);
    }
    expect(fill.findElements('source').single.innerText, 'manual');
  });

  test('no fills write no section', () {
    expect(submersion(const []).findElements('cylinderfills'), isEmpty);
  });

  test('parse returns the fills CSV keys, rounded back exactly', () {
    final rows = UddfFillWriters.parseFills(submersion([full, bare]));
    expect(rows, hasLength(2));
    final first = rows.first;
    expect(first['id'], full.id);
    expect(first['uddfId'], full.id);
    expect(first['passportId'], 'pp-al80');
    expect(first['filledAt'], DateTime(2025, 3, 15, 9, 5));
    expect(first['o2Percent'], 32.0);
    expect(first['hePercent'], 0.0);
    expect(first['pressureBar'], 206.843);
    expect(first['temperatureC'], 22.0);
    expect(first['analyzer'], 'Analox O2EII');
    expect(first['stationName'], 'Blue Hole Dive Center');
    expect(first['source'], 'qr');
    expect(first['notes'], 'Topped off');
    expect(rows[1]['hePercent'], 45.0);
    expect(rows[1].containsKey('pressureBar'), isFalse);
  });

  test('a parsed row is a fill CsvFillImporter accepts unchanged', () {
    final parsed = UddfFillWriters.parseFills(submersion([full]));
    final fill = CsvFillImporter.fromPayload(parsed.single)!;
    expect(fill.id, full.id);
    expect(fill.o2Percent, 32);
    expect(fill.pressureBar, 206.843);
    expect(fill.temperatureC, 22);
    expect(fill.source, FillSource.qr);
  });

  test('a fill missing its id, passport id, time or O2 is dropped', () {
    const ok =
        '<passportid>pp</passportid>'
        '<datetime>2026-10-01T14:05:00Z</datetime><o2>0.32</o2>';
    final rows = UddfFillWriters.parseFills(
      wrap(
        '<cylinderfills>'
        '<fill>$ok</fill>'
        '<fill id="fill_a"><datetime>2026-10-01T14:05:00Z</datetime>'
        '<o2>0.32</o2></fill>'
        '<fill id="fill_b"><passportid>pp</passportid>'
        '<datetime>yesterday</datetime><o2>0.32</o2></fill>'
        '<fill id="fill_c"><passportid>pp</passportid>'
        '<datetime>2026-10-01T14:05:00Z</datetime></fill>'
        '<fill id="fill_d">$ok</fill>'
        '</cylinderfills>',
      ),
    );
    expect(rows.map((r) => r['id']), ['d']);
  });

  test('an unreadable helium value drops the fill; a blank one is none', () {
    const base =
        '<passportid>pp</passportid>'
        '<datetime>2026-10-01T14:05:00Z</datetime><o2>0.21</o2>';
    final rows = UddfFillWriters.parseFills(
      wrap(
        '<cylinderfills>'
        '<fill id="fill_bad">$base<he>bad</he></fill>'
        '<fill id="fill_blank">$base<he> </he></fill>'
        '</cylinderfills>',
      ),
    );
    expect(rows.map((r) => r['id']), ['blank']);
    expect(rows.single['hePercent'], 0.0);
  });

  test('a zoneless time is read as local wall clock', () {
    final rows = UddfFillWriters.parseFills(
      wrap(
        '<cylinderfills><fill id="fill_z"><passportid>pp</passportid>'
        '<datetime>2026-10-01T14:05:00</datetime><o2>0.32</o2></fill>'
        '</cylinderfills>',
      ),
    );
    expect(rows.single['filledAt'], DateTime(2026, 10, 1, 14, 5));
  });

  test('O2 written as a percent is refused, never stored as 3200 %', () {
    final rows = UddfFillWriters.parseFills(
      wrap(
        '<cylinderfills><fill id="fill_p"><passportid>pp</passportid>'
        '<datetime>2026-10-01T14:05:00Z</datetime><o2>32</o2></fill>'
        '</cylinderfills>',
      ),
    );
    expect(CsvFillImporter.fromPayload(rows.single), isNull);
  });
}
