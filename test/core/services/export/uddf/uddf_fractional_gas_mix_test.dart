import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_import_parsers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:xml/xml.dart';

/// Issue #3967: a mix's UDDF id was built from its truncated percentages, so
/// 32.1% and 32.9% shared `mix_32_0`, the later definition replaced the
/// earlier one, and both cylinders restored with the same gas.
void main() {
  Dive diveBreathing(List<GasMix> mixes) => Dive(
    id: 'dive-a',
    diveNumber: 1,
    dateTime: DateTime.utc(2026, 3, 1, 9),
    tanks: [
      for (final (index, mix) in mixes.indexed)
        DiveTank(id: 'tank-$index', gasMix: mix, order: index),
    ],
    profile: const [
      DiveProfilePoint(timestamp: 10, depth: 4.5),
      DiveProfilePoint(timestamp: 60, depth: 12.0),
    ],
  );

  /// Each `<mix>` in the file, by id.
  Map<String, GasMix> definitionsIn(String xml) => {
    for (final mix in XmlDocument.parse(xml).findAllElements('mix'))
      mix.getAttribute('id')!: UddfImportParsers.parseGasMix(mix),
  };

  /// The definition each `<tankdata>` links to, in cylinder order.
  List<GasMix?> linkedMixesIn(String xml) {
    final definitions = definitionsIn(xml);
    return [
      for (final tank in XmlDocument.parse(xml).findAllElements('tankdata'))
        definitions[tank.getElement('link')?.getAttribute('ref')],
    ];
  }

  final exporters = <String, Future<String> Function(List<Dive>)>{
    'full backup': (dives) =>
        UddfFullExportService().generateAllDataXmlForTest(dives: dives),
    'dives-only export': (dives) =>
        UddfExportService().generateDivesUddfContent(dives),
  };

  for (final MapEntry(key: name, value: export) in exporters.entries) {
    group(name, () {
      Future<String> write(List<GasMix> mixes) =>
          export([diveBreathing(mixes)]);

      test('keeps oxygen fractions that truncate alike apart', () async {
        const mixes = [GasMix(o2: 32.1), GasMix(o2: 32.9)];

        expect(linkedMixesIn(await write(mixes)), mixes);
      });

      test('the mix met last does not win', () async {
        const mixes = [GasMix(o2: 32.9), GasMix(o2: 32.1)];

        expect(linkedMixesIn(await write(mixes)), mixes);
      });

      test('keeps helium fractions that truncate alike apart', () async {
        const mixes = [GasMix(o2: 18, he: 45.2), GasMix(o2: 18, he: 45.8)];

        expect(linkedMixesIn(await write(mixes)), mixes);
      });

      test('a measured mix near air survives the default air entry', () async {
        // The forced air definition took the integer bucket's id, so a tank
        // analyzed at 21.3% came back as standard air.
        const mixes = [GasMix(o2: 21.3)];
        final xml = await write(mixes);

        expect(linkedMixesIn(xml), mixes);
        expect(definitionsIn(xml)['mix_21_0'], const GasMix());
      });

      test('old restore noise cannot fold a mix into the one below', () async {
        // 29% used to come back from a restore as 28.999999999999996, which
        // truncated into 28%'s id. Reading the file back also cleans it up.
        final xml = await write(const [
          GasMix(o2: 28),
          GasMix(o2: 28.999999999999996),
        ]);

        expect(linkedMixesIn(xml), const [GasMix(o2: 28), GasMix(o2: 29)]);
      });

      test('binary noise on a logged gas does not make it a new mix', () async {
        // The native bridges compute fraction * 100.0, so a downloaded 28% can
        // be stored a few ULPs off the 28% typed in for the other cylinder.
        final xml = await write(const [
          GasMix(o2: 28),
          GasMix(o2: 28.000000000000004),
        ]);

        expect(linkedMixesIn(xml), const [GasMix(o2: 28), GasMix(o2: 28)]);
        expect(definitionsIn(xml).keys, ['mix_28_0', 'mix_21_0']);
      });

      test('writes each fraction without binary noise', () async {
        // 32.9 / 100 is 0.32899999999999996 and 100 - 32.9 is a noisy n2.
        final xml = await write(const [GasMix(o2: 32.9, he: 0.1)]);

        final mix = XmlDocument.parse(xml)
            .findAllElements('mix')
            .firstWhere((m) => m.getAttribute('id') == 'mix_32.9_0.1');
        expect(mix.getElement('o2')?.innerText, '0.329');
        expect(mix.getElement('n2')?.innerText, '0.67');
        expect(mix.getElement('he')?.innerText, '0.001');
      });

      test('two cylinders of one gas share one definition', () async {
        const mixes = [GasMix(o2: 32.1), GasMix(o2: 32.1)];
        final xml = await write(mixes);

        expect(linkedMixesIn(xml), mixes);
        expect(
          definitionsIn(xml).values.where((m) => m == mixes.first),
          hasLength(1),
        );
      });

      test('marks the start on the first cylinder\'s exact mix', () async {
        const mixes = [GasMix(o2: 32.1), GasMix(o2: 32.9)];
        final xml = await write(mixes);

        final start = XmlDocument.parse(
          xml,
        ).findAllElements('switchmix').first.getAttribute('ref');
        expect(definitionsIn(xml)[start], mixes.first);
      });

      test('a restore gets each cylinder its own exact mix', () async {
        const mixes = [
          GasMix(o2: 32.1),
          GasMix(o2: 32.9),
          GasMix(o2: 18, he: 45.2),
          GasMix(o2: 18, he: 45.8),
          GasMix(o2: 29),
        ];

        final result = await ExportService().importAllDataFromUddf(
          await write(mixes),
        );

        final tanks = result.dives.single['tanks'] as List;
        expect([for (final tank in tanks) tank['gasMix']], mixes);
      });

      test('every id is a legal XML id', () async {
        final xml = await write(const [
          GasMix(o2: 32.1),
          GasMix(o2: 18, he: 45.25),
          GasMix(o2: 1e-7),
        ]);

        expect(
          definitionsIn(xml).keys,
          everyElement(matches(RegExp(r'^[A-Za-z_][\w.-]*$'))),
        );
      });
    });
  }

  group('startMixId', () {
    String? startId(GasMix mix) =>
        UddfExportBuilders.startMixId(diveBreathing([mix]));

    test('a whole-percent mix keeps its readable id', () {
      expect(startId(const GasMix()), 'mix_21_0');
      expect(startId(const GasMix(o2: 32)), 'mix_32_0');
      expect(startId(const GasMix(o2: 18, he: 45)), 'mix_18_45');
    });

    test('a fractional mix names its exact percentages', () {
      expect(startId(const GasMix(o2: 32.1)), 'mix_32.1_0');
      expect(startId(const GasMix(o2: 18, he: 45.25)), 'mix_18_45.25');
    });
  });

  group('parseGasMix', () {
    GasMix parse(String o2, {String he = '0.0'}) =>
        UddfImportParsers.parseGasMix(
          XmlDocument.parse(
            '<mix id="m"><o2>$o2</o2><he>$he</he></mix>',
          ).rootElement,
        );

    test('restores every tenth of a percent exactly', () {
      // Multiplying the stored fraction by 100 left 93 of these, and 29%,
      // slightly off (0.29 * 100 is 28.999999999999996).
      for (var tenths = 1; tenths <= 1000; tenths++) {
        final percent = tenths / 10;
        final fraction = (percent / 100).toString();

        expect(parse(fraction).o2, percent, reason: 'o2 $fraction');
        expect(parse('0.21', he: fraction).he, percent, reason: 'he $fraction');
      }
    });

    test('keeps the precision another program wrote', () {
      expect(parse('0.32125').o2, 32.125);
    });

    test('an unreadable fraction still falls back', () {
      expect(parse('not a number', he: 'nor this'), const GasMix());
    });
  });
}
