import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/google_drive/google_web_client_id_store.dart';

import '../../../../support/fake_keychain_storage.dart';

/// A browser signs in to Google with a client id from the user's own Google
/// Cloud project (issue #4121). The id is checked for shape before it is
/// kept, so a stray space or a missing suffix fails here with a message
/// rather than later with an opaque sign-in error.
void main() {
  const valid = '433819313354-abc123def.apps.googleusercontent.com';

  group('normalize', () {
    test('accepts a valid id and trims the whitespace around it', () {
      expect(GoogleWebClientIdStore.normalize('  $valid\n'), valid);
    });

    test('rejects an id missing the Google suffix', () {
      expect(
        GoogleWebClientIdStore.normalize('433819313354-abc123def'),
        isNull,
      );
      expect(
        GoogleWebClientIdStore.normalize(
          '433819313354-abc123def.apps.googleusercontent',
        ),
        isNull,
      );
    });

    test('rejects an empty or blank string', () {
      expect(GoogleWebClientIdStore.normalize(''), isNull);
      expect(GoogleWebClientIdStore.normalize('   '), isNull);
    });

    test('rejects a secret or a console URL pasted by mistake', () {
      expect(GoogleWebClientIdStore.normalize('GOCSPX-abc123'), isNull);
      expect(
        GoogleWebClientIdStore.normalize('https://console.cloud.google.com'),
        isNull,
      );
    });
  });

  test('the store round-trips through secure storage under its key', () async {
    final keychain = InMemoryKeychain();
    final store = GoogleWebClientIdStore(storage: keychain);
    expect(await store.read(), isNull);
    await store.write(valid);
    expect(keychain.values[GoogleWebClientIdStore.key], valid);
    expect(await store.read(), valid);
    await store.clear();
    expect(await store.read(), isNull);
  });
}
