import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/services/finding_ownership.dart';

QualityFinding _finding({
  String detectorId = 'shared_gear_overlap',
  String? relatedDiveId = 'b1',
  Map<String, Object?> params = const {},
}) => QualityFinding(
  id: 'f1',
  diveId: 'a1',
  relatedDiveId: relatedDiveId,
  detectorId: detectorId,
  detectorVersion: 1,
  category: QualityCategory.time,
  severity: QualitySeverity.info,
  status: QualityStatus.open,
  params: params,
  createdAt: DateTime.utc(2026, 7, 17),
  updatedAt: DateTime.utc(2026, 7, 17),
);

const _crossDiver = {
  'dives': {
    'a1': {'diverId': 'alice'},
    'b1': {'diverId': 'bob'},
  },
};

void main() {
  // Issue #3049: a shared gear pair spans two profiles, and each may act only
  // on its own dive.
  group('foreignDiveIdOf', () {
    test('names the anchor when the related dive is the active diver\'s', () {
      expect(foreignDiveIdOf(_finding(params: _crossDiver), 'bob'), 'a1');
    });

    test('names the related dive when the anchor is the active diver\'s', () {
      expect(foreignDiveIdOf(_finding(params: _crossDiver), 'alice'), 'b1');
    });

    test('is null when both dives are the active diver\'s', () {
      final f = _finding(
        params: const {
          'dives': {
            'a1': {'diverId': 'alice'},
            'b1': {'diverId': 'alice'},
          },
        },
      );
      expect(foreignDiveIdOf(f, 'alice'), isNull);
    });

    test('is null with no active diver', () {
      expect(foreignDiveIdOf(_finding(params: _crossDiver), null), isNull);
    });

    test('is null for a single-dive finding', () {
      expect(
        foreignDiveIdOf(
          _finding(relatedDiveId: null, params: _crossDiver),
          'bob',
        ),
        isNull,
      );
    });

    test('is null for a pair that records no divers', () {
      final f = _finding(detectorId: 'duplicate', params: const {'score': 0.5});
      expect(foreignDiveIdOf(f, 'bob'), isNull);
    });
  });

  group('diveSidesOf', () {
    test('swaps the sides when the anchor is foreign', () {
      final sides = diveSidesOf(_finding(), 'a1');
      expect(sides.own, 'b1');
      expect(sides.paired, 'a1');
    });

    test('keeps the anchor as its own dive otherwise', () {
      for (final foreign in ['b1', null]) {
        final sides = diveSidesOf(_finding(), foreign);
        expect(sides.own, 'a1');
        expect(sides.paired, 'b1');
      }
    });
  });
}
