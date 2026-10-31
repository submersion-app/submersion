import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_source_attribution.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank_pressure_export.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:xml/xml.dart';

import '../../../../helpers/tank_pressure_export_fixtures.dart';

/// Issue #2492: a UDDF backup recorded no source for a tank pressure series,
/// so a restore wrote every source's readings of a cylinder into one series
/// and interleaved them again (the #2440 zigzag). Nor did it record which
/// source and computer each tank row came from (#2716).
void main() {
  const tank = DiveTank(
    id: 'tank-1',
    gasMix: GasMix(o2: 32),
    sourceId: 'src-primary',
    computerId: 'comp-a',
  );
  // The other source's copy of a stage, and a hand-added tank with neither.
  const otherTank = DiveTank(
    id: 'tank-2',
    gasMix: GasMix(o2: 50),
    order: 1,
    sourceId: 'src-other',
    computerId: 'comp-b',
  );
  const handAdded = DiveTank(id: 'tank-3', gasMix: GasMix(), order: 2);

  final dive = Dive(
    id: 'dive-a',
    diveNumber: 1,
    dateTime: DateTime.utc(2026, 3, 1, 9),
    tanks: const [tank, otherTank, handAdded],
    profile: const [
      DiveProfilePoint(timestamp: 0, depth: 0),
      DiveProfilePoint(timestamp: 10, depth: 12),
      DiveProfilePoint(timestamp: 20, depth: 12),
    ],
  );

  DiveSourceExport source(
    String id,
    int ordinal, {
    bool primary = false,
    String? computerId,
  }) => DiveSourceExport(
    id: id,
    diveId: 'dive-a',
    ordinal: ordinal,
    isPrimary: primary,
    importedAt: DateTime.utc(2026, 3, 1, 12),
    createdAt: DateTime.utc(2026, 3, 1, 12),
    sourceFileName: '$id.uddf',
    computerId: computerId,
  );

  // Two recordings of one dive, consolidated: both logged the cylinder,
  // one second apart, and the primary is the second import.
  final sources = [
    source('src-primary', 0, primary: true, computerId: 'comp-a'),
    source('src-other', 1, computerId: 'comp-b'),
  ];
  final pressures = {
    'dive-a': DiveTankPressureExport(
      primarySourceId: 'src-primary',
      series: [
        testTankSeries(
          's-other',
          diveId: 'dive-a',
          tankId: 'tank-1',
          sourceId: 'src-other',
          computerId: 'comp-b',
          samples: [(1, 201.5), (11, 191.5), (21, 181.5)],
        ),
        testTankSeries(
          's-primary',
          diveId: 'dive-a',
          tankId: 'tank-1',
          sourceId: 'src-primary',
          samples: [(0, 200), (10, 190), (20, 180)],
        ),
        // A legacy series v241 could not attribute; still backed up.
        testTankSeries(
          's-legacy',
          diveId: 'dive-a',
          tankId: 'tank-1',
          sourceId: null,
          samples: [(30, 170.25)],
        ),
      ],
    ),
  };

  List<XmlElement> seriesIn(String xml) => XmlDocument.parse(xml)
      .findAllElements('tankpressureseries')
      .expand((b) => b.findElements('series'))
      .toList();

  Future<String> divesExport({
    UddfExportOptions options = const UddfExportOptions(),
  }) => UddfExportService().generateDivesUddfContent(
    [dive],
    diveTankPressures: pressures,
    dataSources: sources,
    options: options,
  );

  Future<String> fullExport() =>
      UddfFullExportService().generateAllDataXmlForTest(
        dives: [dive],
        diveTankPressures: pressures,
        dataSources: sources,
      );

  for (final (name, generate) in [
    ('dives-only export', () => divesExport()),
    ('full backup', fullExport),
  ]) {
    group(name, () {
      test('writes every series with the ordinal of its source', () async {
        final written = seriesIn(await generate());

        expect(
          [
            for (final s in written)
              (
                s.getAttribute('diveref'),
                s.getAttribute('tankref'),
                s.getAttribute('source'),
                s.getAttribute('computer'),
                [
                  for (final sample in s.findElements('sample'))
                    '${sample.getAttribute('divetime')}:'
                        '${sample.getAttribute('pressure')}',
                ].join(' '),
              ),
          ],
          [
            (
              'dive_dive-a',
              'tank_tank-1',
              '1',
              '1',
              '1:201.5 11:191.5 21:181.5',
            ),
            (
              'dive_dive-a',
              'tank_tank-1',
              '0',
              null,
              '0:200.0 10:190.0 20:180.0',
            ),
            ('dive_dive-a', 'tank_tank-1', null, null, '30:170.25'),
          ],
        );
      });

      test('writes the displayed series, not both, in the samples', () async {
        // Another app reading the file sees one curve, the primary's.
        final waypoints = XmlDocument.parse(
          await generate(),
        ).findAllElements('waypoint');

        expect(
          [
            for (final w in waypoints)
              for (final p in w.findElements('tankpressure'))
                (
                  w.getElement('divetime')!.innerText,
                  double.parse(p.innerText) / 100000,
                ),
          ],
          [('0', 200.0), ('10', 190.0), ('20', 180.0)],
        );
      });

      test('writes the source and computer of each tank row', () async {
        // Each as the ordinal of a <source> of the dive: the computer as one
        // that computer recorded, whose restored computer it then takes.
        final tanks = XmlDocument.parse(
          await generate(),
        ).findAllElements('tanksources').expand((b) => b.findElements('tank'));

        expect(
          [
            for (final t in tanks)
              (
                t.getAttribute('diveref'),
                t.getAttribute('tankref'),
                t.getAttribute('source'),
                t.getAttribute('computer'),
              ),
          ],
          [
            ('dive_dive-a', 'tank_tank-1', '0', '0'),
            ('dive_dive-a', 'tank_tank-2', '1', '1'),
          ],
        );
      });

      test('parses the tank rows back into the dive', () async {
        final parsed = await ExportService().importAllDataFromUddf(
          await generate(),
        );
        final entries =
            parsed.dives.single['tankSources'] as List<Map<String, dynamic>>;

        expect(
          [
            for (final e in entries)
              (e['tankRef'], e['sourceOrdinal'], e['computerOrdinal']),
          ],
          [('tank_tank-1', 0, 0), ('tank_tank-2', 1, 1)],
        );
      });

      test('parses back into the dive with its source ordinals', () async {
        final parsed = await ExportService().importAllDataFromUddf(
          await generate(),
        );
        final entries =
            parsed.dives.single['tankPressureSeries']
                as List<Map<String, dynamic>>;

        expect(
          [
            for (final e in entries)
              (
                e['tankRef'],
                e['sourceOrdinal'],
                e['computerOrdinal'],
                [
                  for (final s
                      in e['samples']
                          as List<({int timestamp, double pressure})>)
                    '${s.timestamp}:${s.pressure}',
                ].join(' '),
              ),
          ],
          [
            ('tank_tank-1', 1, 1, '1:201.5 11:191.5 21:181.5'),
            ('tank_tank-1', 0, null, '0:200.0 10:190.0 20:180.0'),
            ('tank_tank-1', null, null, '30:170.25'),
          ],
        );
      });
    });
  }

  // Issue #3917: a dive with fewer than two sources has only one source to
  // restore its series under, so nothing needs telling apart, but the
  // samples are a projection onto the depth clock and cannot always hold
  // what was recorded.
  group('a dive with fewer than two sources', () {
    final lone = [sources.first];

    Map<String, DiveTankPressureExport> recorded(List<(int, double)> samples) =>
        {
          'dive-a': DiveTankPressureExport(
            primarySourceId: 'src-primary',
            series: [
              testTankSeries(
                's-primary',
                diveId: 'dive-a',
                tankId: 'tank-1',
                sourceId: 'src-primary',
                computerId: 'comp-a',
                samples: samples,
              ),
            ],
          ),
        };

    String samplesOf(XmlElement series) => [
      for (final sample in series.findElements('sample'))
        '${sample.getAttribute('divetime')}:'
            '${sample.getAttribute('pressure')}',
    ].join(' ');

    for (final (name, generate)
        in <
          (
            String,
            Future<String> Function(
              Dive,
              Map<String, DiveTankPressureExport>,
              List<DiveSourceExport>,
            ),
          )
        >[
          (
            'dives-only export',
            (d, p, s) => UddfExportService().generateDivesUddfContent(
              [d],
              diveTankPressures: p,
              dataSources: s,
            ),
          ),
          (
            'full backup',
            (d, p, s) => UddfFullExportService().generateAllDataXmlForTest(
              dives: [d],
              diveTankPressures: p,
              dataSources: s,
            ),
          ),
        ]) {
      group(name, () {
        test('writes a series no depth sample lines up with', () async {
          // Five seconds from every depth sample: the samples hold nothing.
          final xml = await generate(
            dive,
            recorded([(5, 199), (15, 191)]),
            lone,
          );

          final written = seriesIn(xml).single;
          expect(written.getAttribute('source'), '0');
          expect(written.getAttribute('computer'), '0');
          expect(samplesOf(written), '5:199.0 15:191.0');
          expect(
            XmlDocument.parse(xml).findAllElements('tankpressure'),
            isEmpty,
          );
          // One source owns every tank, so the tank rows stay unwritten.
          expect(xml, isNot(contains('<tanksources>')));
        });

        test('keeps the time of a reading the samples would move', () async {
          final xml = await generate(dive, recorded([(9, 195)]), lone);

          expect(samplesOf(seriesIn(xml).single), '9:195.0');
        });

        test('keeps a series the samples would repeat', () async {
          // Depth every second: each reading is near several depth samples,
          // so the samples alone come back as a staircase of copies.
          final everySecond = dive.copyWith(
            profile: [
              for (var t = 0; t <= 20; t++)
                DiveProfilePoint(timestamp: t, depth: 12),
            ],
          );

          final xml = await generate(
            everySecond,
            recorded([(0, 200), (10, 190), (20, 180)]),
            lone,
          );

          expect(samplesOf(seriesIn(xml).single), '0:200.0 10:190.0 20:180.0');
        });

        test('keeps a series of a dive with no depth samples', () async {
          final xml = await generate(
            dive.copyWith(profile: const []),
            recorded([(5, 199)]),
            lone,
          );

          expect(samplesOf(seriesIn(xml).single), '5:199.0');
        });

        test('writes no series the samples hold exactly', () async {
          // Readings on depth samples, even only some of them, come back
          // from the samples unchanged.
          final xml = await generate(
            dive,
            recorded([(0, 200), (10, 190)]),
            lone,
          );

          expect(seriesIn(xml), isEmpty);
        });

        test('writes the series with no source in the file', () async {
          final xml = await generate(dive, recorded([(5, 199)]), const []);

          final written = seriesIn(xml).single;
          expect(written.getAttribute('source'), isNull);
          expect(written.getAttribute('computer'), isNull);
          expect(samplesOf(written), '5:199.0');
        });

        test('parses the series back into the dive', () async {
          final parsed = await ExportService().importAllDataFromUddf(
            await generate(dive, recorded([(5, 199), (15, 191)]), const []),
          );
          final entries =
              parsed.dives.single['tankPressureSeries']
                  as List<Map<String, dynamic>>;

          expect(entries.single['samples'], const [
            (timestamp: 5, pressure: 199.0),
            (timestamp: 15, pressure: 191.0),
          ]);
        });
      });
    }

    test('writes only the series the app draws of two recordings', () async {
      // With the sources left out a restore has one source to give them
      // all to, and two recordings of one stretch under one source would
      // zigzag again (#2440). The legacy reading lies past the last depth
      // sample, so what the app draws goes in the block and nothing else.
      final xml = await divesExport(
        options: const UddfExportOptions(includeRawData: false),
      );

      final written = seriesIn(xml);
      expect(written.map(samplesOf), [
        '0:200.0 10:190.0 20:180.0',
        '30:170.25',
      ]);
      expect(written.map((s) => s.getAttribute('source')), [null, null]);
    });
  });

  group('gas switch computers', () {
    GasSwitchWithTank gasSwitch(int timestamp, String? computer) =>
        GasSwitchWithTank(
          gasSwitch: GasSwitch(
            id: 'switch-$timestamp',
            diveId: 'dive-a',
            timestamp: timestamp,
            tankId: 'tank-2',
            createdAt: DateTime.utc(2026, 3, 1, 12),
            computerId: computer,
          ),
          tankName: 'Stage',
          gasMix: 'EAN50',
          o2Fraction: 0.5,
        );

    final switches = {
      'dive-a': [
        gasSwitch(0, 'comp-a'),
        gasSwitch(30, 'comp-b'),
        // Entered by hand, and logged by a computer no source of this dive
        // recorded: neither has a <source> to point at.
        gasSwitch(60, null),
        gasSwitch(90, 'comp-gone'),
      ],
    };

    Future<String> backup(List<DiveSourceExport> sources) =>
        UddfFullExportService().generateAllDataXmlForTest(
          dives: [dive],
          dataSources: sources,
          diveGasSwitches: switches,
        );

    Future<String> divesOnly(List<DiveSourceExport> sources) =>
        UddfExportService().generateDivesUddfContent(
          [dive],
          dataSources: sources,
          extras: UddfDivesExtras(diveGasSwitches: switches),
        );

    List<(String?, String?)> computersIn(String xml) => [
      for (final gs in XmlDocument.parse(xml).findAllElements('gasswitch'))
        (
          gs.getElement('time')?.innerText,
          gs.getElement('computer')?.innerText,
        ),
    ];

    for (final (name, generate) in [
      ('full backup', backup),
      ('dives-only export', divesOnly),
    ]) {
      group(name, () {
        test('names the ordinal of a source that computer recorded', () async {
          expect(computersIn(await generate(sources)), [
            ('0', '0'),
            ('30', '1'),
            ('60', null),
            ('90', null),
          ]);
        });

        test('names it on a dive with a single source too', () async {
          // A lone source adopts the pressure series and tanks a restore cannot
          // place, but a switch with no computer applies to every computer.
          expect(computersIn(await generate([sources.first])), [
            ('0', '0'),
            ('30', null),
            ('60', null),
            ('90', null),
          ]);
        });

        test('parses each switch back with its ordinal', () async {
          final parsed = await ExportService().importAllDataFromUddf(
            await generate(sources),
          );
          final entries =
              parsed.dives.single['gasSwitches'] as List<Map<String, dynamic>>;

          expect(
            [for (final e in entries) (e['timestamp'], e['computerOrdinal'])],
            [(0, 0), (30, 1), (60, null), (90, null)],
          );
        });
      });
    }

    test('the dives-only export writes a trimix switch in full', () async {
      final trimix = GasSwitchWithTank(
        gasSwitch: GasSwitch(
          id: 'switch-trimix',
          diveId: 'dive-a',
          timestamp: 30,
          tankId: 'tank-2',
          depth: 21.5,
          createdAt: DateTime.utc(2026, 3, 1, 12),
        ),
        tankName: 'Stage',
        gasMix: '18/45',
        o2Fraction: 0.18,
        heFraction: 0.45,
      );
      final xml = await UddfExportService().generateDivesUddfContent(
        [dive],
        extras: UddfDivesExtras(
          diveGasSwitches: {
            'dive-a': [trimix],
          },
        ),
      );

      final written = XmlDocument.parse(
        xml,
      ).findAllElements('gasswitch').single;
      expect(written.getElement('depth')?.innerText, '21.5');
      expect(written.getElement('o2fraction')?.innerText, '0.18');
      expect(written.getElement('hefraction')?.innerText, '0.45');
    });

    test('names none when the sources are left out', () async {
      final xml = await UddfFullExportService().generateAllDataXmlForTest(
        dives: [dive],
        dataSources: sources,
        diveGasSwitches: switches,
        options: const UddfExportOptions(includeRawData: false),
      );

      expect(xml, isNot(contains('<computer>')));
    });

    test('the dives-only export names none without the sources', () async {
      final xml = await UddfExportService().generateDivesUddfContent(
        [dive],
        dataSources: sources,
        extras: UddfDivesExtras(diveGasSwitches: switches),
        options: const UddfExportOptions(includeRawData: false),
      );

      expect(xml, contains('<gasswitch>'));
      expect(xml, isNot(contains('<computer>')));
    });
  });

  test('skips rows that name nothing it could restore', () {
    // Untrusted input: a row with no dive or tank ref, a series with no
    // readable sample, a reading that is no number of bar (NaN and
    // Infinity both parse as doubles), and a tank row naming neither
    // source nor computer.
    final uddf = XmlDocument.parse('''
<uddf>
  <applicationdata>
    <submersion>
      <tanksources>
        <tank diveref="dive_a" tankref="tank_1" source="0"/>
        <tank diveref="dive_a" tankref="tank_2"/>
        <tank tankref="tank_3" source="1"/>
      </tanksources>
      <tankpressureseries>
        <series diveref="dive_a" tankref="tank_1" source="x">
          <sample divetime="0" pressure="200"/>
          <sample divetime="ten" pressure="190"/>
          <sample divetime="5" pressure="NaN"/>
          <sample divetime="6" pressure="Infinity"/>
        </series>
        <series diveref="dive_a" tankref="tank_2">
          <sample divetime="0" pressure="high"/>
        </series>
        <series diveref="dive_a">
          <sample divetime="0" pressure="200"/>
        </series>
      </tankpressureseries>
    </submersion>
  </applicationdata>
</uddf>''').rootElement;

    expect(UddfSourceAttribution.parseTanks(uddf), {
      'dive_a': [
        {'tankRef': 'tank_1', 'sourceOrdinal': 0, 'computerOrdinal': null},
      ],
    });
    final series = UddfSourceAttribution.parseSeries(uddf);
    expect(series.keys, ['dive_a']);
    expect(series['dive_a'], hasLength(1));
    expect(series['dive_a']!.single['tankRef'], 'tank_1');
    // An unreadable ordinal is no ordinal, not a guess.
    expect(series['dive_a']!.single['sourceOrdinal'], isNull);
    expect(series['dive_a']!.single['samples'], const [
      (timestamp: 0, pressure: 200.0),
    ]);
  });
}
