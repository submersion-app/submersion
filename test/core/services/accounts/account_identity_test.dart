import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';

void main() {
  S3Config config({
    String endpoint = 'https://minio.local',
    String region = 'us-east-1',
    String bucket = 'dive-media',
    String prefix = 'submersion-sync/',
  }) => S3Config(
    endpoint: endpoint,
    region: region,
    bucket: bucket,
    prefix: prefix,
    accessKeyId: 'AK',
    secretAccessKey: 'SK',
  );

  String idFor(S3Config c) =>
      accountIdFor(kind: AccountKind.s3, naturalKey: s3NaturalKey(c));

  test('same endpoint yields the same id', () {
    expect(idFor(config()), idFor(config()));
  });

  test('id is stable across credential rotation', () {
    final rotated = S3Config(
      endpoint: 'https://minio.local',
      bucket: 'dive-media',
      prefix: 'submersion-sync/',
      accessKeyId: 'ROTATED',
      secretAccessKey: 'ROTATED',
    );
    expect(idFor(config()), idFor(rotated));
  });

  test('a different prefix is a different account', () {
    expect(idFor(config()), isNot(idFor(config(prefix: 'media/'))));
  });

  test('a different bucket is a different account', () {
    expect(idFor(config()), isNot(idFor(config(bucket: 'other'))));
  });

  test('AWS-proper and an explicit AWS endpoint agree', () {
    final implicit = config(endpoint: '', region: 'eu-west-1');
    final explicit = config(
      endpoint: 'https://s3.eu-west-1.amazonaws.com',
      region: 'eu-west-1',
    );
    expect(idFor(implicit), idFor(explicit));
  });

  test('a trailing slash on the endpoint does not change the id', () {
    expect(idFor(config()), idFor(config(endpoint: 'https://minio.local/')));
  });

  test('managed kinds are single-instance per kind', () {
    for (final kind in [
      AccountKind.icloud,
      AccountKind.dropbox,
      AccountKind.googledrive,
    ]) {
      final key = naturalKeyForKind(kind);
      expect(key, isNotNull, reason: '$kind must have a natural key');
      expect(
        accountIdFor(kind: kind, naturalKey: key!),
        accountIdFor(kind: kind, naturalKey: key),
      );
    }
  });

  test('different kinds never collide', () {
    final ids = {
      for (final kind in [
        AccountKind.icloud,
        AccountKind.dropbox,
        AccountKind.googledrive,
      ])
        accountIdFor(kind: kind, naturalKey: naturalKeyForKind(kind)!),
    };
    expect(ids.length, 3);
  });

  test('s3 and lightroom have no kind-only natural key', () {
    expect(naturalKeyForKind(AccountKind.s3), isNull);
    expect(naturalKeyForKind(AccountKind.adobeLightroom), isNull);
  });

  test('the namespace constant is frozen', () {
    expect(kConnectedAccountNamespace, 'c622faae-974f-4310-a5e7-36c2fb773684');
  });
}
