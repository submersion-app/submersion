import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

void main() {
  test('defaults to no provenance and the original tier', () {
    final data = BytesData(bytes: Uint8List(0));
    expect(data.servedFrom, isNull);
    expect(data.servedTier, ServedTier.original);
  });

  test('FileData carries the stamp it was constructed with', () {
    final data = FileData(
      file: File('/tmp/x'),
      servedFrom: ServedFrom.storeCache,
      servedTier: ServedTier.thumbnail,
    );
    expect(data.servedFrom, ServedFrom.storeCache);
    expect(data.servedTier, ServedTier.thumbnail);
    expect(data.isPoster, isFalse);
  });

  test('UnavailableData never claims a source', () {
    const data = UnavailableData(kind: UnavailableKind.notFound);
    expect(data.servedFrom, isNull);
    expect(data.kind, UnavailableKind.notFound);
  });

  test('NetworkData stamps stay const-constructible', () {
    final data = NetworkData(
      url: Uri.parse('https://example.test/a.jpg'),
      servedFrom: ServedFrom.networkUrl,
    );
    expect(data.servedFrom, ServedFrom.networkUrl);
    expect(data.servedTier, ServedTier.original);
  });
}
