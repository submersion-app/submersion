import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/web/remember_credentials_provider.dart';

/// Natively credentials always live in the keychain, so the switch has
/// nothing to move and stays off; the browser's own behaviour runs in
/// test/web/platform/web_secure_storage_test.dart.
void main() {
  test('is off on a native build and stays off when set', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(rememberCredentialsProvider), isFalse);
    await container.read(rememberCredentialsProvider.notifier).set(true);
    expect(container.read(rememberCredentialsProvider), isFalse);
  });
}
