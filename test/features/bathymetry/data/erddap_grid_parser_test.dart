import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/data/sources/erddap_grid_parser.dart';

String fixture(String name) =>
    File('test/fixtures/bathymetry/$name').readAsStringSync();

void main() {
  final when = DateTime.utc(2026, 7, 28);

  test('parses NOAA z-column body into a south-to-north grid', () {
    final g = ErddapGridParser.parse(
      fixture('etopo_bonaire.json'),
      sourceId: 'etopo2022',
      resolutionMeters: 450,
      fetchedAt: when,
    );
    expect(g.rows, 3);
    expect(g.cols, 4);
    expect(g.originLat, closeTo(12.139, 1e-9)); // southernmost first
    expect(g.originLon, closeTo(-68.310, 1e-9)); // westernmost first
    expect(g.cellSizeLatDeg, closeTo(0.004, 1e-9));
    expect(g.cellSizeLonDeg, closeTo(0.004, 1e-9));
    // Elevation -291 becomes depth +291 (positive down).
    expect(g.depthAt(0, 0), closeTo(291, 1e-9));
    // int and double values both parse.
    expect(g.depthAt(1, 2), closeTo(274.2, 1e-9));
    // Land cell: elevation +12 -> depth -12.
    expect(g.depthAt(2, 3), closeTo(-12, 1e-9));
    expect(g.sourceId, 'etopo2022');
  });

  test('parses EMODnet elevation-column body preserving nulls', () {
    final g = ErddapGridParser.parse(
      fixture('emodnet_carib.json'),
      sourceId: 'emodnet',
      resolutionMeters: 115,
      fetchedAt: when,
    );
    expect(g.rows, 3);
    expect(g.cols, 3);
    expect(g.depthAt(0, 0), isNull); // null stays null
    expect(g.depthAt(0, 1), closeTo(106.70838, 1e-6));
    expect(g.depthAt(2, 2), closeTo(352.1, 1e-9));
  });

  test('throws FormatException on empty table', () {
    expect(
      () => ErddapGridParser.parse(
        '{"table": {"columnNames": ["latitude","longitude","z"], "rows": []}}',
        sourceId: 's',
        resolutionMeters: 1,
        fetchedAt: when,
      ),
      throwsFormatException,
    );
  });

  test('throws FormatException when an axis has a single distinct value', () {
    expect(
      () => ErddapGridParser.parse(
        '{"table": {"columnNames": ["latitude","longitude","z"], "rows": '
        '[[12.1, -68.3, -10], [12.1, -68.2, -20]]}}',
        sourceId: 's',
        resolutionMeters: 1,
        fetchedAt: when,
      ),
      throwsFormatException,
    );
  });
}
