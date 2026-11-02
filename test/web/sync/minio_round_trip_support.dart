import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';

/// What the browser round trip (issue #4121) and the tool that seeds its
/// library share: the store named by four `--dart-define`s, the device the
/// seed is published under and the dives it holds.
///
/// Both skip with [minioSkipReason] when `MINIO_ENDPOINT` is unset, so a
/// local run without a store says why; the CI job asserts no skips.
const String minioSkipReason = 'MINIO_ENDPOINT not set';

/// The device id the seeded library is published under.
const String kSeedDeviceId = 'seed-device';

/// The five dives the seed publishes, in dive-number order.
const List<String> kSeededDiveIds = [
  'seed-dive-1',
  'seed-dive-2',
  'seed-dive-3',
  'seed-dive-4',
  'seed-dive-5',
];

const String _endpoint = String.fromEnvironment('MINIO_ENDPOINT');
const String _noCorsEndpoint = String.fromEnvironment('MINIO_NOCORS_ENDPOINT');
const String _bucket = String.fromEnvironment('MINIO_BUCKET');
const String _accessKey = String.fromEnvironment('MINIO_ACCESS_KEY');
const String _secretKey = String.fromEnvironment('MINIO_SECRET_KEY');

/// The store the defines name, or null when no endpoint was given.
S3Config? minioConfigFromEnvironment() => _endpoint.isEmpty
    ? null
    : S3Config(
        endpoint: _endpoint,
        bucket: _bucket,
        accessKeyId: _accessKey,
        secretAccessKey: _secretKey,
      );

/// The skip reason of the test that needs a second store refusing this
/// site's origin.
const String minioNoCorsSkipReason = 'MINIO_NOCORS_ENDPOINT not set';

/// The same store served a second time with a CORS rule that names some
/// other site, or null when `MINIO_NOCORS_ENDPOINT` was not given.
S3Config? minioNoCorsConfigFromEnvironment() => _noCorsEndpoint.isEmpty
    ? null
    : S3Config(
        endpoint: _noCorsEndpoint,
        bucket: _bucket,
        accessKeyId: _accessKey,
        secretAccessKey: _secretKey,
      );

/// A credentials store that answers one fixed configuration and never
/// touches secure storage.
class FixedS3CredentialsStore extends S3CredentialsStore {
  FixedS3CredentialsStore(this.config);

  final S3Config config;

  @override
  Future<S3Config?> load() async => config;

  @override
  Future<void> save(S3Config config) async {}

  @override
  Future<void> clear() async {}
}
