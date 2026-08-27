import 'dart:async';
import 'dart:io';

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

  group('newExpiringProbe', () {
    test('system-volume paths never reach the filesystem', () async {
      var calls = 0;
      final s = VolumeStatus(
        directoryExists: (_) async {
          calls++;
          return true;
        },
      );
      final probe = s.newExpiringProbe(
        ttl: const Duration(seconds: 5),
        platformOverride: 'macos',
      );

      expect(await probe('/Users/eric/a.jpg'), isTrue);
      // An all-internal-disk library must pay nothing at all for this.
      expect(calls, 0);
    });

    test('a screenful of tiles on one root costs one probe', () async {
      var calls = 0;
      final s = VolumeStatus(
        directoryExists: (_) async {
          calls++;
          return false;
        },
      );
      final probe = s.newExpiringProbe(
        ttl: const Duration(seconds: 5),
        platformOverride: 'macos',
      );

      final answers = await Future.wait([
        for (var i = 0; i < 60; i++) probe('/Volumes/NAS/photo$i.jpg'),
      ]);

      expect(calls, 1);
      expect(answers.every((online) => !online), isTrue);
    });

    test('each mount root is probed separately', () async {
      final probed = <String>[];
      final s = VolumeStatus(
        directoryExists: (p) async {
          probed.add(p);
          return true;
        },
      );
      final probe = s.newExpiringProbe(
        ttl: const Duration(seconds: 5),
        platformOverride: 'macos',
      );

      await probe('/Volumes/NAS/a.jpg');
      await probe('/Volumes/Archive/b.jpg');
      await probe('/Volumes/NAS/c.jpg');

      expect(probed, ['/Volumes/NAS', '/Volumes/Archive']);
    });

    test('the memo is reused inside the ttl', () async {
      var calls = 0;
      var clock = DateTime(2026, 8, 19, 12);
      final s = VolumeStatus(
        directoryExists: (_) async {
          calls++;
          return true;
        },
      );
      final probe = s.newExpiringProbe(
        ttl: const Duration(seconds: 5),
        clock: () => clock,
        platformOverride: 'macos',
      );

      await probe('/Volumes/NAS/a.jpg');
      clock = clock.add(const Duration(seconds: 4));
      await probe('/Volumes/NAS/b.jpg');

      expect(calls, 1);
    });

    test('a remount is seen one ttl later', () async {
      var mounted = false;
      var clock = DateTime(2026, 8, 19, 12);
      final s = VolumeStatus(directoryExists: (_) async => mounted);
      final probe = s.newExpiringProbe(
        ttl: const Duration(seconds: 5),
        clock: () => clock,
        platformOverride: 'macos',
      );

      expect(await probe('/Volumes/NAS/a.jpg'), isFalse);
      mounted = true;
      expect(await probe('/Volumes/NAS/a.jpg'), isFalse, reason: 'inside ttl');

      clock = clock.add(const Duration(seconds: 5));
      // The bounded window is the whole reason a long-lived caller may hold
      // this memo: a cache that never expired would keep reporting the
      // volume offline after the user plugged it back in.
      expect(await probe('/Volumes/NAS/a.jpg'), isTrue);
    });

    test('an in-flight probe never expires, however long it hangs', () async {
      var calls = 0;
      var clock = DateTime(2026, 8, 19, 12);
      final hung = Completer<bool>();
      final s = VolumeStatus(
        directoryExists: (_) {
          calls++;
          return hung.future;
        },
      );
      final probe = s.newExpiringProbe(
        ttl: const Duration(seconds: 5),
        clock: () => clock,
        platformOverride: 'macos',
      );

      final first = probe('/Volumes/NAS/a.jpg');
      // A hung mount outlives the ttl by a wide margin. Expiring the probe
      // here would let the next tile park a SECOND dart:io pool thread on
      // the same dead share, which is exactly the stall the memo exists to
      // prevent.
      clock = clock.add(const Duration(minutes: 1));
      final second = probe('/Volumes/NAS/b.jpg');

      expect(calls, 1);
      hung.complete(false);
      expect(await first, isFalse);
      expect(await second, isFalse);
    });

    test(
      'the ttl runs from completion, not from the start of the probe',
      () async {
        var calls = 0;
        var clock = DateTime(2026, 8, 19, 12);
        final slow = Completer<bool>();
        final s = VolumeStatus(
          directoryExists: (_) {
            calls++;
            return calls == 1 ? slow.future : Future.value(true);
          },
        );
        final probe = s.newExpiringProbe(
          ttl: const Duration(seconds: 5),
          clock: () => clock,
          platformOverride: 'macos',
        );

        final first = probe('/Volumes/NAS/a.jpg');
        clock = clock.add(const Duration(seconds: 30));
        slow.complete(false);
        expect(await first, isFalse);

        // Completed 30s after it started, but only just now: the entry is
        // fresh from this instant, not already 30s stale.
        await probe('/Volumes/NAS/b.jpg');
        expect(calls, 1);

        clock = clock.add(const Duration(seconds: 5));
        await probe('/Volumes/NAS/c.jpg');
        expect(calls, 2);
      },
    );

    test(
      'a probe that throws is memoized too, then retried after the ttl',
      () async {
        var calls = 0;
        var clock = DateTime(2026, 8, 19, 12);
        final s = VolumeStatus(
          directoryExists: (_) async {
            calls++;
            throw const FileSystemException('share unreachable');
          },
        );
        final probe = s.newExpiringProbe(
          ttl: const Duration(seconds: 5),
          clock: () => clock,
          platformOverride: 'macos',
        );

        await expectLater(
          probe('/Volumes/NAS/a.jpg'),
          throwsA(isA<FileSystemException>()),
        );
        // A throw still cost a filesystem round-trip, so re-running it per
        // tile is the same stall as never memoizing.
        await expectLater(
          probe('/Volumes/NAS/b.jpg'),
          throwsA(isA<FileSystemException>()),
        );
        expect(calls, 1);

        clock = clock.add(const Duration(seconds: 5));
        await expectLater(
          probe('/Volumes/NAS/c.jpg'),
          throwsA(isA<FileSystemException>()),
        );
        expect(calls, 2);
      },
    );
  });
}
