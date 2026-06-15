import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiverRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiverRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('create then read back round-trips prior-experience fields', () async {
    final since = DateTime(1990);
    final created = await repository.createDiver(
      Diver(
        id: '',
        name: 'Old Salt',
        priorDiveCount: 1200,
        priorDiveTimeSeconds: 1150 * 3600,
        divingSince: since,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final fetched = await repository.getDiverById(created.id);
    expect(fetched, isNotNull);
    expect(fetched!.priorDiveCount, 1200);
    expect(fetched.priorDiveTimeSeconds, 1150 * 3600);
    expect(fetched.divingSince, since);
  });

  test('update persists prior-experience fields', () async {
    final created = await repository.createDiver(
      Diver(
        id: '',
        name: 'A',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    await repository.updateDiver(
      created.copyWith(priorDiveCount: 50, priorDiveTimeSeconds: 30 * 3600),
    );

    final fetched = await repository.getDiverById(created.id);
    expect(fetched!.priorDiveCount, 50);
    expect(fetched.priorDiveTimeSeconds, 30 * 3600);
  });
}
