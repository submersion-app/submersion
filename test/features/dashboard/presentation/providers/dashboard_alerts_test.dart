import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';

NoFlyStatus _status({required Duration untilOffset}) {
  return NoFlyStatus(
    until: DateTime.now().toUtc().add(untilOffset),
    category: NoFlyCategory.single,
    interval: const Duration(hours: 12),
  );
}

void main() {
  test('an active no-fly restriction counts as an alert', () {
    final alerts = DashboardAlerts(
      insuranceExpiringSoon: false,
      insuranceExpired: false,
      noFlyStatus: _status(untilOffset: const Duration(hours: 2)),
    );
    expect(alerts.hasActiveNoFly, isTrue);
    expect(alerts.hasAlerts, isTrue);
    expect(alerts.alertCount, 1);
  });

  test('an expired cached no-fly status clears the alert and badge', () {
    final alerts = DashboardAlerts(
      insuranceExpiringSoon: false,
      insuranceExpired: false,
      // Deadline already in the past: the snapshot lingers but is no longer
      // an active restriction.
      noFlyStatus: _status(untilOffset: const Duration(minutes: -1)),
    );
    expect(alerts.hasActiveNoFly, isFalse);
    expect(alerts.hasAlerts, isFalse);
    expect(alerts.alertCount, 0);
  });

  test('expired no-fly does not inflate the count alongside insurance', () {
    final alerts = DashboardAlerts(
      insuranceExpiringSoon: false,
      insuranceExpired: true,
      noFlyStatus: _status(untilOffset: const Duration(minutes: -1)),
    );
    expect(alerts.hasActiveNoFly, isFalse);
    expect(alerts.alertCount, 1);
  });
}
