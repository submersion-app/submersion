import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_draft_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/notifications/data/services/notification_scheduler.dart';
import 'package:submersion/features/notifications/domain/draft_reminder_plan.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_database.dart';

/// Records draft reminder calls; every other member no-ops.
class _FakeNotificationService implements NotificationService {
  final scheduled = <({String diveId, DateTime at})>[];
  final cancelled = <String>[];

  /// Dives with a draft reminder pending in the OS.
  Set<String> pending = {};

  @override
  Future<Set<String>> pendingDraftReminderIds() async => pending;

  @override
  Future<int> scheduleDraftReminder({
    required String diveId,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    scheduled.add((diveId: diveId, at: at));
    return 1;
  }

  @override
  Future<void> cancelDraftReminder(String diveId) async {
    cancelled.add(diveId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    if (name.contains('pending')) return Future.value(<String>{});
    if (name.contains('schedule')) return Future.value(0);
    return Future.value();
  }
}

/// A reminder when a draft has waited three days for its download (issue
/// #637): off unless switched on on this device, once per draft.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeNotificationService service;
  late DiveDraftRepository drafts;
  var on = true;
  var now = DateTime(2026, 7, 17, 12);
  const settings = AppSettings(reminderTime: TimeOfDay(hour: 9, minute: 0));

  NotificationScheduler scheduler() => NotificationScheduler(
    notificationService: service,
    draftRepository: drafts,
    draftRemindersOn: () async => on,
    clock: () => now,
  );

  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO divers (id, name, is_default, created_at, updated_at) '
      "VALUES ('d1', 'Ana', 1, 0, 0)",
    );
    service = _FakeNotificationService();
    drafts = DiveDraftRepository(dives: DiveRepository());
    on = true;
    now = DateTime(2026, 7, 17, 12);
  });
  tearDown(tearDownTestDatabase);

  /// A draft out of the water at 10:45 on the 17th, wall clock.
  Future<String> surfacedDraft() async {
    final draft = await drafts.createDraft(
      diverId: 'd1',
      entryTime: DateTime.utc(2026, 7, 17, 10),
    );
    await drafts.closeDraft(
      draft.id,
      exitTime: DateTime.utc(2026, 7, 17, 10, 45),
    );
    return draft.id;
  }

  test('off schedules nothing', () async {
    await surfacedDraft();
    on = false;

    await scheduler().updateDraftReminders(settings: settings, diverId: 'd1');

    expect(service.scheduled, isEmpty);
  });

  test('a surfaced draft is reminded of three days after its exit, at the '
      'reminder time', () async {
    final id = await surfacedDraft();

    await scheduler().updateDraftReminders(settings: settings, diverId: 'd1');

    expect(service.scheduled, [(diveId: id, at: DateTime(2026, 7, 20, 9))]);
  });

  test('a draft still in the water is not reminded of', () async {
    await drafts.createDraft(
      diverId: 'd1',
      entryTime: DateTime.utc(2026, 7, 17, 10),
    );

    await scheduler().updateDraftReminders(settings: settings, diverId: 'd1');

    expect(service.scheduled, isEmpty);
  });

  test('filling or completing a draft cancels its reminder', () async {
    final id = await surfacedDraft();
    await drafts.markDraftComplete(id);
    service.pending = {id};

    await scheduler().updateDraftReminders(settings: settings, diverId: 'd1');

    expect(service.cancelled, contains(id));
    expect(service.scheduled, isEmpty);
  });

  test('a reminder whose time has passed is not scheduled again', () async {
    await surfacedDraft();
    now = DateTime(2026, 7, 21, 12);

    await scheduler().updateDraftReminders(settings: settings, diverId: 'd1');

    expect(service.scheduled, isEmpty);
  });

  test('rescheduling everything brings the reminders back', () async {
    final id = await surfacedDraft();

    await scheduler().rescheduleAll(
      settings: settings.copyWith(notificationsEnabled: true),
      diverId: 'd1',
    );

    expect(service.scheduled.map((s) => s.diveId), [id]);
  });

  test('the plan reads the exit in the diver\'s own clock', () {
    expect(
      draftReminderAt(
        exitWallClock: DateTime.utc(2026, 7, 31, 23, 30),
        reminderTime: const TimeOfDay(hour: 8, minute: 15),
      ),
      DateTime(2026, 8, 3, 8, 15),
    );
  });
}
