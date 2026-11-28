import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/data/services/run_media_resolvers.dart';

/// Before a run downloads anything, it says how many items it must fetch
/// (issue #4727).
void main() {
  MediaItem item(String id, {String? path, String? asset}) => MediaItem(
    id: id,
    mediaType: MediaType.photo,
    localPath: path,
    platformAssetId: asset,
    takenAt: DateTime.utc(2026),
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  test('counts items with no file here, and library items whose original '
      'is not here', () async {
    final count = await notOnDeviceCount(
      [
        item('a', path: '/here.jpg'),
        item('b', path: '/gone.jpg'),
        item('c'),
        item('d', asset: 'PH-1'),
      ],
      fileExists: (path) => path == '/here.jpg',
      libraryOriginalHere: (_) async => true,
    );
    expect(count, 2);
  });

  test('a photo library item whose original is only in iCloud is counted: '
      'a run would download it', () async {
    final count = await notOnDeviceCount([
      item('a', asset: 'PH-1'),
      item('b', asset: 'PH-2'),
    ], libraryOriginalHere: (m) async => m.id == 'a');
    expect(count, 1);
  });

  test('media already checked with the installed model is not counted: the '
      'run will not open it', () async {
    final count = await notOnDeviceCount(
      [item('b', path: '/gone.jpg'), item('c'), item('e', asset: 'PH-3')],
      fileExists: (_) => false,
      libraryOriginalHere: (_) async => false,
      checked: const {'b', 'e'},
    );
    expect(count, 1);
  });

  test('library items are checked together, not one after another', () async {
    final asked = <String>[];
    final answer = Completer<bool>();
    final count = notOnDeviceCount(
      [item('a', asset: 'PH-1'), item('b', asset: 'PH-2')],
      libraryOriginalHere: (m) {
        asked.add(m.id);
        return answer.future;
      },
    );
    await pumpEventQueue();

    expect(asked, ['a', 'b']);
    answer.complete(false);
    expect(await count, 2);
  });

  test(
    'no more than eight library lookups run at once (issue #5127)',
    () async {
      var inFlight = 0;
      var most = 0;
      final count = await notOnDeviceCount(
        [for (var i = 0; i < 30; i++) item('m$i', asset: 'PH-$i')],
        libraryOriginalHere: (_) async {
          inFlight++;
          if (inFlight > most) most = inFlight;
          await Future<void>.delayed(Duration.zero);
          inFlight--;
          return false;
        },
      );
      expect(count, 30);
      expect(most, lessThanOrEqualTo(8));
      expect(most, greaterThan(1));
    },
  );

  group('isOnDevice', () {
    bool exists(String path) => path == '/here.jpg';
    Future<bool> library(MediaItem _) async => true;

    test('a file that exists is here, a missing one is not', () async {
      expect(
        await isOnDevice(
          item('a', path: '/here.jpg'),
          libraryOriginalHere: library,
          fileExists: exists,
        ),
        isTrue,
      );
      expect(
        await isOnDevice(
          item('b', path: '/gone.jpg'),
          libraryOriginalHere: library,
          fileExists: exists,
        ),
        isFalse,
      );
    });

    test('an item with no file of its own (a manifest or URL entry) is '
        'not here: reading it fetches it', () async {
      expect(
        await isOnDevice(
          item('c'),
          libraryOriginalHere: library,
          fileExists: exists,
        ),
        isFalse,
      );
    });

    test('a library item is here when its original is', () async {
      expect(
        await isOnDevice(
          item('a', asset: 'PH-1'),
          libraryOriginalHere: (_) async => true,
        ),
        isTrue,
      );
      expect(
        await isOnDevice(
          item('b', asset: 'PH-2'),
          libraryOriginalHere: (_) async => false,
        ),
        isFalse,
      );
    });
  });
}
