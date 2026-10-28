import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/presentation/pages/startup_page.dart';
import 'package:submersion/core/presentation/pages/lock_screen_view.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/core/services/security/database_security_key_store.dart';
import 'package:submersion/core/services/security/database_security_service.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/data/demo_startup.dart';

import '../../../helpers/global_test_defaults.dart';
import '../../../helpers/security_test_kdf.dart';
import '../../../support/fake_keychain_storage.dart';

class _PathLocationService extends DatabaseLocationService {
  _PathLocationService(super.prefs, this._path);

  final String _path;

  @override
  Future<String> getDatabasePath() async => _path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late String realPath;
  late String demoPath;
  late SharedPreferences prefs;
  late LogFileService logFileService;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('startup_demo');
    realPath = p.join(tmp.path, 'submersion.db');
    demoPath = p.join(tmp.path, 'demo_mode', 'submersion_demo.db');
    Directory(p.dirname(demoPath)).createSync(recursive: true);
    // A plaintext SQLite header, as the sample logbook has.
    File(demoPath).writeAsBytesSync([
      ...'SQLite format 3'.codeUnits,
      0,
      ...List.filled(84, 0),
    ]);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    logFileService = LogFileService(logDirectory: p.join(tmp.path, 'logs'));
    DatabaseSecurityService.instance.resetForTesting();
    DatabaseService.instance.resetForTesting();
  });

  tearDown(() async {
    applyGlobalTestDefaults();
    DatabaseSecurityService.instance.resetForTesting();
    DatabaseService.instance.resetForTesting();
    await tmp.delete(recursive: true);
  });

  Future<void> settleRealAsync(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }
  }

  Widget wrapper({
    required List<String> probed,
    required void Function() onInitializeStarted,
  }) => StartupWrapper(
    prefs: prefs,
    logFileService: logFileService,
    locationService: _PathLocationService(prefs, realPath),
    demoStartupOverride: () async {
      DemoModeGate.instance.markActive(true);
      return DemoStartupDecision(demoPath);
    },
    initializerOverride: (_) {
      onInitializeStarted();
      return Completer<void>().future;
    },
    schemaVersionProbeOverride: (path) {
      probed.add(path);
      return (needsMigration: false, totalSteps: 0);
    },
  );

  testWidgets('demo mode active: the schema probe targets the demo file', (
    tester,
  ) async {
    final probed = <String>[];
    var started = false;

    await tester.pumpWidget(
      wrapper(probed: probed, onInitializeStarted: () => started = true),
    );
    await settleRealAsync(tester);

    expect(probed, [demoPath]);
    expect(started, isTrue);
    expect(DatabaseService.instance.databaseKeyHex, isNull);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets(
    'demo mode with encryption and app lock on: the lock still prompts, the '
    'encryption flag stays on, and the demo file opens without the key',
    (tester) async {
      await tester.runAsync(() async {
        await DatabaseSecurityService.instance.configure(
          prefs: prefs,
          keyStore: DatabaseSecurityKeyStore(storage: InMemoryKeychain()),
        );
        await DatabaseSecurityService.instance.enableSecurity(
          password: 'hunter2',
          dbPath: realPath,
          kdf: testKdf,
        );
        final security = DatabaseSecurityService.instance;
        await security.preferences.setDbEncryptionEnabled(true);
        await security.refreshDerivedKey();
        final real = DatabaseService.openRaw(
          realPath,
          mode: sqlite3.OpenMode.readWriteCreate,
          keyHex: security.databaseKeyHex,
        );
        real.execute('CREATE TABLE placeholder (x)');
        real.execute(
          'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
        );
        real.close();
        await security.setAppLockEnabled(true);
        DatabaseSecurityService.instance.resetForTesting();
        await DatabaseSecurityService.instance.configure(
          prefs: prefs,
          keyStore: DatabaseSecurityKeyStore(storage: InMemoryKeychain()),
        );
      });
      final probed = <String>[];
      var started = false;

      await tester.pumpWidget(
        wrapper(probed: probed, onInitializeStarted: () => started = true),
      );
      await settleRealAsync(tester);

      expect(find.byType(LockScreenView), findsOneWidget);
      expect(started, isFalse);

      await tester.enterText(find.byType(TextField), 'hunter2');
      await tester.tap(find.text('Unlock'));
      await settleRealAsync(tester);

      expect(started, isTrue);
      expect(probed, [demoPath]);
      expect(prefs.getBool('db_encryption_enabled'), isTrue);
      expect(DatabaseService.instance.databaseKeyHex, isNull);
      expect(DatabaseSecurityService.instance.databaseKeyHex, isNotNull);
      await tester.pump(const Duration(seconds: 2));
    },
  );
}
