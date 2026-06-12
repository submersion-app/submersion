import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_region.dart';

void main() {
  group('deriveRegion', () {
    test('blank endpoint (AWS proper) defaults to us-east-1', () {
      expect(deriveRegion(''), 'us-east-1');
      expect(deriveRegion('   '), 'us-east-1');
    });

    test('AWS regional endpoint', () {
      expect(deriveRegion('https://s3.eu-west-1.amazonaws.com'), 'eu-west-1');
    });

    test('AWS global endpoint is us-east-1', () {
      expect(deriveRegion('https://s3.amazonaws.com'), 'us-east-1');
    });

    test('AWS dualstack endpoint', () {
      expect(
        deriveRegion('https://s3.dualstack.ap-southeast-2.amazonaws.com'),
        'ap-southeast-2',
      );
    });

    test('AWS legacy dash-form endpoint', () {
      expect(deriveRegion('https://s3-us-west-2.amazonaws.com'), 'us-west-2');
    });

    test('Cloudflare R2 is always auto', () {
      expect(deriveRegion('https://a1b2c3d4.r2.cloudflarestorage.com'), 'auto');
    });

    test('Backblaze B2', () {
      expect(
        deriveRegion('https://s3.us-west-004.backblazeb2.com'),
        'us-west-004',
      );
    });

    test('DigitalOcean Spaces', () {
      expect(deriveRegion('https://nyc3.digitaloceanspaces.com'), 'nyc3');
    });

    test('Wasabi', () {
      expect(
        deriveRegion('https://s3.eu-central-1.wasabisys.com'),
        'eu-central-1',
      );
    });

    test('Scaleway', () {
      expect(deriveRegion('https://s3.fr-par.scw.cloud'), 'fr-par');
    });

    test('unknown hosts (MinIO, NAS) default to us-east-1', () {
      expect(deriveRegion('http://nas.local:9000'), 'us-east-1');
      expect(deriveRegion('https://minio.example.com'), 'us-east-1');
    });

    test('matching is case-insensitive', () {
      expect(deriveRegion('HTTPS://S3.EU-WEST-1.AMAZONAWS.COM'), 'eu-west-1');
    });

    test('unparseable input defaults to us-east-1', () {
      expect(deriveRegion('not a url ::'), 'us-east-1');
    });
  });
}
