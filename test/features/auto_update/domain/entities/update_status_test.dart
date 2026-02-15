import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/auto_update/domain/entities/update_status.dart';

void main() {
  group('UpdateStatus', () {
    group('UpToDate', () {
      test('can be instantiated', () {
        const status = UpToDate();
        expect(status, isA<UpdateStatus>());
        expect(status, isA<UpToDate>());
      });
    });

    group('Checking', () {
      test('can be instantiated', () {
        const status = Checking();
        expect(status, isA<UpdateStatus>());
        expect(status, isA<Checking>());
      });
    });

    group('UpdateAvailable', () {
      test('can be instantiated with required fields', () {
        const status = UpdateAvailable(
          version: '2.0.0',
          downloadUrl: 'https://example.com/download',
        );
        expect(status, isA<UpdateStatus>());
        expect(status, isA<UpdateAvailable>());
      });

      test('has accessible fields', () {
        const status = UpdateAvailable(
          version: '2.0.0',
          releaseNotes: 'Bug fixes and improvements',
          downloadUrl: 'https://example.com/download',
        );
        expect(status.version, '2.0.0');
        expect(status.releaseNotes, 'Bug fixes and improvements');
        expect(status.downloadUrl, 'https://example.com/download');
      });

      test('releaseNotes defaults to null', () {
        const status = UpdateAvailable(
          version: '2.0.0',
          downloadUrl: 'https://example.com/download',
        );
        expect(status.releaseNotes, isNull);
      });
    });

    group('Downloading', () {
      test('can be instantiated', () {
        const status = Downloading(progress: 0.5);
        expect(status, isA<UpdateStatus>());
        expect(status, isA<Downloading>());
      });

      test('has accessible progress field', () {
        const status = Downloading(progress: 0.75);
        expect(status.progress, 0.75);
      });
    });

    group('ReadyToInstall', () {
      test('can be instantiated', () {
        const status = ReadyToInstall(
          version: '2.0.0',
          localPath: '/tmp/update.dmg',
        );
        expect(status, isA<UpdateStatus>());
        expect(status, isA<ReadyToInstall>());
      });

      test('has accessible fields', () {
        const status = ReadyToInstall(
          version: '2.0.0',
          localPath: '/tmp/update.dmg',
        );
        expect(status.version, '2.0.0');
        expect(status.localPath, '/tmp/update.dmg');
      });
    });

    group('UpdateError', () {
      test('can be instantiated', () {
        const status = UpdateError(message: 'Network error');
        expect(status, isA<UpdateStatus>());
        expect(status, isA<UpdateError>());
      });

      test('has accessible message field', () {
        const status = UpdateError(message: 'Network error');
        expect(status.message, 'Network error');
      });
    });
  });
}
