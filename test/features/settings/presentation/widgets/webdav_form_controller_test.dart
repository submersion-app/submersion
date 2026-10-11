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
}
