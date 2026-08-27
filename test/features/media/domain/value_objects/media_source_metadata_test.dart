import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';

void main() {
  test('MediaSourceMetadata equality is value-based', () {
    final a = MediaSourceMetadata(
      takenAt: DateTime.utc(2024, 1, 1),
      latitude: 1.0,
      longitude: 2.0,
      width: 100,
      height: 200,
      durationSeconds: null,
      mimeType: 'image/jpeg',
    );
    final b = MediaSourceMetadata(
      takenAt: DateTime.utc(2024, 1, 1),
      latitude: 1.0,
      longitude: 2.0,
      width: 100,
      height: 200,
      durationSeconds: null,
      mimeType: 'image/jpeg',
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('all fields nullable except mimeType', () {
    const m = MediaSourceMetadata(mimeType: 'image/jpeg');
    expect(m.takenAt, isNull);
    expect(m.latitude, isNull);
    expect(m.width, isNull);
  });
}
