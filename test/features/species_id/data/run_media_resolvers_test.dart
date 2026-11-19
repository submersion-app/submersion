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

  test('counts items with no file here, not photo library items', () {
    final count = notOnDeviceCount([
      item('a', path: '/here.jpg'),
      item('b', path: '/gone.jpg'),
      item('c'),
      item('d', asset: 'PH-1'),
    ], fileExists: (path) => path == '/here.jpg');
    expect(count, 2);
  });
}
