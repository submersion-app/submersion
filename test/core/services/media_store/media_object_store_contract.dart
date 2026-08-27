import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';

/// Behavioral contract every MediaObjectStore implementation must satisfy.
void runMediaObjectStoreContract(
  String name,
  Future<MediaObjectStore> Function() build,
) {
  group('$name contract', () {
    late MediaObjectStore store;
    late Directory tmp;

    setUp(() async {
      store = await build();
      tmp = await Directory.systemTemp.createTemp('mos_contract');
    });

    tearDown(() => tmp.delete(recursive: true));

    File tempFile(String name, List<int> bytes) {
      final f = File('${tmp.path}/$name');
      f.writeAsBytesSync(bytes);
      return f;
    }

    test('head of a missing key is null', () async {
      expect(await store.head('smv1/objects/aa/missing.jpg'), isNull);
    });

    test('putFile then head then getFile round-trips bytes', () async {
      final bytes = List<int>.generate(1024, (i) => i % 251);
      final src = tempFile('src.jpg', bytes);
      await store.putFile(
        'smv1/objects/aa/k1.jpg',
        src,
        contentType: 'image/jpeg',
      );

      final info = await store.head('smv1/objects/aa/k1.jpg');
      expect(info, isNotNull);
      expect(info!.sizeBytes, bytes.length);

      final dest = File('${tmp.path}/dest.jpg');
      await store.getFile('smv1/objects/aa/k1.jpg', dest);
      expect(await dest.readAsBytes(), bytes);
    });

    test('getFile of a missing key throws notFound', () async {
      final dest = File('${tmp.path}/nope.bin');
      await expectLater(
        store.getFile('smv1/objects/aa/nope.bin', dest),
        throwsA(
          isA<MediaStoreException>().having(
            (e) => e.kind,
            'kind',
            MediaStoreErrorKind.notFound,
          ),
        ),
      );
    });

    test('delete is idempotent', () async {
      final src = tempFile('d.bin', [1, 2, 3]);
      await store.putFile(
        'smv1/objects/aa/d.bin',
        src,
        contentType: 'application/octet-stream',
      );
      await store.delete('smv1/objects/aa/d.bin');
      await store.delete('smv1/objects/aa/d.bin');
      expect(await store.head('smv1/objects/aa/d.bin'), isNull);
    });

    test('list filters by prefix', () async {
      final src = tempFile('l.bin', [9]);
      await store.putFile(
        'smv1/objects/aa/one.bin',
        src,
        contentType: 'application/octet-stream',
      );
      await store.putFile(
        'smv1/thumbs/aa/one.jpg',
        src,
        contentType: 'image/jpeg',
      );

      final keys = await store.list('smv1/objects/').map((o) => o.key).toList();
      expect(keys, ['smv1/objects/aa/one.bin']);
    });

    test('putFile and getFile report progress reaching the full '
        'size', () async {
      final bytes = List<int>.generate(4096, (i) => i % 251);
      final src = tempFile('p.bin', bytes);
      final putProgress = <int>[];
      await store.putFile(
        'smv1/objects/aa/p.bin',
        src,
        contentType: 'application/octet-stream',
        onProgress: (sent, total) => putProgress.add(sent),
      );
      expect(putProgress, isNotEmpty);
      expect(putProgress.last, bytes.length);

      final getProgress = <int>[];
      final dest = File('${tmp.path}/p.out');
      await store.getFile(
        'smv1/objects/aa/p.bin',
        dest,
        onProgress: (received, total) => getProgress.add(received),
      );
      expect(getProgress, isNotEmpty);
      expect(getProgress.last, bytes.length);
      expect(await dest.readAsBytes(), bytes);
    });
  });
}
