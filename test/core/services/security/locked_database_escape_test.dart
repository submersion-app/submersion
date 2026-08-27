import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/security/database_security_key_store.dart';
import 'package:submersion/core/services/security/database_security_service.dart';
import 'package:submersion/core/services/security/locked_database_escape.dart';
import 'package:submersion/core/services/sync/sync_preferences.dart';

import '../../../helpers/security_test_kdf.dart';
import '../../../support/fake_keychain_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('setAsideLockedDatabase renames db, sidecars, keys; clears security '
      'and sync config', () async {
    final tmp = await Directory.systemTemp.createTemp('escape_test');
    addTearDown(() => tmp.delete(recursive: true));
    final dbPath = p.join(tmp.path, 'submersion.db');
    SharedPreferences.setMockInitialValues({
      'sync_auto_enabled': true,
      'sync_last_provider': 'icloud',
    });
    final prefs = await SharedPreferences.getInstance();
    final keychain = InMemoryKeychain();
    final keyStore = DatabaseSecurityKeyStore(storage: keychain);
    DatabaseSecurityService.instance.resetForTesting();
    await DatabaseSecurityService.instance.configure(
      prefs: prefs,
      keyStore: keyStore,
    );
    await DatabaseSecurityService.instance.enableSecurity(
      password: 'pw',
      dbPath: dbPath,
      kdf: testKdf,
    );
    File(dbPath).writeAsStringSync('DB');
    File('$dbPath-wal').writeAsStringSync('WAL');

    await setAsideLockedDatabase(
      dbPath: dbPath,
      prefs: prefs,
      keyStore: keyStore,
    );

    expect(File(dbPath).existsSync(), false);
    expect(File(p.join(tmp.path, 'submersion.keys')).existsSync(), false);
    final names = tmp
        .listSync()
        .map((e) => p.basename(e.path))
        .toList(growable: false);
    expect(
      names.where((n) => n.startsWith('submersion.db.locked-')),
      hasLength(2), // db + wal
    );
    expect(
      names.where((n) => n.startsWith('submersion.keys.locked-')),
      hasLength(1),
    );
    // Security prefs and keychain cleared.
    expect(DatabaseSecurityService.instance.appLockEnabled, false);
    expect(DatabaseSecurityService.instance.encryptionEnabled, false);
    expect(await keyStore.loadKey(), isNull);
    // Sync configuration disabled so the fresh DB cannot cross-contaminate
    // the old library.
    expect(SyncPreferences(prefs).autoSyncEnabled, false);
    expect(prefs.getString(syncLastProviderPrefsKey), isNull);

    DatabaseSecurityService.instance.resetForTesting();
  });

  test(
    'rebuildSidecar restores unlockability with new password and code',
    () async {
      final tmp = await Directory.systemTemp.createTemp('rebuild_test');
      addTearDown(() => tmp.delete(recursive: true));
      final dbPath = p.join(tmp.path, 'submersion.db');
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final keychain = InMemoryKeychain();
      final svc = DatabaseSecurityService.instance;
      svc.resetForTesting();
      await svc.configure(
        prefs: prefs,
        keyStore: DatabaseSecurityKeyStore(storage: keychain),
      );
      await svc.enableSecurity(password: 'pw', dbPath: dbPath, kdf: testKdf);

      // Simulate the lost sidecar; the keychain (and in-memory MLK) survive.
      File(p.join(tmp.path, 'submersion.keys')).deleteSync();

      final newCode = await svc.rebuildSidecar(
        password: 'new-pw',
        dbPath: dbPath,
        kdf: testKdf,
      );

      // Relaunch with an empty keychain: only the rebuilt sidecar can unlock.
      svc.resetForTesting();
      await svc.configure(
        prefs: prefs,
        keyStore: DatabaseSecurityKeyStore(storage: InMemoryKeychain()),
      );
      expect(await svc.unlockWithSecret('pw', dbPath: dbPath), false);
      expect(await svc.unlockWithSecret('new-pw', dbPath: dbPath), true);
      svc.resetForTesting();
      await svc.configure(
        prefs: prefs,
        keyStore: DatabaseSecurityKeyStore(storage: InMemoryKeychain()),
      );
      expect(await svc.unlockWithSecret(newCode, dbPath: dbPath), true);

      svc.resetForTesting();
    },
  );
}
