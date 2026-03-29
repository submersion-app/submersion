import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/trips/data/repositories/liveaboard_details_repository.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('LiveaboardDetailsRepository error handling', () {
    late LiveaboardDetailsRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = LiveaboardDetailsRepository();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('methods handle database errors gracefully', () async {
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      final now = DateTime.now();
      final details = LiveaboardDetails(
        id: 'ld1',
        tripId: 't1',
        vesselName: 'MV Explorer',
        createdAt: now,
        updatedAt: now,
      );

      // getByTripId - rethrows
      await expectLater(repository.getByTripId('t1'), throwsA(anything));

      // createOrUpdate - rethrows
      await expectLater(repository.createOrUpdate(details), throwsA(anything));

      // deleteByTripId - rethrows
      await expectLater(repository.deleteByTripId('t1'), throwsA(anything));
    });
  });
}
