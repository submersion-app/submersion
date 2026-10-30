import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/trips/domain/entities/trip_media_preview.dart';

void main() {
  MediaItem item(String id, int minute) => MediaItem(
    id: id,
    mediaType: MediaType.photo,
    takenAt: DateTime.utc(2026, 3, 8, 9, minute),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  DiveMediaPreview dive(List<MediaItem> items, {int? count}) =>
      DiveMediaPreview(
        items: items,
        mediaCount: count ?? items.length,
        photoCount: count ?? items.length,
      );

  test('an empty preview has no items or count', () {
    expect(TripMediaPreview.empty.mediaCount, 0);
    expect(TripMediaPreview.empty.earliest(5), isEmpty);
  });

  test('mediaCount totals the dives, not the preview items', () {
    final preview = TripMediaPreview(
      byDiveId: {
        'a': dive([item('a1', 0)], count: 12),
        'b': dive([item('b1', 1)], count: 3),
      },
    );

    expect(preview.mediaCount, 15);
  });

  test('earliest merges dives chronologically, up to the limit', () {
    final preview = TripMediaPreview(
      byDiveId: {
        'a': dive([item('a1', 1), item('a2', 3), item('a3', 5)]),
        'b': dive([item('b1', 0), item('b2', 2), item('b3', 4)]),
      },
    );

    expect(preview.earliest(4).map((m) => m.id), ['b1', 'a1', 'b2', 'a2']);
  });

  test('earliest breaks a time tie by id, as the query ranks a dive', () {
    final preview = TripMediaPreview(
      byDiveId: {
        'a': dive([item('m2', 0)]),
        'b': dive([item('m1', 0)]),
      },
    );

    expect(preview.earliest(2).map((m) => m.id), ['m1', 'm2']);
  });

  test('copyWith replaces only what it is given', () {
    final original = dive([item('a', 0)], count: 4);
    final preview = TripMediaPreview(byDiveId: {'a': original});

    expect(original.copyWith(mediaCount: 9).mediaCount, 9);
    expect(original.copyWith(mediaCount: 9).photoCount, 4);
    expect(preview.copyWith(), preview);
    expect(preview.copyWith(byDiveId: const {}).mediaCount, 0);
  });
}
