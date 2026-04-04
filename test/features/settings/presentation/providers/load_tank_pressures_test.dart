import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';

/// Fake repository that returns pre-configured pressure data per dive ID.
class FakeTankPressureRepository implements TankPressureRepository {
  final Map<String, Map<String, List<TankPressurePoint>>> _data;
  final List<String> queriedDiveIds = [];

  FakeTankPressureRepository([this._data = const {}]);

  @override
  Future<Map<String, List<TankPressurePoint>>> getTankPressuresForDive(
    String diveId,
  ) async {
    queriedDiveIds.add(diveId);
    return _data[diveId] ?? {};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('loadTankPressuresForDives', () {
    test('loads pressure data for dives that have it', () async {
      final repo = FakeTankPressureRepository({
        'dive-1': {
          'tank-a': [
            const TankPressurePoint(
              id: 'tp1',
              tankId: 'tank-a',
              timestamp: 0,
              pressure: 200.0,
            ),
          ],
        },
      });

      final dives = [
        Dive(id: 'dive-1', dateTime: DateTime(2025, 1, 1)),
        Dive(id: 'dive-2', dateTime: DateTime(2025, 1, 2)),
      ];

      final result = await loadTankPressuresForDives(repo, dives);

      expect(result, hasLength(1));
      expect(result.containsKey('dive-1'), isTrue);
      expect(result.containsKey('dive-2'), isFalse);
      expect(result['dive-1']!['tank-a']!.first.pressure, 200.0);
    });

    test('returns empty map when no dives have pressure data', () async {
      final repo = FakeTankPressureRepository();
      final dives = [Dive(id: 'dive-1', dateTime: DateTime(2025, 1, 1))];

      final result = await loadTankPressuresForDives(repo, dives);

      expect(result, isEmpty);
    });

    test('returns empty map for empty dive list', () async {
      final repo = FakeTankPressureRepository();

      final result = await loadTankPressuresForDives(repo, []);

      expect(result, isEmpty);
      expect(repo.queriedDiveIds, isEmpty);
    });

    test('handles multiple tanks per dive', () async {
      final repo = FakeTankPressureRepository({
        'dive-1': {
          'tank-a': [
            const TankPressurePoint(
              id: 'tp1',
              tankId: 'tank-a',
              timestamp: 0,
              pressure: 200.0,
            ),
          ],
          'tank-b': [
            const TankPressurePoint(
              id: 'tp2',
              tankId: 'tank-b',
              timestamp: 0,
              pressure: 190.0,
            ),
          ],
        },
      });

      final dives = [Dive(id: 'dive-1', dateTime: DateTime(2025, 1, 1))];

      final result = await loadTankPressuresForDives(repo, dives);

      expect(result['dive-1'], hasLength(2));
      expect(result['dive-1']!.containsKey('tank-a'), isTrue);
      expect(result['dive-1']!.containsKey('tank-b'), isTrue);
    });
  });
}
