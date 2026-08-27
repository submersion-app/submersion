import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/resolvers/signature_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

MediaItem _signature({Uint8List? imageData, String? filePath}) => MediaItem(
  id: 'x',
  mediaType: MediaType.instructorSignature,
  sourceType: MediaSourceType.signature,
  imageData: imageData,
  filePath: filePath,
  takenAt: DateTime.utc(2024, 1, 1),
  createdAt: DateTime.utc(2024, 1, 1),
  updatedAt: DateTime.utc(2024, 1, 1),
);

void main() {
  test('returns BytesData when imageData is present', () async {
    final r = SignatureResolver();
    final bytes = Uint8List.fromList([1, 2, 3]);
    final data = await r.resolve(_signature(imageData: bytes));
    expect(data, isA<BytesData>());
    expect((data as BytesData).bytes, bytes);
  });

  test(
    'returns Unavailable.notFound when neither blob nor path is set',
    () async {
      final r = SignatureResolver();
      final data = await r.resolve(_signature());
      expect(data, isA<UnavailableData>());
      expect((data as UnavailableData).kind, UnavailableKind.notFound);
    },
  );

  test('canResolveOnThisDevice always true', () {
    final r = SignatureResolver();
    expect(r.canResolveOnThisDevice(_signature()), isTrue);
  });

  test('extractMetadata returns null', () async {
    final r = SignatureResolver();
    expect(await r.extractMetadata(_signature()), isNull);
  });

  test('verify returns notFound when nothing to read', () async {
    final r = SignatureResolver();
    final v = await r.verify(_signature());
    expect(v.toString(), contains('notFound'));
  });
}
