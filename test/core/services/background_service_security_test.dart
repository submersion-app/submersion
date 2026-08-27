import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/background_service.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/security/database_security_key_store.dart';
import 'package:submersion/core/services/security/database_security_service.dart';

import '../../helpers/security_test_kdf.dart';
import '../../support/fake_keychain_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    DatabaseSecurityService.instance.resetForTesting();
    DatabaseService.instance.resetForTesting();
  });

  tearDown(() {
    DatabaseSecurityService.instance.resetForTesting();
    DatabaseService.instance.resetForTesting();
  });

  test('ready when encryption is off', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    // Pre-wire the fake keychain so the helper's configure keeps it.
    await DatabaseSecurityService.instance.configure(
      prefs: prefs,
      keyStore: DatabaseSecurityKeyStore(storage: InMemoryKeychain()),
    );
    expect(await prepareHeadlessDatabaseKey(prefs: prefs), true);
    expect(DatabaseService.instance.databaseKeyHex, isNull);
  });

  test('skips when encrypted and no cached key exists', () async {
    SharedPreferences.setMockInitialValues({'db_encryption_enabled': true});
    final prefs = await SharedPreferences.getInstance();
    await DatabaseSecurityService.instance.configure(
      prefs: prefs,
      keyStore: DatabaseSecurityKeyStore(storage: InMemoryKeychain()),
    );
    expect(await prepareHeadlessDatabaseKey(prefs: prefs), false);
    expect(DatabaseService.instance.databaseKeyHex, isNull);
  });

  test('ready with key when encrypted and cached key exists', () async {
    final tmp = await Directory.systemTemp.createTemp('headless_test');
    addTearDown(() => tmp.delete(recursive: true));
    final dbPath = p.join(tmp.path, 'submersion.db');
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final keychain = InMemoryKeychain();
    await DatabaseSecurityService.instance.configure(
      prefs: prefs,
      keyStore: DatabaseSecurityKeyStore(storage: keychain),
    );
    await DatabaseSecurityService.instance.enableSecurity(
      password: 'pw',
      dbPath: dbPath,
      kdf: testKdf,
    );
    await DatabaseSecurityService.instance.preferences.setDbEncryptionEnabled(
      true,
    );
    // Simulate the headless isolate: fresh in-memory state, same keychain.
    DatabaseSecurityService.instance.resetForTesting();
    await DatabaseSecurityService.instance.configure(
      prefs: prefs,
      keyStore: DatabaseSecurityKeyStore(storage: keychain),
    );
    expect(await prepareHeadlessDatabaseKey(prefs: prefs), true);
    expect(DatabaseService.instance.databaseKeyHex, hasLength(64));
  });
}
