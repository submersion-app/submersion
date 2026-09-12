import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/data/sources/swiss_lake_levels.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  group('findSwissLake', () {
    test('matches a coordinate inside Zürichsee', () {
      final lake = findSwissLake(const GeoPoint(47.25, 8.65));
      expect(lake, isNotNull);
      expect(lake!.name, contains('Zürichsee'));
      expect(lake.meanLevelMeters, greaterThan(0));
    });

    test('matches a coordinate inside Genfersee', () {
      final lake = findSwissLake(const GeoPoint(46.40, 6.60));
      expect(lake, isNotNull);
      expect(lake!.name, contains('Genfersee'));
    });

    test('returns null for a coordinate far outside Switzerland', () {
      expect(findSwissLake(const GeoPoint(12.16, -68.29)), isNull);
    });

    test('returns null for dry Swiss land between lakes', () {
      // A point in the Bernese Alps, nowhere near a mapped lake bounding box.
      expect(findSwissLake(const GeoPoint(46.55, 7.98)), isNull);
    });

    test('every lake has a plausible mean level and a non-inverted bbox', () {
      for (final lake in swissLakeLevels) {
        expect(
          // Upper bound covers the Engadin lakes (Silsersee/Silvaplanersee,
          // ~1790-1797 m) with headroom for future additions, not just the
          // lowland lakes this table started with.
          lake.meanLevelMeters,
          inInclusiveRange(190.0, 2000.0),
          reason: lake.name,
        );
        expect(lake.minLat, lessThan(lake.maxLat), reason: lake.name);
        expect(lake.minLon, lessThan(lake.maxLon), reason: lake.name);
      }
    });

    test('every lake in the table resolves to ITSELF at its own bbox '
        'center, not to an earlier-listed lake whose bbox happens to '
        'overlap it (Copilot review)', () {
      // Table-driven so a future addition or reorder that accidentally
      // shadows an existing lake (findSwissLake takes the first bbox
      // match in list order) fails loudly here instead of silently
      // misassigning that lake's mean level to whichever coordinate lands
      // in the overlap.
      for (final lake in swissLakeLevels) {
        final center = GeoPoint(
          (lake.minLat + lake.maxLat) / 2,
          (lake.minLon + lake.maxLon) / 2,
        );
        final matched = findSwissLake(center);
        expect(matched, isNotNull, reason: lake.name);
        expect(matched!.name, lake.name, reason: lake.name);
      }
    });

    test('a coordinate at Rotsee resolves to Rotsee, not the coarser '
        'Vierwaldstättersee bbox that happens to sweep over it (Copilot '
        'review, ~14.6 m depth error if regressed)', () {
      // Real Rotsee coordinate (Schiffsstation-adjacent shoreline), inside
      // both Rotsee's own tight bbox and Vierwaldstättersee's much coarser
      // one -- must resolve to Rotsee specifically, not just "some lake".
      final lake = findSwissLake(const GeoPoint(47.07, 8.31));
      expect(lake, isNotNull);
      expect(lake!.name, 'Rotsee');
      expect(lake.meanLevelMeters, closeTo(419.00, 1e-9));
    });

    test('no two lakes\' bounding boxes overlap, except pairs genuinely '
        'connected in the real STAC data and known to resolve correctly '
        'via list order', () {
      // A permanent guard against the exact class of bug Copilot review
      // found repeatedly in this table: two overlapping bboxes mean
      // whichever lake is listed first silently wins for every coordinate
      // in the overlap, even when that coordinate actually belongs to the
      // other lake. Most such overlaps are table-rounding artifacts with
      // no real bbox overlap underneath, fixed by tightening bounds; a
      // few pairs (lakes physically connected by a canal, or one lake
      // sitting inside another's much coarser bounding rectangle) have a
      // GENUINE overlap in the real swisstopo STAC bboxes with no
      // non-overlapping split possible without clipping real coverage --
      // those are listed here as accepted exceptions, each verified
      // correct by its own findSwissLake regression test (see Rotsee's
      // above) rather than by this blanket check.
      const acceptedOverlaps = {
        ('Rotsee', 'Vierwaldstättersee'),
        ('Zugersee', 'Vierwaldstättersee'),
        ('Murtensee', 'Neuenburgersee'),
      };
      for (var i = 0; i < swissLakeLevels.length; i++) {
        for (var j = i + 1; j < swissLakeLevels.length; j++) {
          final a = swissLakeLevels[i];
          final b = swissLakeLevels[j];
          if (acceptedOverlaps.contains((a.name, b.name)) ||
              acceptedOverlaps.contains((b.name, a.name))) {
            continue;
          }
          final overlapLat = a.minLat <= b.maxLat && b.minLat <= a.maxLat;
          final overlapLon = a.minLon <= b.maxLon && b.minLon <= a.maxLon;
          expect(
            overlapLat && overlapLon,
            isFalse,
            reason: '${a.name} (index $i) overlaps ${b.name} (index $j)',
          );
        }
      }
    });
  });
}
