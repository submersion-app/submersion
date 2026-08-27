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
