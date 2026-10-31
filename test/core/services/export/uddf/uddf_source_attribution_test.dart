import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_source_attribution.dart';
import 'package:submersion/features/dive_import/data/services/restored_source_attribution.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank_pressure_export.dart';
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

  test('writes no series for a dive with a single source', () async {
    // A lone restored source owns every series unambiguously, so the
    // samples already say everything a restore needs.
    final xml = await UddfExportService().generateDivesUddfContent(
      [dive],
      diveTankPressures: pressures,
      dataSources: [sources.first],
    );

    expect(seriesIn(xml), isEmpty);
    expect(xml, isNot(contains('<tanksources>')));
  });

  test('writes no series when the sources are left out', () async {
    // Without <source> entries a restore creates one source for the dive,
    // so the series would collapse into one interleaved recording anyway.
    final xml = await divesExport(
      options: const UddfExportOptions(includeRawData: false),
    );

    expect(seriesIn(xml), isEmpty);
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

  /// Issue #3965: `<samples>` holds every source's depth readings interleaved,
  /// and a waypoint names no source, so a restore gave them all to the primary.
  group('sourceprofiles', () {
    const samples = [
      ProfileSample(timestamp: 10, depth: 0, pressure: 199.5),
      ProfileSample(
        timestamp: 40,
        depth: 20.25,
        temperature: 14.7,
        heartRateSource: 'watch',
        gf99: 40,
      ),
    ];

    final blob = const ProfileSeriesCodec().encode(samples).bytes;

    SourceSeriesExport series({
      String? sourceId,
      String? computerId,
      bool isPrimary = false,
    }) => SourceSeriesExport(
      blob: blob,
      sourceId: sourceId,
      computerId: computerId,
      isPrimary: isPrimary,
    );

    DiveSourceExport withSeries(
      String id,
      int ordinal,
      List<SourceSeriesExport> profileSeries, {
      String? computerId,
    }) => DiveSourceExport(
      id: id,
      diveId: 'dive-a',
      ordinal: ordinal,
      isPrimary: ordinal == 0,
      importedAt: DateTime.utc(2026, 3, 1, 12),
      createdAt: DateTime.utc(2026, 3, 1, 12),
      computerId: computerId,
      profileSeries: profileSeries,
    );

    final owned = [
      withSeries('src-primary', 0, [
        series(sourceId: 'src-primary', isPrimary: true, computerId: 'comp-a'),
        // A Combine's surface filler, held here but owned by no source.
        series(isPrimary: true),
      ], computerId: 'comp-a'),
      withSeries('src-other', 1, [
        series(sourceId: 'src-other'),
      ], computerId: 'comp-b'),
    ];

    Future<String> divesOnly(List<DiveSourceExport> sources) =>
        UddfExportService().generateDivesUddfContent([
          dive,
        ], dataSources: sources);

    Future<String> full(List<DiveSourceExport> sources) =>
        UddfFullExportService().generateAllDataXmlForTest(
          dives: [dive],
          dataSources: sources,
        );

    for (final (name, generate) in [
      ('dives-only export', divesOnly),
      ('full backup', full),
    ]) {
      group(name, () {
        test('names the source, computer and flag of each series', () async {
          final xml = await generate(owned);
          final written = XmlDocument.parse(xml)
              .findAllElements('sourceprofiles')
              .expand((block) => block.findElements('series'));

          expect(
            [
              for (final s in written)
                (
                  s.getAttribute('diveref'),
                  s.getAttribute('source'),
                  s.getAttribute('computer'),
                  s.getAttribute('primary'),
                ),
            ],
            [
              ('dive_dive-a', '0', '0', 'true'),
              ('dive_dive-a', null, null, 'true'),
              ('dive_dive-a', '1', null, 'false'),
            ],
          );
        });

        test('parses back every field of every sample', () async {
          final uddf = XmlDocument.parse(await generate(owned)).rootElement;

          final parsed = UddfSourceAttribution.parseProfiles(uddf);

          expect(parsed.keys, ['dive_dive-a']);
          final restored = restoredProfileSeries({
            UddfSourceAttribution.profilesKey: parsed['dive_dive-a'],
          });
          expect(
            [
              for (final s in restored)
                (s.sourceOrdinal, s.computerOrdinal, s.isPrimary),
            ],
            [(0, 0, true), (null, null, true), (1, null, false)],
          );
          for (final s in restored) {
            expect(s.samples, samples);
          }
        });

        test('writes no block when no source owns a series', () async {
          final xml = await generate([
            withSeries('src-primary', 0, const []),
            withSeries('src-other', 1, const []),
          ]);

          expect(xml, isNot(contains('sourceprofiles')));
        });

        test('writes no block for a lone source', () async {
          final xml = await generate([
            withSeries('src-primary', 0, [series(isPrimary: true)]),
          ]);

          expect(xml, isNot(contains('sourceprofiles')));
        });
      });
    }

    test('is written with no tank series beside it', () async {
      final xml = await divesOnly(owned);

      expect(xml, isNot(contains('tankpressureseries')));
      expect(xml, contains('<sourceprofiles>'));
    });

    XmlElement document(String body) => XmlDocument.parse('''<uddf>
  <applicationdata>
    <submersion>
      <sourceprofiles>$body</sourceprofiles>
    </submersion>
  </applicationdata>
</uddf>''').rootElement;

    final encoded = base64Encode(blob);

    test('reads an unreadable ordinal as no ordinal', () {
      final parsed = UddfSourceAttribution.parseProfiles(
        document('<series diveref="dive_a" source="one">$encoded</series>'),
      );

      expect(parsed['dive_a']!.single['sourceOrdinal'], isNull);
      expect(parsed['dive_a']!.single['isPrimary'], isFalse);
    });

    test('skips a series naming no dive', () {
      expect(
        UddfSourceAttribution.parseProfiles(
          document('<series source="0">$encoded</series>'),
        ),
        isEmpty,
      );
    });

    for (final (name, body) in [
      ('not base64', 'not-a-series!'),
      ('not a series', base64Encode(utf8.encode('plain text'))),
      ('empty', ''),
    ]) {
      test('restores no series of a dive with one that is $name', () {
        final parsed = UddfSourceAttribution.parseProfiles(
          document(
            '<series diveref="dive_a" source="0">$encoded</series>'
            '<series diveref="dive_a" source="1">$body</series>',
          ),
        );

        expect(
          restoredProfileSeries({
            UddfSourceAttribution.profilesKey: parsed['dive_a'],
          }),
          isEmpty,
        );
      });
    }
  });
}
