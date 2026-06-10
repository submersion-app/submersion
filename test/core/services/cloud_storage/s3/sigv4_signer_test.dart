import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/s3/sigv4_signer.dart';

// Test vectors from the AWS documentation:
// https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-examples.html
// https://docs.aws.amazon.com/general/latest/gr/signature-v4-examples.html
const awsAccessKey = 'AKIAIOSFODNN7EXAMPLE';
const awsSecretKey = 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY';
const emptyPayloadHash =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

void main() {
  group('hashing primitives', () {
    test('hexSha256 of empty bytes is the well-known empty hash', () {
      expect(SigV4Signer.hexSha256(const []), emptyPayloadHash);
    });

    test('deriveSigningKey matches the reference HMAC chain', () {
      // Inputs from AWS "Examples of how to derive a signing key": secret
      // above, 20120215, us-east-1, iam. Expected value computed with the
      // Python hmac reference implementation of the SigV4 chain.
      final key = SigV4Signer.deriveSigningKey(
        secretAccessKey: awsSecretKey,
        dateStamp: '20120215',
        region: 'us-east-1',
        service: 'iam',
      );
      expect(
        SigV4Signer.hexEncode(key),
        '004aa806e13dae88b9032d9261bcb04c67d023afadd221e6b0d206e1760e0b5e',
      );
    });
  });

  group('date formatting', () {
    final time = DateTime.utc(2013, 5, 24);
    test('amzDateFormat is yyyyMMddTHHmmssZ', () {
      expect(SigV4Signer.amzDateFormat(time), '20130524T000000Z');
    });
    test('dateStampFormat is yyyyMMdd', () {
      expect(SigV4Signer.dateStampFormat(time), '20130524');
    });
    test('non-UTC input is converted to UTC', () {
      final local = DateTime.utc(2013, 5, 24, 1, 2, 3).toLocal();
      expect(SigV4Signer.amzDateFormat(local), '20130524T010203Z');
    });
  });

  group('uriEncode', () {
    test('keeps unreserved characters', () {
      expect(SigV4Signer.uriEncode('AZaz09-._~'), 'AZaz09-._~');
    });
    test('encodes reserved characters with uppercase hex', () {
      expect(SigV4Signer.uriEncode('a b'), 'a%20b');
      expect(SigV4Signer.uriEncode('a=b'), 'a%3Db');
      expect(SigV4Signer.uriEncode('a/b'), 'a%2Fb');
    });
    test('encodeSlash false preserves path separators', () {
      expect(
        SigV4Signer.uriEncode('sync/file name.json', encodeSlash: false),
        'sync/file%20name.json',
      );
    });
    test(
      'encodes SigV4-divergent characters that Uri.encodeComponent skips',
      () {
        expect(SigV4Signer.uriEncode("!*'()"), '%21%2A%27%28%29');
      },
    );

    test('encodes multibyte UTF-8 one percent-escape per byte', () {
      expect(SigV4Signer.uriEncode('Mākena'), 'M%C4%81kena');
    });
  });

  group('canonicalQueryString', () {
    test('sorts parameters by key and encodes values', () {
      expect(
        SigV4Signer.canonicalQueryString({'prefix': 'J', 'max-keys': '2'}),
        'max-keys=2&prefix=J',
      );
    });
    test('empty map yields empty string', () {
      expect(SigV4Signer.canonicalQueryString(const {}), '');
    });
    test('continuation tokens with special characters are encoded', () {
      expect(
        SigV4Signer.canonicalQueryString({'continuation-token': '1/aGVs bG8='}),
        'continuation-token=1%2FaGVs%20bG8%3D',
      );
    });
  });

  group('payload hashing', () {
    test('hexSha256 of a body matches sha256 of its bytes', () {
      final body = utf8.encode('Welcome to Amazon S3.');
      expect(
        SigV4Signer.hexSha256(body),
        '44ce7dd67c959e0d3524ffac1771dfbba87d2b6b4b4e99e42034a8b803f8b072',
      );
    });
  });

  group('header normalization', () {
    test('collapses sequential whitespace inside header values', () {
      final canonical = SigV4Signer.canonicalRequest(
        method: 'GET',
        canonicalUri: '/',
        queryParams: const {},
        headers: {'host': 'h', 'x-test': 'a  b\t c'},
        payloadHash: emptyPayloadHash,
      );
      expect(canonical, contains('x-test:a b c\n'));
    });

    test('pre-encoded canonicalUri passes through verbatim', () {
      final canonical = SigV4Signer.canonicalRequest(
        method: 'GET',
        canonicalUri: '/dive-sync/my%20file.json',
        queryParams: const {},
        headers: {'host': 'h'},
        payloadHash: emptyPayloadHash,
      );
      expect(canonical.split('\n')[1], '/dive-sync/my%20file.json');
    });
  });

  // AWS worked example "GET object" from sig-v4-examples: GET /test.txt on
  // examplebucket with a Range header, signed at 20130524T000000Z.
  group('canonical request and signing (AWS GET object vector)', () {
    final requestTime = DateTime.utc(2013, 5, 24);
    final headers = {
      'host': 'examplebucket.s3.amazonaws.com',
      'range': 'bytes=0-9',
      'x-amz-content-sha256': emptyPayloadHash,
      'x-amz-date': '20130524T000000Z',
    };

    test('canonicalRequest matches the documented form', () {
      final canonical = SigV4Signer.canonicalRequest(
        method: 'GET',
        canonicalUri: '/test.txt',
        queryParams: const {},
        headers: headers,
        payloadHash: emptyPayloadHash,
      );
      expect(canonical, '''
GET
/test.txt

host:examplebucket.s3.amazonaws.com
range:bytes=0-9
x-amz-content-sha256:$emptyPayloadHash
x-amz-date:20130524T000000Z

host;range;x-amz-content-sha256;x-amz-date
$emptyPayloadHash''');
    });

    test('stringToSign embeds the canonical request hash', () {
      final canonical = SigV4Signer.canonicalRequest(
        method: 'GET',
        canonicalUri: '/test.txt',
        queryParams: const {},
        headers: headers,
        payloadHash: emptyPayloadHash,
      );
      final sts = SigV4Signer.stringToSign(
        amzDate: '20130524T000000Z',
        credentialScope: '20130524/us-east-1/s3/aws4_request',
        canonicalRequestStr: canonical,
      );
      expect(sts, '''
AWS4-HMAC-SHA256
20130524T000000Z
20130524/us-east-1/s3/aws4_request
7344ae5b7ee6c3e7e6b0fe0640412a37625d1fbfff95c48bbb2dc43964946972''');
    });

    test('sign produces the documented signature', () {
      final signed = SigV4Signer.sign(
        method: 'GET',
        host: 'examplebucket.s3.amazonaws.com',
        canonicalUri: '/test.txt',
        extraHeaders: const {'range': 'bytes=0-9'},
        payload: const [],
        accessKeyId: awsAccessKey,
        secretAccessKey: awsSecretKey,
        region: 'us-east-1',
        requestTime: requestTime,
      );
      expect(signed['x-amz-date'], '20130524T000000Z');
      expect(signed['x-amz-content-sha256'], emptyPayloadHash);
      expect(
        signed['authorization'],
        contains('Credential=$awsAccessKey/20130524/us-east-1/s3/aws4_request'),
      );
      expect(
        signed['authorization'],
        contains('SignedHeaders=host;range;x-amz-content-sha256;x-amz-date'),
      );
      expect(
        signed['authorization'],
        contains(
          'Signature=f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41',
        ),
      );
    });
  });

  // AWS worked example "Get bucket (list objects)": GET /?max-keys=2&prefix=J
  group('signing with query parameters (AWS list objects vector)', () {
    test('sign produces the documented signature', () {
      final signed = SigV4Signer.sign(
        method: 'GET',
        host: 'examplebucket.s3.amazonaws.com',
        canonicalUri: '/',
        queryParams: const {'max-keys': '2', 'prefix': 'J'},
        payload: const [],
        accessKeyId: awsAccessKey,
        secretAccessKey: awsSecretKey,
        region: 'us-east-1',
        requestTime: DateTime.utc(2013, 5, 24),
      );
      expect(
        signed['authorization'],
        contains(
          'Signature=34b48302e7b5fa45bde8084f4b7868a86f0a534bc59db6670ed5711ef69dc6f7',
        ),
      );
    });
  });
}
