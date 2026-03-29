import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/notifications/data/repositories/scheduled_notification_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('ScheduledNotificationRepository error handling', () {
    late ScheduledNotificationRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = ScheduledNotificationRepository();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('methods handle database errors gracefully', () async {
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      // getForEquipment - rethrows
      await expectLater(repository.getForEquipment('eq1'), throwsA(anything));

      // isScheduled - returns false on error
      expect(
        await repository.isScheduled(
          equipmentId: 'eq1',
          reminderDaysBefore: 7,
          scheduledDate: DateTime.now(),
        ),
        isFalse,
      );

      // recordScheduled - rethrows
      await expectLater(
        repository.recordScheduled(
          equipmentId: 'eq1',
          scheduledDate: DateTime.now(),
          reminderDaysBefore: 7,
          notificationId: 100,
        ),
        throwsA(anything),
      );

      // deleteForEquipment - rethrows
      await expectLater(
        repository.deleteForEquipment('eq1'),
        throwsA(anything),
      );

      // deleteAll - rethrows
      await expectLater(repository.deleteAll(), throwsA(anything));

      // getAll - rethrows
      await expectLater(repository.getAll(), throwsA(anything));

      // deleteExpired - rethrows
      await expectLater(repository.deleteExpired(), throwsA(anything));
    });
  });
}
