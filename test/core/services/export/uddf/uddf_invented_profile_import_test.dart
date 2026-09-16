import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../../helpers/test_database.dart';
import '../../../../helpers/uddf_restore.dart';

/// Issue #1874: before the fix, both of Submersion's UDDF writers put a
/// (0 s, 0 m) waypoint first on every dive and, for a dive with no recorded
/// samples but a duration and a greatest depth, followed it with max depth at
/// 20% of the duration, the average depth (or 0.7 x the max) at 80% and the
/// surface at 100%. Backups already written that way must stop restoring
/// that outline as the dive's profile.
///
/// The documents below are written out by hand in that old format, so these
/// tests do not depend on what the writers produce today.
String _uddf({
  String generator = 'Submersion',
  required String waypoints,
  String after =
      '<greatestdepth>25.0</greatestdepth>'
      '<averagedepth>18.0</averagedepth>'
      '<diveduration>2700</diveduration>',
}) =>
    '''
<?xml version="1.0" encoding="UTF-8"?>
<uddf version="3.2.1">
  <generator><name>$generator</name><version>1.0</version></generator>
  <gasdefinitions><mix id="mix_21_0"><name>Air</name><o2>0.21</o2><he>0.0</he></mix></gasdefinitions>
  <profiledata>
    <repetitiongroup id="rg1">
      <dive id="dive_1">
        <informationbeforedive><datetime>2026-03-01T09:00:00</datetime><divenumber>1</divenumber></informationbeforedive>
        <samples>$waypoints</samples>
        <informationafterdive>$after</informationafterdive>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';

String _wp(int time, String depth, {String extra = ''}) =>
    '<waypoint><divetime>$time</divetime><depth>$depth</depth>$extra</waypoint>';

final _start = _wp(0, '0', extra: '<switchmix ref="mix_21_0"/>');

/// 45 minutes: 20% is 540 s and 80% is 2160 s.
final _invented = [
  _start,
  _wp(540, '25.0', extra: '<temperature>295.15</temperature>'),
  _wp(2160, '18.0'),
  _wp(2700, '0'),
].join();

/// The (timestamp, depth) of each profile point a full parse produced.
Future<List<(int, double)>?> _fullParse(String xml) async {
  final dive = (await ExportService().importAllDataFromUddf(xml)).dives.single;
  final profile = dive['profile'] as List<Map<String, dynamic>>?;
  return profile
      ?.map((p) => (p['timestamp'] as int, p['depth'] as double))
      .toList();
}

/// The same from the simple dives import, which reads the same files.
Future<List<(int, double)>?> _simpleParse(String xml) async {
  final dive = (await ExportService().importDivesFromUddf(
    xml,
  ))['dives']!.single;
  final profile = dive['profile'] as List<Map<String, dynamic>>?;
  return profile
      ?.map((p) => (p['timestamp'] as int, p['depth'] as double))
      .toList();
}

void main() {
  final parsers = {'full import': _fullParse, 'simple import': _simpleParse};

  for (final MapEntry(key: name, value: parse) in parsers.entries) {
    group(name, () {
      test(
        'drops the invented outline of a dive with an average depth',
        () async {
          expect(await parse(_uddf(waypoints: _invented)), isNull);
        },
      );

      test('drops the invented outline of a dive without an average '
          'depth', () async {
        // The old writer fell back to 0.7 x the greatest depth: 17.5 m.
        final xml = _uddf(
          waypoints: [
            _start,
            _wp(540, '25.0'),
            _wp(2160, '17.5'),
            _wp(2700, '0'),
          ].join(),
          after:
              '<greatestdepth>25.0</greatestdepth>'
              '<diveduration>2700</diveduration>',
        );

        expect(await parse(xml), isNull);
      });

      test('drops a lone surface waypoint', () async {
        // A dive with no samples and no duration or depth got only this.
        expect(await parse(_uddf(waypoints: _start, after: '')), isNull);
      });

      test('keeps the same outline in a file another app wrote', () async {
        expect(await parse(_uddf(generator: 'MacDive', waypoints: _invented)), [
          (0, 0.0),
          (540, 25.0),
          (2160, 18.0),
          (2700, 0.0),
        ]);
      });

      test('keeps a four-point profile that is not the invented one', () async {
        // One depth off the formula: a real sample, not the fallback.
        final xml = _uddf(
          waypoints: [
            _start,
            _wp(540, '25.0'),
            _wp(2160, '17.0'),
            _wp(2700, '0'),
          ].join(),
        );

        expect(await parse(xml), [
          (0, 0.0),
          (540, 25.0),
          (2160, 17.0),
          (2700, 0.0),
        ]);
      });

      test('keeps a recorded profile', () async {
        final xml = _uddf(
          waypoints: [
            _start,
            _wp(10, '4.5'),
            _wp(60, '12.0'),
            _wp(120, '6.0'),
          ].join(),
        );

        expect(await parse(xml), [(0, 0.0), (10, 4.5), (60, 12.0), (120, 6.0)]);
      });
    });
  }

  group('restore', () {
    setUp(() async {
      await setUpTestDatabase();
      final now = DateTime.utc(2026, 3, 1);
      await DiverRepository().createDiver(
        Diver(
          id: 'me',
          name: 'Me',
          isDefault: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
    });

    tearDown(tearDownTestDatabase);

    test('an old backup restores the dive with no invented profile', () async {
      await restoreUddfDives(_uddf(waypoints: _invented), diverId: 'me');

      final repository = DiveRepository();
      final listed = (await repository.getAllDives(diverId: 'me')).single;
      final restored = (await repository.getDiveById(listed.id))!;
      expect(restored.profile, isEmpty);
      expect(restored.maxDepth, 25.0);
    });
  });
}
