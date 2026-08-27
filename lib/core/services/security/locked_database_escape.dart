import 'dart:io';

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/security/database_security_key_store.dart';
import 'package:submersion/core/services/security/database_security_sidecar.dart';
import 'package:submersion/core/services/security/security_preferences.dart';
import 'package:submersion/core/services/sync/sync_preferences.dart'
    show disableSyncConfigurationInPrefs;

/// "Open a different database": sets the locked database ASIDE (never
/// deletes), clears the security configuration, and disables cloud sync so
/// the fresh database cannot cross-contaminate the old sync library (same
/// rationale as the Reset flow). The caller restarts initialization, which
/// creates a fresh plaintext DB and lands in the first-run wizard (where
/// restore-from-backup already lives).
Future<void> setAsideLockedDatabase({
  required String dbPath,
  required SharedPreferences prefs,
  DatabaseSecurityKeyStore? keyStore,
}) async {
  final stamp = DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());

  Future<void> setAside(String path, String target) async {
    final f = File(path);
    if (await f.exists()) await f.rename(target);
  }

  await setAside(dbPath, '$dbPath.locked-$stamp');
  await setAside('$dbPath-wal', '$dbPath.locked-$stamp-wal');
  await setAside('$dbPath-shm', '$dbPath.locked-$stamp-shm');
  final sidecar = DatabaseSecuritySidecar.pathFor(dbPath);
  await setAside(sidecar, '$sidecar.locked-$stamp');

  final securityPrefs = SecurityPreferences(prefs);
  await securityPrefs.setAppLockEnabled(false);
  await securityPrefs.setDbEncryptionEnabled(false);
  await (keyStore ?? DatabaseSecurityKeyStore()).clearKey();
  await disableSyncConfigurationInPrefs(prefs);
}
