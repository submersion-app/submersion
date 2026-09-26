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
///
/// The provider's words go in the cause, so they reach the person through
/// `displayMessage` and `toString` while `message` stays the curated advice.
/// That split matters: the media stores classify a failure by substring on
/// `message`, so provider text in it would change what gets retried.
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
          (e) => e.displayMessage,
          'displayMessage',
          allOf(
            contains('InvalidRequest'),
            contains('Multipart uploads are not supported here'),
          ),
        ),
      ),
    );
  });

  test('the provider text stays out of the classification input', () async {
    // The media stores classify by substring on message. A 500 whose
    // Message reads "Access denied by policy" is a server fault to retry,
    // not an auth failure to stop on, so message must not carry it.
    final client = clientReturning(
      500,
      '<Error><Code>InternalError</Code>'
      '<Message>Access denied by policy</Message></Error>',
    );

    await expectLater(
      () => client.putObject('k', Uint8List.fromList([1])),
      throwsA(
        isA<CloudStorageException>()
            .having(
              (e) => e.message,
              'message',
              isNot(contains('Access denied')),
            )
            .having(
              (e) => e.displayMessage,
              'displayMessage',
              contains('Access denied by policy'),
            ),
      ),
    );
  });

  test('a very long Message is bounded', () async {
    // The detail reaches the media queue's errorMessage column and a list
    // tile, and an S3-compatible server is free to answer with a Message of
    // any length, or a proxy with a whole HTML page.
    final client = clientReturning(
      500,
      '<Error><Code>InternalError</Code>'
      '<Message>${'detail ' * 500}</Message></Error>',
    );

    await expectLater(
      () => client.putObject('k', Uint8List.fromList([1])),
      throwsA(
        isA<CloudStorageException>().having(
          (e) => e.displayMessage.length,
          'displayMessage length',
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
          (e) => e.displayMessage,
          'displayMessage',
          allOf(contains('Access denied'), contains('SignatureDoesNotMatch')),
        ),
      ),
    );
  });

  test('a 403 carries the Message, not just the Code', () async {
    // AccessDenied covers a wrong key and a disabled user alike. Only the
    // Message tells them apart, and the advice cannot.
    final client = clientReturning(
      403,
      '<Error><Code>AccessDenied</Code>'
      '<Message>user is disabled</Message></Error>',
    );

    await expectLater(
      () => client.putObject('k', Uint8List.fromList([1])),
      throwsA(
        isA<CloudStorageException>().having(
          (e) => e.displayMessage,
          'displayMessage',
          allOf(contains('Access denied'), contains('user is disabled')),
        ),
      ),
    );
  });

  test('the region branch carries the expected region the body names', () {
    // AWS answers this code with a Message that names the region it wanted,
    // which is the one value the advice tells the person to go and find.
    final client = clientReturning(
      400,
      '<Error><Code>AuthorizationHeaderMalformed</Code>'
      "<Message>the region 'us-east-1' is wrong; expecting 'eu-west-2'"
      '</Message></Error>',
    );

    expect(
      () => client.putObject('k', Uint8List.fromList([1])),
      throwsA(
        isA<CloudStorageException>().having(
          (e) => e.displayMessage,
          'displayMessage',
          allOf(contains('signature region'), contains('eu-west-2')),
        ),
      ),
    );
  });

  test('the clock branch carries the skew the body reports', () {
    final client = clientReturning(
      403,
      '<Error><Code>RequestTimeTooSkewed</Code>'
      '<Message>request time 2026-06-09T09:00:00Z differs by 42 minutes'
      '</Message></Error>',
    );

    expect(
      () => client.getObject('k'),
      throwsA(
        isA<CloudStorageException>().having(
          (e) => e.displayMessage,
          'displayMessage',
          allOf(contains('clock'), contains('42 minutes')),
        ),
      ),
    );
  });

  test('a completion error inside a 200 body says what S3 said', () async {
    // S3 reports completion failures inside a 200. The client already looks
    // for the Code to notice it failed at all, then threw it away, which is
    // the same gap as the catch-all one status class over.
    final client = clientReturning(
      200,
      '<Error><Code>InvalidPart</Code>'
      '<Message>One or more of the specified parts could not be found'
      '</Message></Error>',
    );

    await expectLater(
      () => client.completeMultipartUpload(
        'k',
        uploadId: 'u',
        parts: const [S3PartInfo(partNumber: 1, etag: '"e"')],
      ),
      throwsA(
        isA<CloudStorageException>()
            .having((e) => e.message, 'message', isNot(contains('InvalidPart')))
            .having(
              (e) => e.displayMessage,
              'displayMessage',
              allOf(
                contains('rejected the upload completion'),
                contains('InvalidPart'),
                contains('could not be found'),
              ),
            ),
      ),
    );
  });

  test('an unparseable body degrades to the bare status', () async {
    final client = clientReturning(400, '<html>bad request</html>');

    await expectLater(
      () => client.putObject('k', Uint8List.fromList([1])),
      throwsA(
        isA<CloudStorageException>()
            .having(
              (e) => e.displayMessage,
              'displayMessage',
              allOf(contains('400'), isNot(contains('html'))),
            )
            .having((e) => e.cause, 'cause', isNull),
      ),
    );
  });
}
