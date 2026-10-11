import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// The table's batch read (#2984) must show what the detail page shows:
/// the stored interval, else [DiveRepository.getSurfaceInterval].
void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  DateTime at(int hour, [int minute = 0]) =>
      DateTime.utc(2026, 4, 1, hour, minute);

  test('the batch matches the detail page for every dive', () async {
    final dives = [
      domain.Dive(
        id: 'first',
        dateTime: at(8),
        entryTime: at(8),
        exitTime: at(8, 45),
      ),
      domain.Dive(
        id: 'runtime-only',
        dateTime: at(10),
        entryTime: at(10),
        runtime: const Duration(minutes: 50),
      ),
      domain.Dive(
        id: 'after-runtime',
        dateTime: at(12),
        entryTime: at(12),
        exitTime: at(12, 40),
      ),
      domain.Dive(id: 'overlap', dateTime: at(12, 20), entryTime: at(12, 20)),
      domain.Dive(
        id: 'stored',
        dateTime: at(15),
        entryTime: at(15),
        surfaceInterval: const Duration(minutes: 33),
      ),
      domain.Dive(
        id: 'profile-only',
        dateTime: at(17),
        entryTime: at(17),
        profile: [
          for (var t = 0; t <= 1200; t += 10)
            domain.DiveProfilePoint(
              timestamp: t,
              depth: t == 0 || t == 1200 ? 0 : 12,
            ),
        ],
      ),
      domain.Dive(id: 'after-profile', dateTime: at(19), entryTime: at(19)),
    ];
    for (final d in dives) {
      await repository.createDive(d);
    }

    final batch = await repository.getSurfaceIntervals();

    for (final d in dives) {
      final detail =
          d.surfaceInterval ?? await repository.getSurfaceInterval(d.id);
      expect(batch[d.id], detail, reason: d.id);
    }
    expect(batch['first'], isNull);
    expect(batch['stored'], const Duration(minutes: 33));
    // The profile's 20-minute span is the runtime the next gap starts from.
    expect(batch['after-profile'], const Duration(minutes: 100));
  });
}
