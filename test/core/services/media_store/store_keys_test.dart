import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';

void main() {
  test('objectKey fans out on the first two hash chars', () {
    final hash = 'ab${'0' * 62}';
    expect(
      StoreKeys.objectKey(hash, extension: 'jpg'),
      'smv1/objects/ab/$hash.jpg',
    );
    expect(StoreKeys.thumbKey(hash), 'smv1/thumbs/ab/$hash.jpg');
    expect(StoreKeys.markerKey, 'smv1/store.json');
  });

  test('renditionKey fans out and uses the given ext', () {
    expect(
      StoreKeys.renditionKey('abcdef0123', ext: 'jpg'),
      'smv1/renditions/ab/abcdef0123.jpg',
    );
    expect(
      StoreKeys.renditionKey('abcdef0123', ext: 'mp4'),
      'smv1/renditions/ab/abcdef0123.mp4',
    );
  });

  test('extensionFor sanitizes and falls back to bin', () {
    expect(StoreKeys.extensionFor('IMG_1234.JPG'), 'jpg');
    expect(StoreKeys.extensionFor('clip.MOV'), 'mov');
    expect(StoreKeys.extensionFor('archive.tar.gz'), 'gz');
    expect(StoreKeys.extensionFor('noext'), 'bin');
    expect(StoreKeys.extensionFor(null), 'bin');
    expect(StoreKeys.extensionFor('weird.j%p*g'), 'bin');
    expect(StoreKeys.extensionFor('x.verylongextension'), 'bin');
    expect(StoreKeys.extensionFor('trailing.'), 'bin');
  });

  test('contentTypeFor maps common types', () {
    expect(StoreKeys.contentTypeFor('jpg'), 'image/jpeg');
    expect(StoreKeys.contentTypeFor('jpeg'), 'image/jpeg');
    expect(StoreKeys.contentTypeFor('png'), 'image/png');
    expect(StoreKeys.contentTypeFor('heic'), 'image/heic');
    expect(StoreKeys.contentTypeFor('mp4'), 'video/mp4');
    expect(StoreKeys.contentTypeFor('mov'), 'video/quicktime');
    expect(StoreKeys.contentTypeFor('bin'), 'application/octet-stream');
  });

  test('sha256OfFile streams and matches a known vector', () async {
    // Vector computed with:
    //   python3 -c "import hashlib; print(hashlib.sha256(b'submersion').hexdigest())"
    final dir = await Directory.systemTemp.createTemp('store_keys_test');
    addTearDown(() => dir.delete(recursive: true));
    final f = File('${dir.path}/v.bin');
    await f.writeAsBytes('submersion'.codeUnits);
    final digest = await sha256OfFile(f);
    expect(digest.sizeBytes, 10);
    expect(
      digest.hash,
      'f2ab25e4b7f97b505bedc4108f9090f7a2ce6b3ac50f08d34f987a6b6eb977c5',
    );
  });
}
