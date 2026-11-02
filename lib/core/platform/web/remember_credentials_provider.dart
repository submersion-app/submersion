import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/platform/secure_storage_backend.dart';

/// "Remember on this device" (issue #4121): whether a browser keeps the
/// credentials and passphrase past the tab, in local storage, or forgets
/// them when it closes. Off by default. Natively the keychain always keeps
/// them, so the switch has nothing to move and stays off.
class RememberCredentialsNotifier extends Notifier<bool> {
  @override
  bool build() => SecureStorageBackend.remember;

  /// Moves every stored credential to the store [value] names.
  Future<void> set(bool value) async {
    await SecureStorageBackend.setRemember(value);
    state = SecureStorageBackend.remember;
  }
}

final rememberCredentialsProvider =
    NotifierProvider<RememberCredentialsNotifier, bool>(
      RememberCredentialsNotifier.new,
    );
