import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/resolvers/local_file_resolver.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

/// Every call here would be a file system the browser lacks.
class _NoBookmarks extends Fake implements LocalBookmarkStorage {}

/// A page has no file system (issue #4121): a row that points at a file
/// on some device reads as from another device, without a single read.
void main() {
  test('a local file row is from another device, untouched', () async {
    final resolver = LocalFileResolver(
      bookmarkStorage: _NoBookmarks(),
      platform: LocalMediaPlatform(),
      isWeb: () => true,
      deviceLabel: (id) async => 'Erics-MacBook-Pro',
    );
    final item = MediaItem(
      id: 'x',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.localFile,
      localPath: '/Users/eric/Pictures/dive.jpg',
      originDeviceId: 'mac',
      takenAt: DateTime.utc(2024),
      createdAt: DateTime.utc(2024),
      updatedAt: DateTime.utc(2024),
    );
    final data = await resolver.resolve(item);
    expect(data, isA<UnavailableData>());
    final unavailable = data as UnavailableData;
    expect(unavailable.kind, UnavailableKind.fromOtherDevice);
    expect(unavailable.originDeviceLabel, 'Erics-MacBook-Pro');
  });
}
