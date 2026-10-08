import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/notifications/data/services/notification_scheduler.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_database.dart';

/// Records the kind of every service reminder; every other member no-ops.
class _FakeNotificationService implements NotificationService {
  final reminderKinds = <String>[];

  @override
  Future<int> scheduleServiceReminder({
    required String scheduleId,
    required String equipmentId,
    required String equipmentName,
    required String kindName,
    required String? brandModel,
    required DateTime scheduledDate,
    required int daysBefore,
  }) async {
    reminderKinds.add(kindName);
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

/// A shared item's clock can use its owner's custom service kind (issue
/// #2046). The sharee's reminders must still include it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(tearDownTestDatabase);

  test(
    'a sharee gets the reminder for a clock on the owner custom kind',
    () async {
      final now = DateTime.now();
      final t = now.millisecondsSinceEpoch;
      for (final id in ['owner', 'wife']) {
        await db
            .into(db.divers)
            .insert(
              DiversCompanion.insert(
                id: id,
                name: id,
                createdAt: t,
                updatedAt: t,
              ),
            );
      }
      await db
          .into(db.serviceKinds)
          .insert(
            ServiceKindsCompanion.insert(
              id: 'owner-kind',
              name: 'Owner clean',
              createdAt: t,
              updatedAt: t,
              diverId: const Value('owner'),
              defaultIntervalDays: const Value(365),
            ),
          );
      final item = await EquipmentRepository().createEquipment(
        const EquipmentItem(
          id: '',
          diverId: 'owner',
          name: 'Reg',
          type: EquipmentType.regulator,
        ),
      );
      // Due in 40 days, so the 30-day reminder is still ahead.
      await ServiceScheduleRepository().createSchedule(
        ServiceSchedule(
          id: 'sched',
          equipmentId: item.id,
          serviceKindId: 'owner-kind',
          intervalDays: 365,
          anchorDate: now.subtract(const Duration(days: 325)),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await EquipmentShareRepository().shareMany(
        equipmentIds: [item.id],
        diverIds: ['wife'],
        actingDiverId: 'owner',
      );

      final fake = _FakeNotificationService();
      await NotificationScheduler(
        notificationService: fake,
      ).scheduleAll(settings: const AppSettings(), diverId: 'wife');

      expect(fake.reminderKinds, contains('Owner clean'));
    },
  );
}
