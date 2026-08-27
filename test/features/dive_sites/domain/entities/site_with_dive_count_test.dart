import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';

void main() {
  const site = DiveSite(id: 'site-1', name: 'Blue Hole');

  group('SiteWithDiveCount', () {
    test('aggregates default to null and an empty feature list', () {
      const entry = SiteWithDiveCount(site: site, diveCount: 3);

      expect(entry.lastDivedAt, isNull);
      expect(entry.maxDepthReached, isNull);
      expect(entry.featureTypes, isEmpty);
    });

    test('is value-equal on every field', () {
      final a = SiteWithDiveCount(
        site: site,
        diveCount: 3,
        lastDivedAt: DateTime(2026, 3, 5),
        maxDepthReached: 31.5,
        featureTypes: const ['wreck', 'mooring'],
      );
      final b = SiteWithDiveCount(
        site: site,
        diveCount: 3,
        lastDivedAt: DateTime(2026, 3, 5),
        maxDepthReached: 31.5,
        featureTypes: const ['wreck', 'mooring'],
      );

      expect(a, equals(b));
      expect(a.copyWith(diveCount: 4), isNot(equals(b)));
    });
  });

  group('SiteDiveAggregate', () {
    test('is value-equal', () {
      final a = SiteDiveAggregate(
        diveCount: 2,
        lastDivedAt: DateTime(2026, 1, 1),
        maxDepthReached: 18,
      );
      final b = SiteDiveAggregate(
        diveCount: 2,
        lastDivedAt: DateTime(2026, 1, 1),
        maxDepthReached: 18,
      );
      expect(a, equals(b));
    });
  });
}
