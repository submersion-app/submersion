import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';

void main() {
  S3Config minio() => S3Config(
    endpoint: 'http://192.168.1.10:9000',
    bucket: 'dive-sync',
    accessKeyId: 'minio-user',
    secretAccessKey: 'minio-secret',
  );

  group('S3Config normalization', () {
    test('defaults: region us-east-1, prefix submersion-sync/', () {
      final config = minio();
      expect(config.region, 'us-east-1');
      expect(config.prefix, 'submersion-sync/');
    });

    test('pathStyle defaults to true for a custom endpoint', () {
      expect(minio().pathStyle, isTrue);
    });

    test('pathStyle defaults to false for AWS (empty endpoint)', () {
      final config = S3Config(
        endpoint: '',
        bucket: 'b',
        accessKeyId: 'a',
        secretAccessKey: 's',
      );
      expect(config.pathStyle, isFalse);
    });

    test('explicit pathStyle overrides the default', () {
      final config = S3Config(
        endpoint: '',
        bucket: 'b',
        accessKeyId: 'a',
        secretAccessKey: 's',
        pathStyle: true,
      );
      expect(config.pathStyle, isTrue);
    });

    test('prefix is normalized: leading slash stripped, trailing added', () {
      final config = minio().copyWith(prefix: '/my/dives');
      expect(config.prefix, 'my/dives/');
    });

    test('empty prefix stays empty (bucket root)', () {
      final config = minio().copyWith(prefix: '');
      expect(config.prefix, '');
    });

    test('endpoint whitespace and trailing slash are trimmed', () {
      final config = minio().copyWith(endpoint: ' http://nas.local:9000/ ');
      expect(config.endpoint, 'http://nas.local:9000');
    });

    test('secretAccessKey is trimmed', () {
      final config = minio().copyWith(secretAccessKey: ' sk\n');
      expect(config.secretAccessKey, 'sk');
    });

    test('blank region falls back to us-east-1', () {
      expect(minio().copyWith(region: '   ').region, 'us-east-1');
    });
  });

  group('S3Config derived values', () {
    test('isAws true only when endpoint is empty', () {
      expect(minio().isAws, isFalse);
      expect(minio().copyWith(endpoint: '').isAws, isTrue);
    });

    test('displayHost is the endpoint host for custom endpoints', () {
      expect(minio().displayHost, '192.168.1.10');
    });

    test('displayHost is the regional AWS host for AWS', () {
      final config = minio().copyWith(endpoint: '', region: 'eu-west-1');
      expect(config.displayHost, 's3.eu-west-1.amazonaws.com');
    });

    test('isInsecureEndpoint true only for http://', () {
      expect(minio().isInsecureEndpoint, isTrue);
      expect(
        minio()
            .copyWith(endpoint: 'https://minio.example.com')
            .isInsecureEndpoint,
        isFalse,
      );
      expect(minio().copyWith(endpoint: '').isInsecureEndpoint, isFalse);
    });

    test(
      'displayHost falls back to the raw string for unparseable endpoints',
      () {
        final config = minio().copyWith(endpoint: '192.168.1.10:9000');
        expect(config.displayHost, '192.168.1.10:9000');
      },
    );

    test('copyWith keeps an explicitly set pathStyle sticky', () {
      final aws = S3Config(
        endpoint: '',
        bucket: 'b',
        accessKeyId: 'a',
        secretAccessKey: 's',
        pathStyle: true,
      );
      expect(aws.copyWith(endpoint: 'http://nas.local:9000').pathStyle, isTrue);
    });
  });

  group('S3Config.effectivePathStyle (dotted-bucket TLS guard, #335)', () {
    S3Config aws({required String bucket, bool? pathStyle}) => S3Config(
      endpoint: '',
      region: 'ap-southeast-2',
      bucket: bucket,
      accessKeyId: 'a',
      secretAccessKey: 's',
      pathStyle: pathStyle,
    );

    test('plain AWS bucket without a dot mirrors the stored flag', () {
      final config = aws(bucket: 'dive-sync');
      expect(config.pathStyle, isFalse);
      expect(config.effectivePathStyle, isFalse);
    });

    test('dotted AWS bucket forces path-style despite a false flag', () {
      final config = aws(bucket: 'my.dive.bucket');
      expect(config.pathStyle, isFalse);
      expect(config.effectivePathStyle, isTrue);
    });

    test('dotted bucket on an HTTPS custom endpoint forces path-style', () {
      final config = S3Config(
        endpoint: 'https://minio.example.com',
        bucket: 'my.bucket',
        accessKeyId: 'a',
        secretAccessKey: 's',
        pathStyle: false,
      );
      expect(config.effectivePathStyle, isTrue);
    });

    test('dotted bucket on a plain-HTTP endpoint defers to the flag', () {
      // No TLS handshake to break, so the stored choice is honored as-is.
      final config = S3Config(
        endpoint: 'http://nas.local:9000',
        bucket: 'my.bucket',
        accessKeyId: 'a',
        secretAccessKey: 's',
        pathStyle: false,
      );
      expect(config.effectivePathStyle, isFalse);
    });

    test('explicit path-style stays true regardless of the bucket', () {
      expect(aws(bucket: 'plain', pathStyle: true).effectivePathStyle, isTrue);
    });
  });

  group('S3Config.validate', () {
    test('valid config returns null', () {
      expect(minio().validate(), isNull);
    });

    test('missing bucket / accessKeyId / secretAccessKey are rejected', () {
      expect(minio().copyWith(bucket: '').validate(), isNotNull);
      expect(minio().copyWith(accessKeyId: '').validate(), isNotNull);
      expect(minio().copyWith(secretAccessKey: '').validate(), isNotNull);
    });

    test('non-http(s) endpoint is rejected, empty endpoint accepted', () {
      expect(minio().copyWith(endpoint: 'ftp://nas').validate(), isNotNull);
      expect(minio().copyWith(endpoint: 'not a url').validate(), isNotNull);
      expect(minio().copyWith(endpoint: '').validate(), isNull);
    });

    test('schemeless host:port and sub-path endpoints are rejected', () {
      expect(
        minio().copyWith(endpoint: '192.168.1.10:9000').validate(),
        isNotNull,
      );
      expect(
        minio().copyWith(endpoint: 'https://nas.example.com/s3-api').validate(),
        isNotNull,
      );
    });
  });

  group('S3Config JSON round-trip', () {
    test('toJson/fromJson preserves every field', () {
      final config = S3Config(
        endpoint: 'https://s3.us-west-004.backblazeb2.com',
        region: 'us-west-004',
        bucket: 'dive-logs',
        prefix: 'devices/',
        pathStyle: false,
        accessKeyId: 'keyid',
        secretAccessKey: 'sekrit',
      );
      final restored = S3Config.fromJson(config.toJson());
      expect(restored.endpoint, config.endpoint);
      expect(restored.region, config.region);
      expect(restored.bucket, config.bucket);
      expect(restored.prefix, config.prefix);
      expect(restored.pathStyle, config.pathStyle);
      expect(restored.accessKeyId, config.accessKeyId);
      expect(restored.secretAccessKey, config.secretAccessKey);
    });
  });

  test('toString does not leak the secret', () {
    expect(minio().toString(), isNot(contains('minio-secret')));
  });
}
