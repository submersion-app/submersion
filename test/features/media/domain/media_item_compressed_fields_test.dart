import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

MediaItem base() => MediaItem(
  id: 'm1',
  mediaType: MediaType.photo,
  takenAt: DateTime(2026, 1, 1),
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  test('copyWith sets and clears remoteCompressedUploadedAt', () {
    final withStamp = base().copyWith(
      remoteCompressedUploadedAt: DateTime(2026, 2, 2),
    );
    expect(withStamp.remoteCompressedUploadedAt, DateTime(2026, 2, 2));
    final cleared = withStamp.copyWith(remoteCompressedUploadedAt: null);
    expect(cleared.remoteCompressedUploadedAt, isNull);
  });

  test('copyWith leaves compressedLevel untouched when omitted', () {
    final a = base().copyWith(compressedLevel: 'balanced');
    final b = a.copyWith(caption: 'hi');
    expect(b.compressedLevel, 'balanced');
  });

  test('compressed fields participate in equality', () {
    expect(
      base().copyWith(compressedSizeBytes: 10),
      isNot(equals(base().copyWith(compressedSizeBytes: 20))),
    );
  });
}
