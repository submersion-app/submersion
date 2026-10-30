import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/notifications/data/services/notification_scheduler.dart';
import 'package:submersion/features/notifications/presentation/providers/notification_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';

class _CountingScheduler implements NotificationScheduler {
  int calls = 0;

  @override
  Future<void> scheduleAll({
    required AppSettings settings,
    String? diverId,
  }) async {
    calls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Issue #3818: scheduling read five settings and watched all of them.
void main() {
  late MockSettingsNotifier notifier;
  late _CountingScheduler scheduler;
  late ProviderContainer container;

  Future<void> settle() =>
      container.read(notificationSchedulingProvider.future);

  setUp(() async {
    notifier = MockSettingsNotifier(
      const AppSettings(notificationsEnabled: true),
    );
    scheduler = _CountingScheduler();
    container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => notifier),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        notificationSchedulerProvider.overrideWithValue(scheduler),
      ],
    );
    addTearDown(container.dispose);
    container.listen(notificationSchedulingProvider, (_, _) {});
    await settle();
  });

  test('schedules once on start', () {
    expect(scheduler.calls, 1);
  });

  test('sits out an edit no reminder depends on', () async {
    notifier.state = notifier.state.copyWith(showDataSourceBadges: false);
    await settle();

    expect(scheduler.calls, 1);
  });

  test('reschedules when a reminder setting changes', () async {
    notifier.state = notifier.state.copyWith(
      reminderTime: const TimeOfDay(hour: 7, minute: 30),
    );
    await settle();

    expect(scheduler.calls, 2);
  });

  test('reschedules when the language of the reminders changes', () async {
    notifier.state = notifier.state.copyWith(locale: 'de');
    await settle();

    expect(scheduler.calls, 2);
  });
}
