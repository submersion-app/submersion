import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/volume_status.dart';

void main() {
  VolumeStatus statusWith(Set<String> existing) =>
      VolumeStatus(directoryExists: existing.contains);

  group('macOS', () {
    test('paths under /Volumes are governed by the volume root', () {
      final s = statusWith({'/Volumes/NAS'});
      expect(
        s.volumeRootOf('/Volumes/NAS/photos/a.jpg', platformOverride: 'macos'),
        '/Volumes/NAS',
      );
      expect(
        s.isVolumeOnline(
          '/Volumes/NAS/photos/a.jpg',
          platformOverride: 'macos',
        ),
        isTrue,
      );
      expect(
        s.isVolumeOnline(
          '/Volumes/Other/photos/a.jpg',
          platformOverride: 'macos',
        ),
        isFalse,
      );
    });

    test('system-volume paths are always online', () {
      final s = statusWith({});
      expect(
        s.volumeRootOf('/Users/eric/a.jpg', platformOverride: 'macos'),
        isNull,
      );
      expect(
        s.isVolumeOnline('/Users/eric/a.jpg', platformOverride: 'macos'),
        isTrue,
      );
    });
  });

  group('Windows', () {
    test('UNC paths are governed by the share root', () {
      final s = statusWith({r'\\nas\photos'});
      expect(
        s.volumeRootOf(r'\\nas\photos\2026\a.jpg', platformOverride: 'windows'),
        r'\\nas\photos',
      );
      expect(
        s.isVolumeOnline(
          r'\\nas\photos\2026\a.jpg',
          platformOverride: 'windows',
        ),
        isTrue,
      );
      expect(
        s.isVolumeOnline(r'\\gone\share\a.jpg', platformOverride: 'windows'),
        isFalse,
      );
    });

    test('mapped drives are probed; C: is always online', () {
      final s = statusWith({r'Z:\'});
      expect(
        s.isVolumeOnline(r'Z:\photos\a.jpg', platformOverride: 'windows'),
        isTrue,
      );
      expect(
        s.isVolumeOnline(r'Y:\photos\a.jpg', platformOverride: 'windows'),
        isFalse,
      );
      expect(
        s.isVolumeOnline(r'C:\photos\a.jpg', platformOverride: 'windows'),
        isTrue,
      );
    });
  });

  group('Linux', () {
    test('a file directly under a single-segment media mount resolves to '
        'the directory root, never the file itself', () {
      final s = statusWith({'/media/usb'});
      expect(
        s.volumeRootOf('/media/usb/a.jpg', platformOverride: 'linux'),
        '/media/usb',
        reason: 'the optional second segment must not swallow the filename',
      );
      expect(
        s.isVolumeOnline('/media/usb/a.jpg', platformOverride: 'linux'),
        isTrue,
      );
    });

    test('run/media mount roots are probed', () {
      final s = statusWith({'/run/media/eric/nas'});
      expect(
        s.volumeRootOf(
          '/run/media/eric/nas/photos/a.jpg',
          platformOverride: 'linux',
        ),
        '/run/media/eric/nas',
      );
      expect(
        s.isVolumeOnline(
          '/run/media/eric/nas/photos/a.jpg',
          platformOverride: 'linux',
        ),
        isTrue,
      );
      expect(
        s.isVolumeOnline(
          '/run/media/eric/gone/a.jpg',
          platformOverride: 'linux',
        ),
        isFalse,
      );
    });

    test('mnt and media mount roots are probed', () {
      final s = statusWith({'/mnt/nas', '/media/eric/usb'});
      expect(
        s.isVolumeOnline('/mnt/nas/a.jpg', platformOverride: 'linux'),
        isTrue,
      );
      expect(
        s.isVolumeOnline('/mnt/gone/a.jpg', platformOverride: 'linux'),
        isFalse,
      );
      expect(
        s.isVolumeOnline('/media/eric/usb/a.jpg', platformOverride: 'linux'),
        isTrue,
      );
      expect(
        s.isVolumeOnline('/home/eric/a.jpg', platformOverride: 'linux'),
        isTrue,
      );
    });
  });
}
