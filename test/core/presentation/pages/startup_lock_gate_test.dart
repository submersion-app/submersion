import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/presentation/pages/lock_screen_view.dart';
import 'package:submersion/core/presentation/pages/startup_page.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/core/services/security/database_security_key_store.dart';
import 'package:submersion/core/services/security/database_security_service.dart';

import '../../../helpers/security_test_kdf.dart';
import '../../../support/fake_keychain_storage.dart';

/// A fake [DatabaseLocationService] that returns a caller-provided path.
class _PathLocationService extends DatabaseLocationService {
  final String _path;
  _PathLocationService(super.prefs, this._path);

  @override
  Future<String> getDatabasePath() async => _path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late String dbPath;
  late SharedPreferences prefs;
  late LogFileService logFileService;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('lock_gate_test');
    dbPath = p.join(tmp.path, 'submersion.db');
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    logFileService = LogFileService(logDirectory: p.join(tmp.path, 'logs'));
    DatabaseSecurityService.instance.resetForTesting();
    DatabaseService.instance.resetForTesting();
  });

  tearDown(() async {
    DatabaseSecurityService.instance.resetForTesting();
    DatabaseService.instance.resetForTesting();
    await tmp.delete(recursive: true);
  });

  /// Alternates real-async windows (so file I/O and crypto can progress)
  /// with pumps (so fake-zone microtask continuations run). A single
  /// runAsync window only advances ONE real-async hop of an await chain;
  /// the unlock path has several (sidecar read, Argon2id, keychain write).
  Future<void> settleRealAsync(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }
  }

  // The initializer records that it STARTED but never completes, mirroring
  // the existing startup tests: the ready state is never reached, so the
  // real app (which needs a live database) never mounts.
  Widget wrapper({required void Function() onInitializeStarted}) {
    return StartupWrapper(
      prefs: prefs,
      logFileService: logFileService,
      locationService: _PathLocationService(prefs, dbPath),
      initializerOverride: (_) {
        onInitializeStarted();
        return Completer<void>().future;
      },
      schemaVersionProbeOverride: (_) => (needsMigration: false, totalSteps: 0),
    );
  }

  testWidgets('no security: initializer starts without a lock screen', (
    tester,
  ) async {
    var started = false;
    await tester.pumpWidget(wrapper(onInitializeStarted: () => started = true));
    // Let the gate resolve (pure microtasks + sync file probe when security
    // is off).
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(find.byType(LockScreenView), findsNothing);
    expect(started, true);
    // Expire the 1-second minimum-splash timer so no timer outlives the test.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets(
    'app lock on: lock screen defers the initializer until unlock succeeds',
    (tester) async {
      // Arrange: security enabled on dbPath, then simulate a relaunch with an
      // EMPTY keychain so the password path (not biometrics) is exercised.
      await tester.runAsync(() async {
        await DatabaseSecurityService.instance.configure(
          prefs: prefs,
          keyStore: DatabaseSecurityKeyStore(storage: InMemoryKeychain()),
        );
        await DatabaseSecurityService.instance.enableSecurity(
          password: 'hunter2',
          dbPath: dbPath,
          kdf: testKdf,
        );
        await DatabaseSecurityService.instance.setAppLockEnabled(true);
        DatabaseSecurityService.instance.resetForTesting();
        await DatabaseSecurityService.instance.configure(
          prefs: prefs,
          keyStore: DatabaseSecurityKeyStore(storage: InMemoryKeychain()),
        );
      });

      var started = false;
      await tester.pumpWidget(
        wrapper(onInitializeStarted: () => started = true),
      );
      await settleRealAsync(tester);

      // Locked: the initializer must not have started.
      expect(find.byType(LockScreenView), findsOneWidget);
      expect(started, false);

      // Wrong password: still locked.
      await tester.enterText(find.byType(TextField), 'wrong');
      await tester.tap(find.text('Unlock'));
      await settleRealAsync(tester);
      expect(started, false);
      expect(find.text('Incorrect password. Try again.'), findsOneWidget);

      // Correct password: gate opens, the initializer starts.
      await tester.enterText(find.byType(TextField), 'hunter2');
      await tester.tap(find.text('Unlock'));
      await settleRealAsync(tester);
      expect(started, true);
      expect(find.byType(LockScreenView), findsNothing);
      // Expire the 1-second minimum-splash timer so no timer outlives the
      // test.
      await tester.pump(const Duration(seconds: 2));
    },
  );
}
