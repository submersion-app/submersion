import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklists_repository.dart';

import '../../../../helpers/test_database.dart';

/// Mirrors trip_checklist_repository_error_test.dart: close the database out
/// from under the repository so every try/catch's log+rethrow path runs for
/// real, instead of only ever being unit-tested via the happy path.
void main() {
  group('TripChecklistsRepository error handling', () {
    late TripChecklistsRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = TripChecklistsRepository();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('methods rethrow when the database is unavailable', () async {
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      await expectLater(
        repository.getChecklistsForTrip('t1'),
        throwsA(anything),
      );
      await expectLater(
        repository.createChecklist(tripId: 't1', name: 'Gear'),
        throwsA(anything),
      );
      await expectLater(
        repository.renameChecklist('c1', 'Clothing'),
        throwsA(anything),
      );
      await expectLater(
        repository.reorderChecklists('t1', ['c1']),
        throwsA(anything),
      );
      await expectLater(repository.deleteChecklist('c1'), throwsA(anything));
    });
  });
}
