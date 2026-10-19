import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/accounts/account_display_name.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';

/// Storage accounts read by a short name (issue #3522): a nickname the diver
/// chose, else the bucket and a recognised provider instead of an endpoint
/// host carrying account ids.
void main() {
  group('shortStorageLabel', () {
    const r2Host = '149b84f66d5479265f3e4d4ad4740926.r2.cloudflarestorage.com';

    test('names Cloudflare R2 instead of the account-id host', () {
      expect(
        shortStorageLabel('submersion-sync @ $r2Host'),
        'submersion-sync @ Cloudflare R2',
      );
    });

    test('names the other well-known S3 services', () {
      expect(
        shortStorageLabel('dives @ s3.eu-west-1.amazonaws.com'),
        'dives @ Amazon S3',
      );
      expect(
        shortStorageLabel('dives @ s3.us-west-004.backblazeb2.com'),
        'dives @ Backblaze B2',
      );
      expect(
        shortStorageLabel('dives @ s3.eu-central-1.wasabisys.com'),
        'dives @ Wasabi',
      );
      expect(
        shortStorageLabel('dives @ ams3.digitaloceanspaces.com'),
        'dives @ DigitalOcean Spaces',
      );
      expect(
        shortStorageLabel('dives @ storage.googleapis.com'),
        'dives @ Google Cloud Storage',
      );
      expect(
        shortStorageLabel('dives @ us-east-1.linodeobjects.com'),
        'dives @ Akamai (Linode) Object Storage',
      );
      expect(
        shortStorageLabel('dives @ s3.fr-par.scw.cloud'),
        'dives @ Scaleway',
      );
    });

    test('keeps a trailing folder note', () {
      expect(
        shortStorageLabel('club @ $r2Host (submersion-sites/reef-team)'),
        'club @ Cloudflare R2 (submersion-sites/reef-team)',
      );
    });

    test('matches the host case-insensitively', () {
      expect(
        shortStorageLabel('dives @ ABC.R2.CloudflareStorage.com'),
        'dives @ Cloudflare R2',
      );
    });

    test('leaves an unrecognised host alone', () {
      expect(shortStorageLabel('dives @ minio.local'), 'dives @ minio.local');
      expect(
        shortStorageLabel('eric @ cloud.example.com'),
        'eric @ cloud.example.com',
      );
    });

    test('does not mistake a look-alike host for a provider', () {
      expect(
        shortStorageLabel('dives @ notr2.cloudflarestorage.com.evil.net'),
        'dives @ notr2.cloudflarestorage.com.evil.net',
      );
    });

    test('leaves a label without a host alone', () {
      expect(shortStorageLabel('Dropbox'), 'Dropbox');
      expect(shortStorageLabel(''), '');
    });
  });

  group('ConnectedAccount.displayName', () {
    ConnectedAccount account({String? nickname}) => ConnectedAccount(
      id: 'a1',
      kind: AccountKind.s3,
      label: 'dives @ s3.eu-west-1.amazonaws.com',
      nickname: nickname,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    test('is the nickname when the diver chose one', () {
      expect(account(nickname: 'Club bucket').displayName, 'Club bucket');
    });

    test('is the short label without a nickname', () {
      expect(account().displayName, 'dives @ Amazon S3');
    });

    test('ignores a blank nickname', () {
      expect(account(nickname: '   ').displayName, 'dives @ Amazon S3');
    });

    test('copyWith can set and clear the nickname', () {
      final named = account().copyWith(nickname: 'Club');
      expect(named.nickname, 'Club');
      expect(named.copyWith(clearNickname: true).nickname, isNull);
      expect(named.copyWith(label: 'x').nickname, 'Club');
    });
  });
}
