import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_computer_tissue.dart';
import 'package:submersion/features/dive_log/domain/entities/computer_tissue_snapshot.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:xml/xml.dart';

void main() {
  XmlElement block(String inner) =>
      XmlDocument.parse('<computertissue>$inner</computertissue>').rootElement;

  Dive dive({
    ComputerTissueSnapshot? computerTissue,
    List<DiveProfilePoint> profile = const [],
  }) => Dive(
    id: 'd',
    dateTime: DateTime.utc(2026),
    computerTissue: computerTissue,
    profile: profile,
  );

  group('hasData', () {
    test('is true for a snapshot or any sample with an N2 load', () {
      expect(
        UddfComputerTissue.hasData(
          dive(computerTissue: const ComputerTissueSnapshot(algorithm: 'x')),
        ),
        isTrue,
      );
      expect(
        UddfComputerTissue.hasData(
          dive(
            profile: const [
              DiveProfilePoint(timestamp: 0, depth: 1),
              DiveProfilePoint(timestamp: 10, depth: 2, n2Load: 5),
            ],
          ),
        ),
        isTrue,
      );
    });

    test('is false for a dive without either', () {
      expect(
        UddfComputerTissue.hasData(
          dive(
            profile: const [DiveProfilePoint(timestamp: 0, depth: 1, gf99: 3)],
          ),
        ),
        isFalse,
      );
    });
  });

  group('parse', () {
    test('reads the snapshot and the N2 load per dive ref', () {
      final byDive = UddfComputerTissue.parse(
        block('''
          <dive ref="dive_a">
            <snapshot>{"algorithm":"zhl_16c","end":{"gf99_percent":40}}</snapshot>
            <n2load>0:12 60:34</n2load>
          </dive>
          <dive ref="dive_b"><n2load>30:7</n2load></dive>
        '''),
      );

      expect(
        byDive['dive_a']!.snapshot,
        const ComputerTissueSnapshot(
          algorithm: 'zhl_16c',
          end: ComputerTissueState(gf99Percent: 40),
        ),
      );
      expect(byDive['dive_a']!.n2LoadByTime, {0: 12, 60: 34});
      expect(byDive['dive_b']!.snapshot, isNull);
      expect(byDive['dive_b']!.n2LoadByTime, {30: 7});
    });

    test('drops a malformed snapshot and malformed N2 load pairs without '
        'losing the rest', () {
      final byDive = UddfComputerTissue.parse(
        block('''
          <dive ref="dive_a">
            <snapshot>{not json</snapshot>
            <n2load>0:12 x:3 60: :9 120:abc 180:40 240:2.5</n2load>
          </dive>
        '''),
      );

      expect(byDive['dive_a']!.snapshot, isNull);
      expect(byDive['dive_a']!.n2LoadByTime, {0: 12, 180: 40});
    });

    test('skips a dive without a ref or without any data', () {
      final byDive = UddfComputerTissue.parse(
        block('''
          <dive><n2load>0:1</n2load></dive>
          <dive ref=""><n2load>0:1</n2load></dive>
          <dive ref="dive_empty"><snapshot> </snapshot><n2load/></dive>
        '''),
      );

      expect(byDive, isEmpty);
    });
  });

  group('apply', () {
    test('sets the snapshot and the N2 load on matching samples only', () {
      final diveMap = <String, dynamic>{
        'profile': <Map<String, dynamic>>[
          {'timestamp': 0, 'depth': 1.0},
          {'timestamp': 30, 'depth': 5.0},
          {'timestamp': 60, 'depth': 9.0},
        ],
      };
      const snapshot = ComputerTissueSnapshot(algorithm: 'buhlmann');

      UddfComputerTissue.apply(diveMap, (
        snapshot: snapshot,
        n2LoadByTime: const {0: 12, 60: 34, 999: 50},
      ));

      expect(diveMap['computerTissue'], snapshot);
      final profile = diveMap['profile'] as List<Map<String, dynamic>>;
      expect(profile.map((p) => p['n2Load']), [12, null, 34]);
      expect(profile[1].containsKey('n2Load'), isFalse);
    });

    test('leaves a dive without a profile or snapshot untouched', () {
      final diveMap = <String, dynamic>{'id': 'x'};

      UddfComputerTissue.apply(diveMap, (
        snapshot: null,
        n2LoadByTime: const {0: 12},
      ));

      expect(diveMap, {'id': 'x'});
    });
  });
}
