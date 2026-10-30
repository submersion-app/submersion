import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/trips/data/repositories/trip_media_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('TripMediaRepository error handling', () {
    late TripMediaRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = TripMediaRepository();
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('getPreview rethrows a database failure', () async {
      await expectLater(repository.getPreview('t1'), throwsA(anything));
    });

    test('getMediaForTrip rethrows a database failure', () async {
      await expectLater(repository.getMediaForTrip('t1'), throwsA(anything));
    });
  });
}
