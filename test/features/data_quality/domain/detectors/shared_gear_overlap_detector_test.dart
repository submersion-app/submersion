import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/detectors/shared_gear_overlap_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';

import '../../helpers/quality_test_helpers.dart';

/// The same item on two profiles' overlapping dives (issue #2853).
void main() {
  const detector = SharedGearOverlapDetector();
  final ten = DateTime.utc(2026, 7, 1, 10);
  DateTime at(int minutes) => ten.add(Duration(minutes: minutes));

  SharedGearItem item(
    String id, {
    Set<String> hosts = const {},
    List<String> installed = const [],
    Set<String> mine = const {'gearList'},
    Set<String> theirs = const {'gearList'},
  }) => SharedGearItem(
    equipmentId: id,
    name: 'Item $id',
    thisLinkKinds: mine,
    otherLinkKinds: theirs,
    hostIds: hosts,
    installedPartIds: installed,
  );

  /// Bill's dive b1 from 10:00 for 40 minutes, sharing [items] with Anna's
  /// dive a1 starting [otherStart] minutes later.
  List<QualityFinding> detectFromBill(
    List<SharedGearItem> items, {
    int otherStart = 10,
    int? otherMinutes = 40,
    Duration? runtime = const Duration(minutes: 40),
  }) => detector.detect(
    makeContext(
      dive: makeTestDive(
        id: 'b1',
        diverId: 'bill',
        entry: ten,
        runtime: runtime,
      ),
      sharedGearOverlaps: [
        SharedGearOverlap(
          otherDiveId: 'a1',
          otherDiverId: 'anna',
          otherDiverName: 'Anna',
          thisDiverName: 'Bill',
          otherEntry: at(otherStart),
          otherExit: otherMinutes == null
              ? null
              : at(otherStart + otherMinutes),
          items: items,
        ),
      ],
    ),
  );

  test('6 minutes of overlap reports, 5 and 4 do not', () {
    expect(detectFromBill([item('light')], otherStart: 34), hasLength(1));
    expect(detectFromBill([item('light')], otherStart: 35), isEmpty);
    expect(detectFromBill([item('light')], otherStart: 36), isEmpty);
  });

  test('a dive without a duration is never compared', () {
    expect(detectFromBill([item('light')], runtime: null), isEmpty);
    expect(detectFromBill([item('light')], otherMinutes: null), isEmpty);
  });

  test('installed parts fold into their host, one finding per setup', () {
    final findings = detectFromBill([
      item('reg', installed: ['spare']),
      item('hose', hosts: {'reg'}),
      item('octo', hosts: {'reg'}),
    ]);
    final f = findings.single;
    expect(f.params['equipmentId'], 'reg');
    expect(f.params['partIds'], ['hose', 'octo', 'spare']);
  });

  test('unrelated items give one finding each', () {
    final findings = detectFromBill([item('light'), item('mask')]);
    expect(findings.map((f) => f.params['equipmentId']).toSet(), {
      'light',
      'mask',
    });
  });

  test('the finding is info, in the time category, and names both dives', () {
    final f = detectFromBill([
      item('tank', mine: {'tankCylinder', 'gearList'}),
    ]).single;
    expect(f.severity, QualitySeverity.info);
    expect(f.category, QualityCategory.time);
    expect(f.params['itemName'], 'Item tank');
    final dives = f.params['dives'] as Map<String, Object?>;
    expect(dives.keys, ['a1', 'b1'], reason: 'ascending dive-id order');
    expect(dives['b1'], {
      'diverId': 'bill',
      'diverName': 'Bill',
      'entryMs': ten.millisecondsSinceEpoch,
      'linkKinds': ['gearList', 'tankCylinder'],
      'removable': false,
    });
    expect((dives['a1']! as Map)['linkKinds'], ['gearList']);
  });

  test('both sides of the pair write the same finding, byte for byte', () {
    final fromBill = detectFromBill([item('light')]).single;
    final fromAnna = detector
        .detect(
          makeContext(
            dive: makeTestDive(id: 'a1', diverId: 'anna', entry: at(10)),
            sharedGearOverlaps: [
              SharedGearOverlap(
                otherDiveId: 'b1',
                otherDiverId: 'bill',
                otherDiverName: 'Bill',
                thisDiverName: 'Anna',
                otherEntry: ten,
                otherExit: at(40),
                items: [item('light')],
              ),
            ],
          ),
        )
        .single;
    expect(fromAnna.id, fromBill.id);
    expect(jsonEncode(fromAnna.params), jsonEncode(fromBill.params));
  });

  test(
    'the scanned dive ends at its recorded exit, as the other side does',
    () {
      // Runtime says 40 minutes but the recorded exit is at 10:30; Anna starts
      // at 10:26, so the real overlap is 4 minutes.
      final findings = detector.detect(
        makeContext(
          dive: makeTestDive(
            id: 'b1',
            diverId: 'bill',
            entry: ten,
            runtime: const Duration(minutes: 40),
          ).copyWith(exitTime: at(30)),
          sharedGearOverlaps: [
            SharedGearOverlap(
              otherDiveId: 'a1',
              otherDiverId: 'anna',
              otherDiverName: 'Anna',
              thisDiverName: 'Bill',
              otherEntry: at(26),
              otherExit: at(66),
              items: [item('light')],
            ),
          ],
        ),
      );
      expect(findings, isEmpty);
    },
  );

  test('a side is removable only when every folded item is gear-list only', () {
    final f = detectFromBill([
      item('reg'),
      item('hose', hosts: {'reg'}, mine: {'gearList', 'tankRegulator'}),
    ]).single;
    final dives = f.params['dives'] as Map<String, Object?>;
    expect((dives['b1']! as Map)['removable'], isFalse);
    expect((dives['a1']! as Map)['removable'], isTrue);
  });
}
