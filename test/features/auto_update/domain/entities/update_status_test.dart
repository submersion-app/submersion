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

      test('two instances are equal', () {
        const a = UpToDate();
        const b = UpToDate();
        expect(a, equals(b));
      });
    });

    group('Checking', () {
      test('can be instantiated', () {
        const status = Checking();
        expect(status, isA<UpdateStatus>());
        expect(status, isA<Checking>());
      });

      test('two instances are equal', () {
        const a = Checking();
        const b = Checking();
        expect(a, equals(b));
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

      test('two instances with same fields are equal', () {
        const a = UpdateAvailable(
          version: '2.0.0',
          releaseNotes: 'Notes',
          downloadUrl: 'https://example.com/download',
        );
        const b = UpdateAvailable(
          version: '2.0.0',
          releaseNotes: 'Notes',
          downloadUrl: 'https://example.com/download',
        );
        expect(a, equals(b));
      });

      test('instances with different fields are not equal', () {
        const a = UpdateAvailable(
          version: '2.0.0',
          downloadUrl: 'https://example.com/download',
        );
        const b = UpdateAvailable(
          version: '3.0.0',
          downloadUrl: 'https://example.com/download',
        );
        expect(a, isNot(equals(b)));
      });

      test('copyWith returns new instance with updated fields', () {
        const original = UpdateAvailable(
          version: '2.0.0',
          releaseNotes: 'Notes',
          downloadUrl: 'https://example.com/download',
        );
        final updated = original.copyWith(version: '3.0.0');
        expect(updated.version, '3.0.0');
        expect(updated.releaseNotes, 'Notes');
        expect(updated.downloadUrl, 'https://example.com/download');
        expect(updated, isNot(same(original)));
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

      test('two instances with same progress are equal', () {
        const a = Downloading(progress: 0.5);
        const b = Downloading(progress: 0.5);
        expect(a, equals(b));
      });

      test('instances with different progress are not equal', () {
        const a = Downloading(progress: 0.3);
        const b = Downloading(progress: 0.7);
        expect(a, isNot(equals(b)));
      });

      test('progress below 0.0 throws AssertionError', () {
        expect(
          () => Downloading(progress: -0.1),
          throwsA(isA<AssertionError>()),
        );
      });

      test('progress above 1.0 throws AssertionError', () {
        expect(
          () => Downloading(progress: 1.1),
          throwsA(isA<AssertionError>()),
        );
      });

      test('progress at boundary values is valid', () {
        const zero = Downloading(progress: 0.0);
        const one = Downloading(progress: 1.0);
        expect(zero.progress, 0.0);
        expect(one.progress, 1.0);
      });

      test('copyWith returns new instance with updated progress', () {
        const original = Downloading(progress: 0.3);
        final updated = original.copyWith(progress: 0.8);
        expect(updated.progress, 0.8);
        expect(updated, isNot(same(original)));
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

      test('two instances with same fields are equal', () {
        const a = ReadyToInstall(
          version: '2.0.0',
          localPath: '/tmp/update.dmg',
        );
        const b = ReadyToInstall(
          version: '2.0.0',
          localPath: '/tmp/update.dmg',
        );
        expect(a, equals(b));
      });

      test('instances with different fields are not equal', () {
        const a = ReadyToInstall(
          version: '2.0.0',
          localPath: '/tmp/update.dmg',
        );
        const b = ReadyToInstall(version: '2.0.0', localPath: '/tmp/other.dmg');
        expect(a, isNot(equals(b)));
      });

      test('copyWith returns new instance with updated fields', () {
        const original = ReadyToInstall(
          version: '2.0.0',
          localPath: '/tmp/update.dmg',
        );
        final updated = original.copyWith(localPath: '/tmp/new.dmg');
        expect(updated.version, '2.0.0');
        expect(updated.localPath, '/tmp/new.dmg');
        expect(updated, isNot(same(original)));
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

      test('two instances with same message are equal', () {
        const a = UpdateError(message: 'Network error');
        const b = UpdateError(message: 'Network error');
        expect(a, equals(b));
      });

      test('instances with different messages are not equal', () {
        const a = UpdateError(message: 'Network error');
        const b = UpdateError(message: 'Disk full');
        expect(a, isNot(equals(b)));
      });

      test('copyWith returns new instance with updated message', () {
        const original = UpdateError(message: 'Network error');
        final updated = original.copyWith(message: 'Timeout');
        expect(updated.message, 'Timeout');
        expect(updated, isNot(same(original)));
      });
    });
  });
}
