import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding_subjects.dart';

QualityFinding _f(
  String detectorId,
  Map<String, Object?> params, {
  String id = 'f1',
}) => QualityFinding(
  id: id,
  diveId: 'd1',
  detectorId: detectorId,
  detectorVersion: 1,
  category: QualityCategory.source,
  severity: QualitySeverity.info,
  status: QualityStatus.open,
  params: params,
  createdAt: DateTime.utc(2026, 11, 4),
  updatedAt: DateTime.utc(2026, 11, 4),
);

void main() {
  group('findingSourceId', () {
    test('reads the sourceId param', () {
      expect(findingSourceId(_f('clock_offset', {'sourceId': 's2'})), 's2');
    });

    test('ignores a missing, empty or non-string id', () {
      expect(findingSourceId(_f('clock_offset', {'offsetHours': 1})), isNull);
      expect(findingSourceId(_f('source_conflict', {'sourceId': ''})), isNull);
      expect(findingSourceId(_f('source_conflict', {'sourceId': 7})), isNull);
    });
  });

  group('findingTankIds', () {
    test('one tank for a pressure finding', () {
      expect(
        findingTankIds(_f('pressure_anomaly', {'tankId': 't1', 'riseBar': 9})),
        ['t1'],
      );
    });

    test('both tanks of a twin pair, in the finding order', () {
      expect(
        findingTankIds(_f('tank_assignment', {'tankIdA': 'b', 'tankIdB': 'a'})),
        ['b', 'a'],
      );
    });

    test('nothing for a detector whose message names its tank itself', () {
      expect(findingTankIds(_f('transmitter_role', {'tankId': 't1'})), isEmpty);
    });

    test('skips non-string ids', () {
      expect(findingTankIds(_f('pressure_anomaly', {'tankId': 3})), isEmpty);
    });
  });

  group('subject keys', () {
    final findings = [
      _f('source_conflict', {'sourceId': 's2'}, id: 'a'),
      _f('clock_offset', {'sourceId': 's1'}, id: 'b'),
      _f('source_conflict', {'sourceId': 's2'}, id: 'c'),
      _f('tank_assignment', {'tankIdA': 't3', 'tankIdB': 't1'}, id: 'd'),
    ];

    test('are sorted, de-duplicated and comma-joined', () {
      expect(qualitySourceIdsKey(findings), 's1,s2');
      expect(qualityTankIdsKey(findings), 't1,t3');
    });

    test('are empty when nothing is named', () {
      final none = [
        _f('sample_gap', {'gapCount': 1}),
      ];
      expect(qualitySourceIdsKey(none), isEmpty);
      expect(qualityTankIdsKey(none), isEmpty);
      expect(idsOfSubjectKey(''), isEmpty);
    });

    test('round-trip through idsOfSubjectKey', () {
      expect(idsOfSubjectKey(qualitySourceIdsKey(findings)), ['s1', 's2']);
    });
  });

  group('QualityFindingSubjects', () {
    const subjects = QualityFindingSubjects(
      sourceLabels: {'s1': 'Suunto EON Core'},
      tanks: {'t1': QualityTankRef(number: 1), 't3': QualityTankRef(number: 3)},
    );

    test('labels the source a finding names', () {
      expect(
        subjects.sourceLabelOf(_f('clock_offset', {'sourceId': 's1'})),
        'Suunto EON Core',
      );
      expect(
        subjects.sourceLabelOf(_f('clock_offset', {'sourceId': 'gone'})),
        isNull,
      );
    });

    test('keeps the finding order and drops tanks that are gone', () {
      expect(
        subjects.tanksOf(
          _f('tank_assignment', {'tankIdA': 't3', 'tankIdB': 'gone'}),
        ),
        const [QualityTankRef(number: 3)],
      );
    });
  });
}
