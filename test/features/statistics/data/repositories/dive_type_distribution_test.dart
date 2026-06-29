import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late StatisticsRepository stats;
  late DiveRepository diveRepo;

  setUp(() async {
    await setUpTestDatabase();
    stats = StatisticsRepository();
    diveRepo = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  test('a multi-type dive counts toward each of its types', () async {
    await diveRepo.createDive(
      domain.Dive(
        id: 'a',
        dateTime: DateTime(2026, 1, 1),
        diveTypeIds: const ['night', 'wreck'],
      ),
    );
    await diveRepo.createDive(
      domain.Dive(
        id: 'b',
        dateTime: DateTime(2026, 1, 2),
        diveTypeIds: const ['night'],
      ),
    );

    final dist = await stats.getDiveTypeDistribution();
    final byLabel = {for (final s in dist) s.label: s.count};
    expect(byLabel['Night'], 2); // both dives
    expect(byLabel['Wreck'], 1); // only dive 'a'
  });

  test('isDiveTypeInUse is true when a type is on any dive', () async {
    await diveRepo.createDive(
      domain.Dive(
        id: 'a',
        dateTime: DateTime(2026, 1, 1),
        diveTypeIds: const ['cave', 'deep'],
      ),
    );
    final typeRepo = DiveTypeRepository();
    expect(await typeRepo.isDiveTypeInUse('deep'), isTrue);
    expect(await typeRepo.isDiveTypeInUse('wreck'), isFalse);
  });
}
