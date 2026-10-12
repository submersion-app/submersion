import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';

void main() {
  WebDavConfig make({
    String serverUrl = 'https://dav.example.com/dav',
    String folder = 'Submersion',
  }) => WebDavConfig(
    serverUrl: serverUrl,
    username: 'alice@example.com',
    password: 'secret',
    folder: folder,
  );

  group('davRoot', () {
    test('is the address as entered, with a trailing slash', () {
      expect(make().davRoot.toString(), 'https://dav.example.com/dav/');
      expect(
        make(serverUrl: ' https://dav.example.com/dav// ').davRoot.toString(),
        'https://dav.example.com/dav/',
      );
    });
  });

  group('chunkedUploadsRoot', () {
    test('is derived from a per-user files collection', () {
      expect(
        make(
          serverUrl: 'https://cloud.example.com/remote.php/dav/files/alice',
        ).chunkedUploadsRoot.toString(),
        'https://cloud.example.com/remote.php/dav/uploads/alice/',
      );
    });

    test('keeps a path prefix and an encoded user id', () {
      expect(
        make(
          serverUrl:
              'https://example.com/cloud/remote.php/dav/files/alice%40example.com/Backups',
        ).chunkedUploadsRoot.toString(),
        'https://example.com/cloud/remote.php/dav/uploads/alice%40example.com/',
      );
    });

    test('is null for any other address', () {
      expect(make().chunkedUploadsRoot, isNull);
      expect(
        make(
          serverUrl: 'https://cloud.example.com/remote.php/dav/files',
        ).chunkedUploadsRoot,
        isNull,
      );
      expect(
        make(
          serverUrl: 'https://cloud.example.com/remote.php/webdav',
        ).chunkedUploadsRoot,
        isNull,
      );
    });
  });

  group('folder normalization and validation', () {
    test('trims slashes and whitespace and collapses repeats', () {
      expect(make(folder: ' /Apps//Submersion/ ').folder, 'Apps/Submersion');
    });

    test('rejects dot segments, an empty folder and missing fields', () {
      expect(make(folder: 'Apps/../x').validate(), isNotNull);
      expect(make(folder: '  ').validate(), isNotNull);
      expect(make(serverUrl: 'ftp://x').validate(), isNotNull);
      expect(make(serverUrl: '').validate(), isNotNull);
      expect(make().copyWith(password: '').validate(), isNotNull);
      expect(make().validate(), isNull);
    });
  });

  test('isInsecure is true only for http', () {
    expect(make(serverUrl: 'http://nas.local').isInsecure, isTrue);
    expect(make().isInsecure, isFalse);
  });

  test('JSON round-trips every field and stores no server type', () {
    final c = make().copyWith(pinnedCertSha256: 'ab' * 32);
    final json = c.toJson();
    expect(WebDavConfig.fromJson(json).toJson(), json);
    expect(json.keys, isNot(contains('preset')));
    expect(json.keys, isNot(contains('nextcloudUserId')));
  });

  group('a config saved with a server type', () {
    Map<String, Object?> legacy(
      String preset, {
      String serverUrl = '',
      String username = 'alice@example.com',
      String? userId,
    }) => {
      'preset': preset,
      'serverUrl': serverUrl,
      'username': username,
      'password': 'secret',
      'folder': 'Submersion',
      'nextcloudUserId': userId,
      'pinnedCertSha256': null,
    };

    // Each expected address is the DAV root the old build connected to.
    // It feeds the account id, so it must come out byte for byte.
    test('host-only types become the per-user files address', () {
      for (final preset in ['nextcloud', 'owncloud']) {
        final c = WebDavConfig.fromJson(
          legacy(preset, serverUrl: 'https://cloud.example.com/'),
        );
        expect(
          c.davRoot.toString(),
          'https://cloud.example.com/remote.php/dav/files/alice%40example.com/',
        );
      }
    });

    test('the resolved user id wins over the login name', () {
      final c = WebDavConfig.fromJson(
        legacy(
          'nextcloud',
          serverUrl: 'https://cloud.example.com/sub',
          userId: 'alice',
        ),
      );
      expect(
        c.davRoot.toString(),
        'https://cloud.example.com/sub/remote.php/dav/files/alice/',
      );
      expect(
        c.chunkedUploadsRoot.toString(),
        'https://cloud.example.com/sub/remote.php/dav/uploads/alice/',
      );
    });

    test('fixed-address types get their address filled in', () {
      const expected = {
        'koofr': 'https://app.koofr.net/dav/Koofr/',
        'pcloudUs': 'https://webdav.pcloud.com/',
        'pcloudEu': 'https://ewebdav.pcloud.com/',
        'fastmail': 'https://myfiles.fastmail.com/',
        'yandex': 'https://webdav.yandex.com/',
      };
      for (final MapEntry(key: preset, value: root) in expected.entries) {
        final c = WebDavConfig.fromJson(legacy(preset));
        expect(c.davRoot.toString(), root, reason: preset);
        expect(c.validate(), isNull, reason: preset);
      }
    });

    test('address-as-entered and unknown types keep the address', () {
      for (final preset in ['synology', 'other', 'gopher']) {
        final c = WebDavConfig.fromJson(
          legacy(preset, serverUrl: 'https://nas.local:5006/dav'),
        );
        expect(c.davRoot.toString(), 'https://nas.local:5006/dav/');
      }
    });

    test('saves back without the server type', () {
      final json = WebDavConfig.fromJson(legacy('koofr')).toJson();
      expect(json['serverUrl'], 'https://app.koofr.net/dav/Koofr');
      expect(json.keys, isNot(contains('preset')));
    });
  });

  test('copyWith can clear the pin', () {
    final c = make().copyWith(pinnedCertSha256: 'ab' * 32);
    expect(c.copyWith(clearPin: true).pinnedCertSha256, isNull);
  });

  test('displayLabel is user @ host and never contains the password', () {
    expect(make().displayLabel, 'alice@example.com @ dav.example.com');
    expect(make().toString(), isNot(contains('secret')));
  });

  test('credentials embedded in the server URL are rejected', () {
    expect(
      make(serverUrl: 'https://u:secret@dav.example.com/dav').validate(),
      isNotNull,
    );
    expect(
      make(serverUrl: 'https://u@dav.example.com/dav').validate(),
      isNotNull,
    );
  });

  test('a server URL with a query or fragment is rejected', () {
    // The DAV paths are appended to the address, so they would land in
    // the query or fragment instead of the path.
    expect(
      make(serverUrl: 'https://dav.example.com/base?tenant=x').validate(),
      isNotNull,
    );
    expect(
      make(serverUrl: 'https://dav.example.com/base#frag').validate(),
      isNotNull,
    );
  });
}
