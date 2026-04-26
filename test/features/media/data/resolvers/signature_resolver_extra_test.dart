import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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
  test('sourceType getter returns signature', () {
    final r = SignatureResolver();
    expect(r.sourceType, MediaSourceType.signature);
  });

  test(
    'resolve returns FileData when filePath points at an existing file',
    () async {
      final tmp = Directory.systemTemp.createTempSync('sig_resolver_test');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final file = File(p.join(tmp.path, 'sig.png'));
      await file.writeAsBytes([1, 2, 3]);

      final r = SignatureResolver();
      final data = await r.resolve(_signature(filePath: file.path));
      expect(data, isA<FileData>());
      expect((data as FileData).file.path, file.path);
    },
  );

  test(
    'resolve returns Unavailable.notFound when filePath is missing',
    () async {
      final r = SignatureResolver();
      final data = await r.resolve(
        _signature(filePath: '/no/such/path/abc.png'),
      );
      expect(data, isA<UnavailableData>());
      expect((data as UnavailableData).kind, UnavailableKind.notFound);
    },
  );

  test('resolveThumbnail delegates to resolve', () async {
    final r = SignatureResolver();
    final bytes = Uint8List.fromList([7, 8, 9]);
    final data = await r.resolveThumbnail(
      _signature(imageData: bytes),
      target: const Size(64, 64),
    );
    expect(data, isA<BytesData>());
    expect((data as BytesData).bytes, bytes);
  });

  test('verify returns available when imageData is set', () async {
    final r = SignatureResolver();
    final bytes = Uint8List.fromList([1]);
    final v = await r.verify(_signature(imageData: bytes));
    expect(v.toString(), contains('available'));
  });
}
