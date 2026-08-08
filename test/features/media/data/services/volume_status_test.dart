import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/volume_status.dart';

void main() {
  VolumeStatus statusWith(Set<String> existing) =>
      VolumeStatus(directoryExists: (p) async => existing.contains(p));

  group('macOS', () {
    test('paths under /Volumes are governed by the volume root', () async {
      final s = statusWith({'/Volumes/NAS'});
      expect(
        s.volumeRootOf('/Volumes/NAS/photos/a.jpg', platformOverride: 'macos'),
        '/Volumes/NAS',
      );
      expect(
        await s.isVolumeOnline(
          '/Volumes/NAS/photos/a.jpg',
          platformOverride: 'macos',
        ),
        isTrue,
      );
      expect(
        await s.isVolumeOnline(
          '/Volumes/Other/photos/a.jpg',
          platformOverride: 'macos',
        ),
        isFalse,
      );
    });

    test('system-volume paths are always online', () async {
      final s = statusWith({});
      expect(
        s.volumeRootOf('/Users/eric/a.jpg', platformOverride: 'macos'),
        isNull,
      );
      expect(
        await s.isVolumeOnline('/Users/eric/a.jpg', platformOverride: 'macos'),
        isTrue,
      );
    });
  });

  group('Windows', () {
    test('UNC paths are governed by the share root', () async {
      final s = statusWith({r'\\nas\photos'});
      expect(
        s.volumeRootOf(r'\\nas\photos\2026\a.jpg', platformOverride: 'windows'),
        r'\\nas\photos',
      );
      expect(
        await s.isVolumeOnline(
          r'\\nas\photos\2026\a.jpg',
          platformOverride: 'windows',
        ),
        isTrue,
      );
      expect(
        await s.isVolumeOnline(
          r'\\gone\share\a.jpg',
          platformOverride: 'windows',
        ),
        isFalse,
      );
    });

    test('mapped drives are probed; C: is always online', () async {
      final s = statusWith({r'Z:\'});
      expect(
        await s.isVolumeOnline(r'Z:\photos\a.jpg', platformOverride: 'windows'),
        isTrue,
      );
      expect(
        await s.isVolumeOnline(r'Y:\photos\a.jpg', platformOverride: 'windows'),
        isFalse,
      );
      expect(
        await s.isVolumeOnline(r'C:\photos\a.jpg', platformOverride: 'windows'),
        isTrue,
      );
    });
  });

  group('Linux', () {
    test('a file directly under a single-segment media mount resolves to '
        'the directory root, never the file itself', () async {
      final s = statusWith({'/media/usb'});
      expect(
        s.volumeRootOf('/media/usb/a.jpg', platformOverride: 'linux'),
        '/media/usb',
        reason: 'the optional second segment must not swallow the filename',
      );
      expect(
        await s.isVolumeOnline('/media/usb/a.jpg', platformOverride: 'linux'),
        isTrue,
      );
    });

    test('run/media mount roots are probed', () async {
      final s = statusWith({'/run/media/eric/nas'});
      expect(
        s.volumeRootOf(
          '/run/media/eric/nas/photos/a.jpg',
          platformOverride: 'linux',
        ),
        '/run/media/eric/nas',
      );
      expect(
        await s.isVolumeOnline(
          '/run/media/eric/nas/photos/a.jpg',
          platformOverride: 'linux',
        ),
        isTrue,
      );
      expect(
        await s.isVolumeOnline(
          '/run/media/eric/gone/a.jpg',
          platformOverride: 'linux',
        ),
        isFalse,
      );
    });

    test('mnt and media mount roots are probed', () async {
      final s = statusWith({'/mnt/nas', '/media/eric/usb'});
      expect(
        await s.isVolumeOnline('/mnt/nas/a.jpg', platformOverride: 'linux'),
        isTrue,
      );
      expect(
        await s.isVolumeOnline('/mnt/gone/a.jpg', platformOverride: 'linux'),
        isFalse,
      );
      expect(
        await s.isVolumeOnline(
          '/media/eric/usb/a.jpg',
          platformOverride: 'linux',
        ),
        isTrue,
      );
      expect(
        await s.isVolumeOnline('/home/eric/a.jpg', platformOverride: 'linux'),
        isTrue,
      );
    });
  });

  group('pass probe', () {
    test('probes each mount root once per pass', () async {
      final probed = <String>[];
      final s = VolumeStatus(
        directoryExists: (p) async {
          probed.add(p);
          return p == '/Volumes/NAS';
        },
      );
      final probe = s.newPassProbe(platformOverride: 'macos');

      expect(await probe('/Volumes/NAS/a.jpg'), isTrue);
      expect(await probe('/Volumes/NAS/b.jpg'), isTrue);
      expect(await probe('/Volumes/NAS/deep/c.jpg'), isTrue);
      expect(await probe('/Volumes/Gone/d.jpg'), isFalse);
      expect(await probe('/Volumes/Gone/e.jpg'), isFalse);
      expect(await probe('/Users/eric/f.jpg'), isTrue);

      expect(probed, ['/Volumes/NAS', '/Volumes/Gone']);
    });

    test(
      'concurrent probes of one root share a single filesystem call',
      () async {
        var calls = 0;
        final s = VolumeStatus(
          directoryExists: (p) async {
            calls++;
            return true;
          },
        );
        final probe = s.newPassProbe(platformOverride: 'macos');

        await Future.wait([
          probe('/Volumes/NAS/a.jpg'),
          probe('/Volumes/NAS/b.jpg'),
          probe('/Volumes/NAS/c.jpg'),
        ]);

        expect(calls, 1);
      },
    );

    test('a fresh probe sees a remount', () async {
      var mounted = false;
      final s = VolumeStatus(directoryExists: (p) async => mounted);

      final first = s.newPassProbe(platformOverride: 'macos');
      expect(await first('/Volumes/NAS/a.jpg'), isFalse);

      mounted = true;
      expect(await first('/Volumes/NAS/a.jpg'), isFalse, reason: 'same pass');
      final second = s.newPassProbe(platformOverride: 'macos');
      expect(await second('/Volumes/NAS/a.jpg'), isTrue);
    });
  });
}
