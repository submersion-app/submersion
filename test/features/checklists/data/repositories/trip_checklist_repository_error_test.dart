import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_database.dart';

/// Mirrors tank_preset_repository_error_test.dart: close the database out
/// from under the repository so every try/catch's log+rethrow path runs for
/// real, instead of only ever being unit-tested via the happy path.
void main() {
  group('TripChecklistRepository error handling', () {
    late TripChecklistRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = TripChecklistRepository();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('methods rethrow when the database is unavailable', () async {
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      final now = DateTime.now();
      final item = TripChecklistItem(
        id: 'i1',
        checklistId: 'c1',
        title: 'Service regulator',
        createdAt: now,
        updatedAt: now,
      );

      await expectLater(repository.getByChecklistId('c1'), throwsA(anything));
      await expectLater(repository.createItem(item), throwsA(anything));
      await expectLater(repository.updateItem(item), throwsA(anything));
      await expectLater(
        repository.toggleDone('i1', isDone: true),
        throwsA(anything),
      );
      await expectLater(repository.deleteItem('i1'), throwsA(anything));
      await expectLater(repository.getAllItemsForTrip('t1'), throwsA(anything));
      await expectLater(
        repository.saveAsTemplate(
          checklistId: 'c1',
          tripStartDate: now,
          name: 'My prep',
        ),
        throwsA(anything),
      );
      await expectLater(
        repository.replaceWithTemplate(
          templateId: 'tpl1',
          checklistId: 'c1',
          trip: Trip(
            id: 't1',
            name: 'Red Sea',
            startDate: now,
            endDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        ),
        throwsA(anything),
      );
    });
  });
}
