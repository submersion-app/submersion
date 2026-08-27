import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1);
  final base = MediaItem(
    id: 'm1',
    diveId: 'd1',
    mediaType: MediaType.photo,
    takenAt: now,
    createdAt: now,
    updatedAt: now,
  );

  group('MediaItem.manualElapsedSeconds', () {
    test('defaults to null, meaning the automatic position applies', () {
      expect(base.manualElapsedSeconds, isNull);
    });

    test('copyWith sets and preserves the value', () {
      final pinned = base.copyWith(manualElapsedSeconds: 720);
      expect(pinned.manualElapsedSeconds, 720);
      expect(pinned.copyWith(caption: 'x').manualElapsedSeconds, 720);
    });

    test('copyWith can clear the value back to automatic', () {
      final pinned = base.copyWith(manualElapsedSeconds: 720);
      expect(
        pinned.copyWith(manualElapsedSeconds: null).manualElapsedSeconds,
        isNull,
      );
    });

    test('participates in equality', () {
      expect(base.copyWith(manualElapsedSeconds: 720), isNot(equals(base)));
    });
  });
}
