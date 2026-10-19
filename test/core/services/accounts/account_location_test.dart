// Issue #3482 phase 2: a secret-free description of where an S3 or WebDAV
// account points, synced so a second device signs in by typing only the
// secret.

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_location.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';

S3Config _s3({
  String key = 'AKIA1',
  String secret = 'shh',
  String prefix = 'submersion-sync/',
  String endpoint = 'https://minio.home:9000',
}) => S3Config(
  endpoint: endpoint,
  region: 'eu-west-1',
  bucket: 'dives',
  prefix: prefix,
  pathStyle: true,
  accessKeyId: key,
  secretAccessKey: secret,
);

WebDavConfig _dav({String password = 'pw', String folder = 'Submersion'}) =>
    WebDavConfig(
      serverUrl: 'https://cloud.example.com/remote.php/dav/files/eric',
      username: 'eric',
      password: password,
      folder: folder,
    );

void main() {
  test('an S3 location never carries a secret', () {
    final json = S3AccountLocation.fromConfig(_s3()).toJsonString();
    expect(json, isNot(contains('AKIA1')));
    expect(json, isNot(contains('shh')));
  });

  test('a WebDAV location never carries the password', () {
    final json = WebDavAccountLocation.fromConfig(
      _dav(password: 'hunter2'),
    ).toJsonString();
    expect(json, isNot(contains('hunter2')));
  });

  test('an S3 location rebuilds a config that hashes to the same id', () {
    final cfg = _s3(prefix: 'submersion-sites/reef-team/');
    final loc =
        AccountLocation.tryParse(
              S3AccountLocation.fromConfig(cfg).toJsonString(),
            )!
            as S3AccountLocation;
    final rebuilt = loc.toConfig(accessKeyId: 'AKIA1', secretAccessKey: 'shh');
    expect(
      accountIdFor(kind: AccountKind.s3, naturalKey: s3NaturalKey(rebuilt)),
      accountIdFor(kind: AccountKind.s3, naturalKey: s3NaturalKey(cfg)),
    );
    expect(rebuilt.region, 'eu-west-1');
    expect(rebuilt.pathStyle, isTrue);
  });

  test('a WebDAV location rebuilds a config that hashes to the same id', () {
    final cfg = _dav(folder: 'submersion-sites/reef-team');
    final loc =
        AccountLocation.tryParse(
              WebDavAccountLocation.fromConfig(cfg).toJsonString(),
            )!
            as WebDavAccountLocation;
    final rebuilt = loc.toConfig(password: 'pw');
    expect(
      accountIdFor(
        kind: AccountKind.webdav,
        naturalKey: webdavNaturalKey(rebuilt),
      ),
      accountIdFor(kind: AccountKind.webdav, naturalKey: webdavNaturalKey(cfg)),
    );
    expect(rebuilt.username, 'eric');
  });

  test('rows on one server share a server key across folders', () {
    expect(
      S3AccountLocation.fromConfig(_s3(prefix: 'submersion-sync/')).serverKey,
      S3AccountLocation.fromConfig(
        _s3(prefix: 'submersion-sites/reef-team/'),
      ).serverKey,
    );
    expect(
      WebDavAccountLocation.fromConfig(_dav(folder: 'Submersion')).serverKey,
      WebDavAccountLocation.fromConfig(
        _dav(folder: 'Submersion Media'),
      ).serverKey,
    );
  });

  test('another host is another server', () {
    expect(
      S3AccountLocation.fromConfig(_s3()).serverKey,
      isNot(
        S3AccountLocation.fromConfig(
          _s3(endpoint: 'https://other.home:9000'),
        ).serverKey,
      ),
    );
  });

  test('tryParse rejects null, junk, unknown kinds and newer versions', () {
    for (final j in [
      null,
      '',
      '{',
      '[]',
      '{"v":1,"kind":"ftp"}',
      '{"v":2,"kind":"s3"}',
      '{"v":1,"kind":"s3","bucket":7}',
      // An address that does not parse would throw when grouped.
      '{"v":1,"kind":"webdav","serverUrl":"http://[::1","username":"u",'
          '"folder":"f"}',
    ]) {
      expect(AccountLocation.tryParse(j), isNull, reason: '$j');
    }
  });

  test('copyWith moves the folder and keeps the server', () {
    const s3 = S3AccountLocation(
      displayHost: 'minio.home',
      endpoint: 'https://minio.home',
      bucket: 'dives',
      region: 'us-east-1',
      prefix: 'submersion-sync/',
      pathStyle: true,
    );
    final moved = s3.copyWith(prefix: 'dives/');
    expect(moved.folder, 'dives');
    expect(moved.serverKey, s3.serverKey);
    const dav = WebDavAccountLocation(
      serverUrl: 'https://dav.home/dav',
      username: 'ann',
      folder: 'Submersion',
    );
    expect(dav.copyWith(folder: 'Dives').folder, 'Dives');
  });
}
