import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';

/// A rejected request has to say why. S3 answers with
/// `<Error><Code>..</Code><Message>..</Message></Error>`, and the catch-all
/// used to throw the bare status, discarding the Code it had already parsed
/// to recognise four specific failures. That is the gap #2018 fixed on the
/// Drive adapter.
void main() {
  S3ApiClient clientReturning(int status, String body) => S3ApiClient(
    S3Config(
      endpoint: 'http://nas.local:9000',
      bucket: 'dive-sync',
      accessKeyId: 'ak',
      secretAccessKey: 'sk',
    ),
    httpClient: MockClient((_) async => http.Response(body, status)),
    now: () => DateTime.utc(2026, 6, 9, 12),
    retryDelay: Duration.zero,
  );

  test('a rejected request carries the S3 Code and Message', () async {
    final client = clientReturning(
      400,
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<Error><Code>InvalidRequest</Code>'
      '<Message>Multipart uploads are not supported here</Message>'
      '</Error>',
    );

    await expectLater(
      () => client.putObject('k', Uint8List.fromList([1])),
      throwsA(
        isA<CloudStorageException>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('InvalidRequest'),
            contains('Multipart uploads are not supported here'),
          ),
        ),
      ),
    );
  });

  test('a very long Message is bounded', () async {
    // The detail lands in the media queue's errorMessage column and in a
    // list tile, by way of MediaStoreException's primary message, which is
    // not the half that toString bounds. An S3-compatible server is free to
    // answer with a Message of any length.
    final client = clientReturning(
      500,
      '<Error><Code>InternalError</Code>'
      '<Message>${'detail ' * 500}</Message></Error>',
    );

    await expectLater(
      () => client.putObject('k', Uint8List.fromList([1])),
      throwsA(
        isA<CloudStorageException>().having(
          (e) => e.message.length,
          'message length',
          lessThan(400),
        ),
      ),
    );
  });

  test('a 403 carries the code the provider rejected it with', () async {
    // The advice stays -- it is the actionable part -- but a provider that
    // says SignatureDoesNotMatch is naming a different fault than one that
    // says AccessDenied, and the person reading the failure cannot tell the
    // two apart without it.
    final client = clientReturning(
      403,
      '<Error><Code>SignatureDoesNotMatch</Code>'
      '<Message>The request signature we calculated does not match</Message>'
      '</Error>',
    );

    await expectLater(
      () => client.putObject('k', Uint8List.fromList([1])),
      throwsA(
        isA<CloudStorageException>().having(
          (e) => e.message,
          'message',
          allOf(contains('Access denied'), contains('SignatureDoesNotMatch')),
        ),
      ),
    );
  });

  test('an unparseable body degrades to the bare status', () async {
    final client = clientReturning(400, '<html>bad request</html>');

    await expectLater(
      () => client.putObject('k', Uint8List.fromList([1])),
      throwsA(
        isA<CloudStorageException>().having(
          (e) => e.message,
          'message',
          allOf(contains('400'), isNot(contains('html'))),
        ),
      ),
    );
  });
}
