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
}
