import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_map_point.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

MediaItem _item({
  DateTime? remoteUploadedAt,
  DateTime? remoteThumbUploadedAt,
  DateTime? updatedAt,
  String? contentHash,
  bool isFavorite = false,
  String? thumbnailPath,
}) => MediaItem(
  id: 'm1',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.localFile,
  filePath: p.join('media', 'm1'),
  takenAt: DateTime.utc(2026, 6, 1),
  createdAt: DateTime.utc(2026, 6, 1),
  updatedAt: updatedAt ?? DateTime.utc(2026, 6, 1),
  remoteUploadedAt: remoteUploadedAt,
  remoteThumbUploadedAt: remoteThumbUploadedAt,
  contentHash: contentHash,
  isFavorite: isFavorite,
  thumbnailPath: thumbnailPath,
);

MediaMapPoint _point(MediaItem item) => MediaMapPoint(
  entry: MediaLibraryEntry(item: item, siteName: 'Blue Hole'),
  point: const LatLng(12.5, 43.2),
  placement: MediaPlacement.diveSite,
  placeLabel: 'Blue Hole',
);

void main() {
  test('a media-store upload makes a map point unequal', () {
    // The tile resolver's store fallback reads the hash and upload stamps,
    // so a tile on a device without the local file needs the fresh item.
    // Cluster stability is the widget's job, not equality's.
    final before = _point(_item());
    final after = _point(
      _item(
        remoteUploadedAt: DateTime.utc(2026, 9, 25),
        remoteThumbUploadedAt: DateTime.utc(2026, 9, 25),
        updatedAt: DateTime.utc(2026, 9, 25, 12),
        contentHash: 'abc123',
      ),
    );

    expect(after, isNot(before));
  });

  test('a favorite toggle makes a map point unequal', () {
    expect(_point(_item(isFavorite: true)), isNot(_point(_item())));
  });

  test('a new thumbnail makes a map point unequal', () {
    expect(
      _point(_item(thumbnailPath: p.join('thumbs', 'm1.jpg'))),
      isNot(_point(_item())),
    );
  });
}
