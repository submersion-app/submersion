import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Thin, non-throwing wrapper over local_auth. Platform support: iOS,
/// Android, macOS (Touch ID), Windows (Hello). Linux has no local_auth
/// backend — password-only there, and [isAvailable] says so.
class BiometricService {
  final LocalAuthentication _auth;
  final bool _platformSupported;

  /// [platformSupported] exists so tests do not depend on the host they run
  /// on: the Linux gate below would otherwise make every capability test
  /// pass on macOS and fail on CI's Linux runners.
  BiometricService({
    LocalAuthentication? auth,
    @visibleForTesting bool? platformSupported,
  }) : _auth = auth ?? LocalAuthentication(),
       _platformSupported = platformSupported ?? !Platform.isLinux;

  Future<bool> isAvailable() async {
    if (!_platformSupported) return false;
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // MissingPluginException is NOT a PlatformException: platforms with no
      // local_auth backend (and the flutter test host) land here.
      return false;
    }
  }

  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // Retry after the OS backgrounds the app mid-prompt (the 3.x
        // replacement for stickyAuth) instead of failing the unlock.
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
