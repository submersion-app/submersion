import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_preset.dart';
import 'package:submersion/features/settings/presentation/widgets/webdav_server_fields.dart';

void main() {
  final saved = WebDavConfig(
    preset: WebDavPreset.nextcloud,
    serverUrl: 'https://cloud.example.com',
    username: 'alice@example.com',
    password: 'secret',
    nextcloudUserId: 'alice',
  );

  test('loading a config keeps its resolved Nextcloud user id', () {
    final form = WebDavFormController()..load(saved);
    addTearDown(form.dispose);
    expect(form.build().nextcloudUserId, 'alice');
  });

  test('editing the username or server drops the resolved user id', () {
    final form = WebDavFormController()..load(saved);
    addTearDown(form.dispose);
    form.username.text = 'bob@example.com';
    expect(form.build().nextcloudUserId, isNull);

    form.load(saved);
    form.serverUrl.text = 'https://other.example.com';
    expect(form.build().nextcloudUserId, isNull);
  });

  test('loading a config is not a user edit', () {
    final form = WebDavFormController()..load(saved);
    addTearDown(form.dispose);
    expect(form.userEdited, isFalse);
  });

  test('editing any field or the server type is a user edit', () {
    final edits = <String, void Function(WebDavFormController)>{
      'server': (f) => f.serverUrl.text = 'https://x.example.com',
      'username': (f) => f.username.text = 'bob',
      'password': (f) => f.password.text = 'pw',
      'folder': (f) => f.folder.text = 'Elsewhere',
      'preset': (f) => f.setPreset(WebDavPreset.owncloud),
    };
    for (final MapEntry(:key, :value) in edits.entries) {
      final form = WebDavFormController();
      addTearDown(form.dispose);
      value(form);
      expect(form.userEdited, isTrue, reason: key);
    }
  });
}
