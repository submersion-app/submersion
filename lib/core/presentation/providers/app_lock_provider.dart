import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/security/biometric_service.dart';
import 'package:submersion/core/services/security/database_security_service.dart';

/// True = the running app is locked behind the re-lock overlay. The database
/// stays open — this is a UI gate (App Lock tier), not a DB close.
final appLockNotifierProvider = NotifierProvider<AppLockNotifier, bool>(
  AppLockNotifier.new,
);

class AppLockNotifier extends Notifier<bool> {
  DateTime? _backgroundedAt;

  @override
  bool build() => false;

  DatabaseSecurityService get _security => DatabaseSecurityService.instance;

  /// Unconfigured service (early frames, widget tests that never touch
  /// security) means "app lock disabled" rather than a StateError.
  bool get _appLockEnabled {
    try {
      return _security.appLockEnabled;
    } on StateError {
      return false;
    }
  }

  void noteBackgrounded() {
    if (!_appLockEnabled) return;
    _backgroundedAt ??= clock.now();
  }

  void noteResumed() {
    final at = _backgroundedAt;
    _backgroundedAt = null;
    if (!_appLockEnabled || at == null) return;
    final timeout = _security.preferences.appLockTimeoutMinutes;
    if (timeout < 0) return; // -1 = never re-lock
    if (clock.now().difference(at).inMinutes >= timeout) {
      state = true;
    }
  }

  Future<bool> unlockWithSecret(String secret) async {
    final dbPath = await DatabaseService.instance.databasePath;
    final ok = await _security.unlockWithSecret(secret, dbPath: dbPath);
    if (ok) state = false;
    return ok;
  }

  Future<bool> unlockWithBiometric() async {
    if (!_security.preferences.appLockBiometricsEnabled) return false;
    final ok = await BiometricService().authenticate(
      reason: 'Unlock Submersion',
    );
    if (ok) state = false;
    return ok;
  }
}
