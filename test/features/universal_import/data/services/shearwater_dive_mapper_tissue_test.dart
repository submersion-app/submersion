import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_log/domain/entities/computer_tissue_snapshot.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_dive_mapper.dart';

void main() {
  ComputerTissueSnapshot? tissueOf(Map<String, dynamic> dive) =>
      ComputerTissueSnapshot.from(dive['computerTissue']);

  pigeon.ParsedDive parsedWithSamples(List<int> times) => pigeon.ParsedDive(
    fingerprint: '',
    dateTimeYear: 2026,
    dateTimeMonth: 8,
    dateTimeDay: 1,
    dateTimeHour: 9,
    dateTimeMinute: 8,
    dateTimeSecond: 48,
    maxDepthMeters: 40,
    avgDepthMeters: 25,
    durationSeconds: times.isEmpty ? 0 : times.last,
    samples: [
      for (final t in times)
        pigeon.ProfileSample(timeSeconds: t, depthMeters: 20.0),
    ],
    tanks: [],
    gasMixes: [],
    events: [],
  );

  group('ShearwaterDiveMapper computer tissue', () {
    test('builds the snapshot from the dive_logs header and EndGF99', () {
      const rawDive = ShearwaterRawDive(
        diveId: 'tissue',
        endGF99: 58,
        decoModel: 'VPM-B/GFS',
        startGFS: 18,
        startCNS: 4,
        endCNS: 21,
      );

      final tissue = tissueOf(ShearwaterDiveMapper.mapDiveMetadata(rawDive));
      expect(tissue, isNotNull);
      expect(tissue!.algorithm, 'VPM-B/GFS');
      expect(tissue.start?.surfaceGfPercent, 18.0);
      expect(tissue.start?.cnsPercent, 4.0);
      expect(tissue.end?.gf99Percent, 58.0);
      expect(tissue.end?.cnsPercent, 21.0);
    });

    test('prefers the EndGF99 derived from the samples over a 0.0 '
        'dive_details placeholder', () {
      const rawDive = ShearwaterRawDive(
        diveId: 'placeholder',
        endGF99: 0.0,
        calculatedValues: {'EndGF99': 62.0},
      );

      final tissue = tissueOf(ShearwaterDiveMapper.mapDiveMetadata(rawDive));
      expect(tissue?.end?.gf99Percent, 62.0);
    });

    test('falls back to dive_details.EndGF99 when no calculated value', () {
      const rawDive = ShearwaterRawDive(diveId: 'details-only', endGF99: 41);

      final tissue = tissueOf(ShearwaterDiveMapper.mapDiveMetadata(rawDive));
      expect(tissue?.end?.gf99Percent, 41.0);
      expect(tissue?.start, isNull);
      expect(tissue?.algorithm, isNull);
    });

    test('falls back to the last gf99 sample when neither summary is set', () {
      const rawDive = ShearwaterRawDive(
        diveId: 'series-only',
        endGF99: 0.0,
        gf99Samples: [
          ShearwaterGf99Sample(timeSeconds: 0, gf99: 3),
          ShearwaterGf99Sample(timeSeconds: 10, gf99: 55),
        ],
      );

      final tissue = tissueOf(ShearwaterDiveMapper.mapDiveMetadata(rawDive));
      expect(tissue?.end?.gf99Percent, 55.0);
    });

    test('omits the snapshot when no tissue value is present', () {
      const rawDive = ShearwaterRawDive(diveId: 'none', endGF99: 0.0);

      final dive = ShearwaterDiveMapper.mapDiveMetadata(rawDive);
      expect(dive.containsKey('computerTissue'), isFalse);
    });

    test('omits the end state when only start values are present', () {
      const rawDive = ShearwaterRawDive(diveId: 'start-only', startGFS: 12);

      final tissue = tissueOf(ShearwaterDiveMapper.mapDiveMetadata(rawDive));
      expect(tissue?.start?.surfaceGfPercent, 12.0);
      expect(tissue?.end, isNull);
    });

    test('carries gfMin/gfMax as gradient factors in the metadata map', () {
      const rawDive = ShearwaterRawDive(diveId: 'gf', gfMin: 30, gfMax: 70);

      final dive = ShearwaterDiveMapper.mapDiveMetadata(rawDive);
      expect(dive['gradientFactorLow'], 30);
      expect(dive['gradientFactorHigh'], 70);
    });

    test('leaves the gradient factor keys out when dive_logs has none', () {
      const rawDive = ShearwaterRawDive(diveId: 'no-gf');

      final dive = ShearwaterDiveMapper.mapDiveMetadata(rawDive);
      expect(dive.containsKey('gradientFactorLow'), isFalse);
      expect(dive.containsKey('gradientFactorHigh'), isFalse);
    });
  });

  group('ShearwaterDiveMapper.mergeWithParsedDive gf99 alignment', () {
    test('sets gf99 on the libdivecomputer samples by nearest time', () {
      const series = [
        ShearwaterGf99Sample(timeSeconds: 0, gf99: 2),
        ShearwaterGf99Sample(timeSeconds: 11, gf99: 20),
        ShearwaterGf99Sample(timeSeconds: 30, gf99: 62),
      ];
      final merged = ShearwaterDiveMapper.mergeWithParsedDive(
        {'profile': const <Map<String, dynamic>>[]},
        parsedWithSamples([0, 10, 20, 30]),
        gf99Samples: series,
      );

      final profile = merged['profile'] as List<Map<String, dynamic>>;
      expect(profile.map((p) => p['gf99']), [2, 20, null, 62]);
      expect(profile[2].containsKey('gf99'), isFalse);
    });

    test('leaves samples without gf99 when the series is empty', () {
      final merged = ShearwaterDiveMapper.mergeWithParsedDive({
        'profile': const <Map<String, dynamic>>[],
      }, parsedWithSamples([0, 10]));

      final profile = merged['profile'] as List<Map<String, dynamic>>;
      expect(profile.any((p) => p.containsKey('gf99')), isFalse);
    });

    test('the last aligned gf99 agrees with the end snapshot', () {
      const rawDive = ShearwaterRawDive(
        diveId: 'agree',
        calculatedValues: {'EndGF99': 62.0},
        gf99Samples: [
          ShearwaterGf99Sample(timeSeconds: 0, gf99: 5),
          ShearwaterGf99Sample(timeSeconds: 10, gf99: 30),
          ShearwaterGf99Sample(timeSeconds: 20, gf99: 62),
        ],
      );
      final merged = ShearwaterDiveMapper.mergeWithParsedDive(
        ShearwaterDiveMapper.mapDiveMetadata(rawDive),
        parsedWithSamples([0, 10, 20]),
        gf99Samples: rawDive.gf99Samples,
      );

      final profile = merged['profile'] as List<Map<String, dynamic>>;
      final lastGf99 = profile.reversed
          .map((p) => p['gf99'] as int?)
          .firstWhere((v) => v != null);
      expect(lastGf99, 62);
      expect(tissueOf(merged)?.end?.gf99Percent, closeTo(lastGf99!, 1.0));
    });
  });

  group('committed CCR fixture', () {
    test('maps EndGF99 62 into computerTissue.end', () async {
      final bytes = File(
        'test/dives/100_shearwater_cloud_export_with_one_ccr_dive.db.export',
      ).readAsBytesSync();
      final rawDive = (await ShearwaterDbReader.readDives(bytes)).single;

      final tissue = tissueOf(ShearwaterDiveMapper.mapDiveMetadata(rawDive));
      expect(tissue?.end?.gf99Percent, 62.0);
      // The export carries no dive_logs row, so there is no start state.
      expect(tissue?.start, isNull);
      expect(tissue?.algorithm, isNull);
    });
  });
}
