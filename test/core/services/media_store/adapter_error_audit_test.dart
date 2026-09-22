import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_api_client.dart';
import 'package:submersion/core/services/media_store/dropbox_media_object_store.dart';
import 'package:submersion/core/services/media_store/icloud_media_object_store.dart';
import 'package:submersion/core/services/media_store/icloud_media_platform.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';

/// The adapter audit spec 5.3 asks for, recorded as tests.
///
/// Drive was fixed separately (#2018, PR #2019) and S3 is fixed in this
/// slice. These two needed no change of their own: Dropbox already pulls
/// Google's equivalent, `error_summary`, out of the body, and iCloud is
/// filesystem-backed so there is no server body to lose. Both only needed
/// `MediaStoreException.toString()` to stop hiding the cause. These tests
/// fail with the reason if either property goes away.
void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('adapter_audit_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test("a Dropbox failure carries Dropbox's error_summary", () async {
    final store = DropboxMediaObjectStore(
      client: DropboxApiClient(
        getAccessToken: () async => 'token',
        onAccessTokenRejected: () {},
        httpClient: MockClient(
          (_) async => http.Response(
            '{"error_summary": "path/conflict/file/..", '
            '"error": {".tag": "path"}}',
            409,
          ),
        ),
      ),
    );
    final src = File('${tmp.path}/a.bin')..writeAsBytesSync([1]);

    await expectLater(
      store.putFile('smv1/objects/aa/a.bin', src, contentType: 'x'),
      throwsA(
        isA<MediaStoreException>().having(
          (e) => e.toString(),
          'toString',
          contains('path/conflict/file/..'),
        ),
      ),
    );
  });

  test('a very long Dropbox error_summary is bounded', () async {
    // error_summary is provider-controlled and, unlike the raw-body
    // fallback, was not capped. It reaches MediaStoreException.message
    // through displayMessage, which is the half nothing else bounds, and
    // from there the queue's errorMessage column and a list tile.
    final store = DropboxMediaObjectStore(
      client: DropboxApiClient(
        getAccessToken: () async => 'token',
        onAccessTokenRejected: () {},
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error_summary': 'path/conflict/${'x' * 5000}',
              'error': {'.tag': 'path'},
            }),
            409,
          ),
        ),
      ),
    );
    final src = File('${tmp.path}/long.bin')..writeAsBytesSync([1]);

    await expectLater(
      store.putFile('smv1/objects/aa/long.bin', src, contentType: 'x'),
      throwsA(
        isA<MediaStoreException>()
            .having((e) => e.message.length, 'message length', lessThan(400))
            .having(
              (e) => e.toString().length,
              'toString length',
              lessThan(600),
            ),
      ),
    );
  });

  test('an iCloud read failure carries the filesystem error', () async {
    final store = ICloudMediaObjectStore(
      platform: DirectoryICloudMediaPlatform(tmp),
    );
    // A source that is not there at all: the adapter's own read fails, and
    // the FileSystemException is the only explanation there is.
    final missing = File('${tmp.path}/gone.bin');

    await expectLater(
      store.putFile('smv1/objects/aa/gone.bin', missing, contentType: 'x'),
      throwsA(
        isA<MediaStoreException>().having(
          (e) => e.toString(),
          'toString',
          allOf(
            contains('cannot read source'),
            contains('gone.bin'),
            // The message carries the key, not the source file's own path,
            // so only the cause can put that path in the string. Asserting
            // on the key alone would pass with the cause dropped. The type
            // name is not asserted: a missing file raises the
            // PathNotFoundException subclass, and which subclass Dart picks
            // is not what this test is about.
            contains(missing.path),
          ),
        ),
      ),
    );
  });
}
