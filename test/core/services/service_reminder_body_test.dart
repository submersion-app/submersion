import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/notification_service.dart';

void main() {
  String body(int daysBefore) => NotificationService.serviceReminderBody(
    prefix: 'Apeks XTX50',
    kindName: 'Regulator service',
    daysBefore: daysBefore,
  );

  test('daysBefore == 0 reads "due today", not overdue', () {
    expect(body(0), 'Apeks XTX50: Regulator service is due today');
  });

  test('negative daysBefore degrades to "due today"', () {
    expect(body(-3), 'Apeks XTX50: Regulator service is due today');
  });

  test('daysBefore == 1 reads "due tomorrow", not "1 days"', () {
    final result = body(1);
    expect(result, 'Apeks XTX50: Regulator service is due tomorrow');
    expect(result, isNot(contains('1 days')));
  });

  test('daysBefore > 1 reads "due in N days"', () {
    expect(body(14), 'Apeks XTX50: Regulator service is due in 14 days');
  });
}
