import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/providers/storage_usage_providers.dart';

void main() {
  group('backupsPathToMeasure', () {
    test('falls back to the app default when nothing is configured', () async {
      expect(
        await backupsPathToMeasure(
          configuredLocation: null,
          defaultPath: () async => '/app/default',
        ),
        '/app/default',
      );
      expect(
        await backupsPathToMeasure(
          configuredLocation: '',
          defaultPath: () async => '/app/default',
        ),
        '/app/default',
      );
    });

    test('measures a configured filesystem location', () async {
      expect(
        await backupsPathToMeasure(
          configuredLocation: '/Volumes/Backups/Submersion',
          defaultPath: () async => '/app/default',
        ),
        '/Volumes/Backups/Submersion',
      );
    });

    test('reports null for an Android SAF tree URI', () async {
      // There is no Directory behind a content:// URI, so it cannot be walked.
      // Reporting it as 0 bytes would tell the user their backups had vanished,
      // and this null is the whole reason measure() returns a nullable int.
      expect(
        await backupsPathToMeasure(
          configuredLocation:
              'content://com.android.externalstorage.documents'
              '/tree/primary%3ASubmersion',
          defaultPath: () async => '/app/default',
        ),
        isNull,
      );
    });

    test('never resolves the app default when it is not needed', () async {
      // resolveDefaultBackupsDirectory creates the directory when it is
      // missing. Measuring storage must not have that side effect on a device
      // whose backups live somewhere else.
      var resolved = false;
      Future<String> defaultPath() async {
        resolved = true;
        return '/app/default';
      }

      await backupsPathToMeasure(
        configuredLocation: '/custom/location',
        defaultPath: defaultPath,
      );
      expect(resolved, isFalse);

      await backupsPathToMeasure(
        configuredLocation: 'content://tree/whatever',
        defaultPath: defaultPath,
      );
      expect(resolved, isFalse);

      await backupsPathToMeasure(
        configuredLocation: null,
        defaultPath: defaultPath,
      );
      expect(resolved, isTrue);
    });
  });
}
