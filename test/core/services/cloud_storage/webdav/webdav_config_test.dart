import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_preset.dart';

void main() {
  WebDavConfig make({
    WebDavPreset preset = WebDavPreset.other,
    String serverUrl = 'https://dav.example.com/dav',
    String folder = 'Submersion',
    String? userId,
  }) => WebDavConfig(
    preset: preset,
    serverUrl: serverUrl,
    username: 'alice@example.com',
    password: 'secret',
    folder: folder,
    nextcloudUserId: userId,
  );

  group('davRoot', () {
    test('Other uses the URL as entered, with a trailing slash', () {
      expect(make().davRoot.toString(), 'https://dav.example.com/dav/');
    });

    test('Nextcloud appends files/<user id>, preferring the resolved id', () {
      final c = make(
        preset: WebDavPreset.nextcloud,
        serverUrl: 'https://cloud.example.com/',
      );
      expect(
        c.davRoot.toString(),
        'https://cloud.example.com/remote.php/dav/files/alice%40example.com/',
      );
      expect(
        c.copyWith(nextcloudUserId: 'alice').davRoot.toString(),
        'https://cloud.example.com/remote.php/dav/files/alice/',
      );
      expect(
        c.copyWith(nextcloudUserId: 'alice').nextcloudUploadsRoot.toString(),
        'https://cloud.example.com/remote.php/dav/uploads/alice/',
      );
      expect(
        c.principalProbeUri.toString(),
        'https://cloud.example.com/remote.php/dav/',
      );
    });

    test('fixed-host presets ignore the server URL', () {
      expect(
        make(preset: WebDavPreset.koofr, serverUrl: '').davRoot.toString(),
        'https://app.koofr.net/dav/Koofr/',
      );
      expect(
        make(preset: WebDavPreset.pcloudEu, serverUrl: '').davRoot.host,
        'ewebdav.pcloud.com',
      );
    });

    test('only Nextcloud chunks', () {
      expect(make(preset: WebDavPreset.owncloud).nextcloudUploadsRoot, isNull);
      expect(WebDavPreset.nextcloud.supportsNextcloudChunking, isTrue);
      expect(WebDavPreset.owncloud.supportsNextcloudChunking, isFalse);
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
      expect(
        make(preset: WebDavPreset.koofr, serverUrl: '').validate(),
        isNull,
      );
    });
  });

  test('isInsecure is true only for http', () {
    expect(make(serverUrl: 'http://nas.local').isInsecure, isTrue);
    expect(make().isInsecure, isFalse);
  });

  test(
    'JSON round-trips every field, and an unknown preset reads as other',
    () {
      final c = make(
        preset: WebDavPreset.nextcloud,
        userId: 'alice',
      ).copyWith(pinnedCertSha256: 'ab' * 32);
      final back = WebDavConfig.fromJson(c.toJson());
      expect(back.toJson(), c.toJson());
      expect(
        WebDavConfig.fromJson({...c.toJson(), 'preset': 'gopher'}).preset,
        WebDavPreset.other,
      );
    },
  );

  test('copyWith can clear the pin and the user id', () {
    final c = make(userId: 'alice').copyWith(pinnedCertSha256: 'ab' * 32);
    final cleared = c.copyWith(clearPin: true, clearNextcloudUserId: true);
    expect(cleared.pinnedCertSha256, isNull);
    expect(cleared.nextcloudUserId, isNull);
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
