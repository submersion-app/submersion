import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/profile_series_revision.dart';

ProfileSeriesRevision _revision() => const ProfileSeriesRevision(
  seriesId: 'series-2',
  diveId: 'dive-1',
  parentSeriesId: 'series-1',
  rootSeriesId: 'series-1',
  contentHash: 'hash-2',
  revisionKind: 'edit',
  createdAt: 200,
  isActive: true,
);

void main() {
  group('ProfileSeriesRevision', () {
    test('two revisions with the same fields are equal', () {
      expect(_revision(), _revision());
      expect(_revision().hashCode, _revision().hashCode);
    });

    test('a revision that differs in any field is not equal', () {
      final base = _revision();
      expect(base.copyWith(seriesId: 'other'), isNot(base));
      expect(base.copyWith(diveId: 'other'), isNot(base));
      expect(base.copyWith(parentSeriesId: 'other'), isNot(base));
      expect(base.copyWith(rootSeriesId: 'other'), isNot(base));
      expect(base.copyWith(contentHash: 'other'), isNot(base));
      expect(base.copyWith(revisionKind: 'other'), isNot(base));
      expect(base.copyWith(createdAt: 1), isNot(base));
      expect(base.copyWith(isActive: false), isNot(base));
    });

    test('copyWith with no arguments returns an equal revision', () {
      expect(_revision().copyWith(), _revision());
    });

    test('copyWith replaces only the fields it is given', () {
      final copy = _revision().copyWith(isActive: false, createdAt: 300);

      expect(copy.isActive, isFalse);
      expect(copy.createdAt, 300);
      expect(copy.seriesId, 'series-2');
      expect(copy.parentSeriesId, 'series-1');
      expect(copy.revisionKind, 'edit');
    });

    test('copyWith can clear the parent of a root revision', () {
      final copy = _revision().copyWith(clearParentSeriesId: true);

      expect(copy.parentSeriesId, isNull);
      expect(copy.rootSeriesId, 'series-1');
    });
  });
}
