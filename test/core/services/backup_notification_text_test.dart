import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/notification_service.dart';

void main() {
  group('title', () {
    test('a backup that reached the cloud, or was never meant to, reads as a '
        'plain completion', () {
      expect(
        NotificationService.backupNotificationTitle(
          success: true,
          cloudCopyMissing: false,
        ),
        'Backup Complete',
      );
    });

    test(
      'a local-only fallback is still a completed backup, not a failure',
      () {
        expect(
          NotificationService.backupNotificationTitle(
            success: true,
            cloudCopyMissing: true,
          ),
          'Backup Complete (device only)',
        );
      },
    );

    // Issue #3782: the main copy is in the cloud, so "device only" would be
    // wrong; the title still says not every copy arrived.
    test('a missed extra copy qualifies the title without "device only"', () {
      expect(
        NotificationService.backupNotificationTitle(
          success: true,
          cloudCopyMissing: false,
          extraCopyMissing: true,
        ),
        'Backup Complete (not every account)',
      );
    });

    test('a missing main copy wins over a missed extra copy', () {
      expect(
        NotificationService.backupNotificationTitle(
          success: true,
          cloudCopyMissing: true,
          extraCopyMissing: true,
        ),
        'Backup Complete (device only)',
      );
    });

    test('a failed backup reads as a failure', () {
      expect(
        NotificationService.backupNotificationTitle(
          success: false,
          cloudCopyMissing: false,
        ),
        'Backup Failed',
      );
    });
  });

  group('body', () {
    test('a cloud backup that landed says so plainly', () {
      expect(
        NotificationService.backupNotificationBody(
          success: true,
          cloudCopyMissing: false,
        ),
        'Your dive data has been backed up successfully.',
      );
    });

    test('a local-only fallback names the missing cloud copy: silence here is '
        'what let issue #969 go unreported', () {
      final body = NotificationService.backupNotificationBody(
        success: true,
        cloudCopyMissing: true,
      );
      expect(body, contains('on this device'));
      expect(body, contains('cloud'));
      expect(
        body,
        isNot(contains('successfully')),
        reason: 'an unqualified success reads as "the cloud copy is safe"',
      );
    });

    test('a missed extra copy says the backup is off the device but did not '
        'reach every account', () {
      final body = NotificationService.backupNotificationBody(
        success: true,
        cloudCopyMissing: false,
        extraCopyMissing: true,
      );
      expect(body, contains('every account'));
      expect(body, isNot(contains('on this device')));
      expect(body, isNot(contains('successfully')));
    });

    test('a failure carries the reason when there is one', () {
      expect(
        NotificationService.backupNotificationBody(
          success: false,
          cloudCopyMissing: false,
          error: 'disk full',
        ),
        'Automatic backup failed: disk full',
      );
    });

    test('a failure without a reason suggests the manual path', () {
      expect(
        NotificationService.backupNotificationBody(
          success: false,
          cloudCopyMissing: false,
        ),
        'Automatic backup failed. Please try a manual backup.',
      );
    });

    test('a failure ignores cloudCopyMissing: nothing was written at all', () {
      expect(
        NotificationService.backupNotificationBody(
          success: false,
          cloudCopyMissing: true,
        ),
        'Automatic backup failed. Please try a manual backup.',
      );
    });
  });
}
