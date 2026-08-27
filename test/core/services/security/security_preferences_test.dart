import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/security/security_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SecurityPreferences> makePrefs() async {
    SharedPreferences.setMockInitialValues({});
    return SecurityPreferences(await SharedPreferences.getInstance());
  }

  test('defaults: both tiers off, 5 min timeout, biometrics on', () async {
    final prefs = await makePrefs();
    expect(prefs.appLockEnabled, false);
    expect(prefs.dbEncryptionEnabled, false);
    expect(prefs.appLockTimeoutMinutes, 5);
    expect(prefs.appLockBiometricsEnabled, true);
  });

  test('round-trips every setting', () async {
    final prefs = await makePrefs();
    await prefs.setAppLockEnabled(true);
    await prefs.setDbEncryptionEnabled(true);
    await prefs.setAppLockTimeoutMinutes(-1);
    await prefs.setAppLockBiometricsEnabled(false);
    expect(prefs.appLockEnabled, true);
    expect(prefs.dbEncryptionEnabled, true);
    expect(prefs.appLockTimeoutMinutes, -1);
    expect(prefs.appLockBiometricsEnabled, false);
  });
}
