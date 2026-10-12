import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/features/settings/presentation/widgets/webdav_server_fields.dart';

void main() {
  final saved = WebDavConfig(
    serverUrl: 'https://cloud.example.com/remote.php/dav/files/alice',
    username: 'alice@example.com',
    password: 'secret',
    pinnedCertSha256: 'ab' * 32,
  );

  test('loading a config builds the same config back', () {
    final form = WebDavFormController()..load(saved);
    addTearDown(form.dispose);
    expect(form.build().toJson(), saved.toJson());
  });

  test('loading a config is not a user edit', () {
    final form = WebDavFormController()..load(saved);
    addTearDown(form.dispose);
    expect(form.userEdited, isFalse);
  });

  test('editing any field is a user edit', () {
    final edits = <String, void Function(WebDavFormController)>{
      'server': (f) => f.serverUrl.text = 'https://x.example.com',
      'username': (f) => f.username.text = 'bob',
      'password': (f) => f.password.text = 'pw',
      'folder': (f) => f.folder.text = 'Elsewhere',
    };
    for (final MapEntry(:key, :value) in edits.entries) {
      final form = WebDavFormController();
      addTearDown(form.dispose);
      value(form);
      expect(form.userEdited, isTrue, reason: key);
    }
  });
}
