@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/web/cors_diagnoser.dart';
import 'package:submersion/core/services/cloud_storage/s3_storage_provider.dart';

import 'minio_round_trip_support.dart';

/// The failure shape the diagnoser's VM tests assume, proven in a real
/// browser (issue #4121): a store whose CORS rule names another site makes
/// the browser report an opaque network failure, which the diagnoser reads
/// as blocked by CORS; the same store with a rule admitting this site
/// answers the connection test.
///
/// Needs MINIO_ENDPOINT (a store admitting every origin) and
/// MINIO_NOCORS_ENDPOINT (the same store admitting only another site) as
/// `--dart-define`s, with the bucket and the keys; it skips, saying so,
/// without them.
void main() {
  final allowed = minioConfigFromEnvironment();
  final refused = minioNoCorsConfigFromEnvironment();
  final skip = allowed == null
      ? minioSkipReason
      : refused == null
      ? minioNoCorsSkipReason
      : null;

  test(
    'a store that refuses this site is diagnosed as blocked by CORS',
    () async {
      final provider = S3StorageProvider(
        store: FixedS3CredentialsStore(refused!),
      );
      Object? failure;
      try {
        await provider.testConnection(refused);
      } catch (error) {
        failure = error;
      }
      expect(failure, isNotNull, reason: 'the browser must refuse the request');
      expect(isOpaqueBrowserFailure(failure!), isTrue, reason: '$failure');
      final diagnosis = diagnose(
        error: failure,
        endpoint: Uri.parse(refused.endpoint),
        origin: Uri.base.origin,
        isWebDav: false,
        failedOnWrite: provider.lastProbeFailedOnWrite,
      );
      expect(diagnosis.verdict, CorsVerdict.blockedByCors);
      expect(diagnosis.ruleTemplate, contains(Uri.base.origin));
    },
    skip: skip,
  );

  test('a store that admits this site passes the connection test', () async {
    final provider = S3StorageProvider(
      store: FixedS3CredentialsStore(allowed!),
    );
    await provider.testConnection(allowed);
  }, skip: skip);
}
