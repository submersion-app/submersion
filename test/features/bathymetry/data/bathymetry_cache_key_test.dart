import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/bathymetry/data/sources/swiss_lake_levels.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// [BathymetryRepository.isCurrentKey] decides which cached grids the local
/// cache sweep deletes (issue #1929), so a false negative throws away a grid
/// the app would read on its next visit. Every key [BathymetryRepository.keyFor]
/// can build today must read as current.
void main() {
  const bonaire = GeoPoint(12.16, -68.29);
  const southern = GeoPoint(-33.861, 151.212);
  const betlis = GeoPoint(47.135503, 9.144546); // Walensee

  group('isCurrentKey keeps every key keyFor builds', () {
    final points = {
      'bonaire': bonaire,
      'southern hemisphere': southern,
      'swiss lake': betlis,
    };
    // null is the base square; the rest are LOD patch spans.
    const spans = <double?>[null, 8000, 2000, 1000, 500, 250];

    for (final entry in points.entries) {
      for (final span in spans) {
        test('${entry.key}, span ${span ?? 'default'}', () {
          final key = BathymetryRepository.keyFor(
            entry.value,
            spanMeters: span,
          );
          expect(BathymetryRepository.isCurrentKey(key), isTrue, reason: key);
        });
      }
    }
  });

  group('isCurrentKey drops superseded keys', () {
    test('generation 1 keys, which end in a bare span', () {
      expect(BathymetryRepository.isCurrentKey('12.16,-68.30@8000'), isFalse);
      expect(BathymetryRepository.isCurrentKey('12.16,-68.30@4000'), isFalse);
    });

    test('keys under an earlier generation', () {
      for (final generation in ['v2', 'v3', 'v4']) {
        expect(
          BathymetryRepository.isCurrentKey('12.16,-68.30@8000$generation'),
          isFalse,
          reason: generation,
        );
        expect(
          BathymetryRepository.isCurrentKey(
            '47.135503,9.144546@8000$generation@419.07',
          ),
          isFalse,
          reason: '$generation lake key',
        );
      }
    });

    test('a generation that only starts with the current one', () {
      const current = BathymetryRepository.selectionGeneration;
      expect(
        BathymetryRepository.isCurrentKey('12.16,-68.30@8000${current}0'),
        isFalse,
      );
    });

    test('a lake key carrying a level the lake no longer documents', () {
      final key = BathymetryRepository.keyFor(betlis);
      final lake = findSwissLake(betlis)!;
      final stale = key.replaceFirst(
        '@${lake.meanLevelMeters}',
        '@${lake.meanLevelMeters + 0.5}',
      );
      expect(stale, isNot(key));
      expect(BathymetryRepository.isCurrentKey(stale), isFalse);
    });

    test('a level-bearing key whose coordinate is outside every lake', () {
      const generation = BathymetryRepository.selectionGeneration;
      expect(
        BathymetryRepository.isCurrentKey(
          '12.160000,-68.290000@8000$generation@372.05',
        ),
        isFalse,
      );
    });

    test('keys keyFor could never have built', () {
      const generation = BathymetryRepository.selectionGeneration;
      for (final key in [
        '',
        'garbage',
        '@8000$generation',
        '12.16,-68.30@@8000$generation',
        '12.16,-68.30@8000${generation}extra',
        'north,west@8000$generation@419.07',
        '47.135503,9.144546@8000$generation@419.07@1',
      ]) {
        expect(BathymetryRepository.isCurrentKey(key), isFalse, reason: key);
      }
    });
  });
}
