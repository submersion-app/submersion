import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/security/database_security_key_store.dart';
import 'package:submersion/core/services/security/database_security_service.dart';
import 'package:submersion/features/settings/presentation/pages/security_settings_page.dart';
import 'package:submersion/features/settings/presentation/widgets/security_setup_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/security_test_kdf.dart';
import '../../../../support/fake_keychain_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late String dbPath;
  late SharedPreferences prefs;
  late InMemoryKeychain keychain;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('security_page_test');
    dbPath = p.join(tmp.path, 'submersion.db');
    DatabaseSecurityService.instance.resetForTesting();
    DatabaseService.instance.resetForTesting();
    DatabaseService.instance.setCurrentPathForTesting(dbPath);
  });

  tearDown(() async {
    DatabaseSecurityService.instance.resetForTesting();
    DatabaseService.instance.resetForTesting();
    await tmp.delete(recursive: true);
  });

  Future<void> configure(Map<String, Object> prefsValues) async {
    SharedPreferences.setMockInitialValues(prefsValues);
    prefs = await SharedPreferences.getInstance();
    keychain = InMemoryKeychain();
    await DatabaseSecurityService.instance.configure(
      prefs: prefs,
      keyStore: DatabaseSecurityKeyStore(storage: keychain),
    );
  }

  Future<void> resetInMemorySecurity() async {
    DatabaseSecurityService.instance.resetForTesting();
    await DatabaseSecurityService.instance.configure(
      prefs: prefs,
      keyStore: DatabaseSecurityKeyStore(storage: keychain),
    );
  }

  /// Enables security with the cheap test KDF so the page's own unwrap paths
  /// (which read the per-slot params from the sidecar) stay fast.
  ///
  /// The wrap itself runs through [WidgetTester.runAsync]: Argon2id yields
  /// internally, and those yields never resume on testWidgets' fake clock,
  /// so calling it directly in a test body hangs until the 10-minute timeout.
  Future<void> configureWithPassword(
    WidgetTester tester,
    String password, {
    bool appLockEnabled = true,
  }) async {
    await configure({});
    await tester.runAsync(() async {
      await DatabaseSecurityService.instance.enableSecurity(
        password: password,
        dbPath: dbPath,
        kdf: testKdf,
      );
      if (appLockEnabled) {
        await DatabaseSecurityService.instance.setAppLockEnabled(true);
      }
    });
  }

  /// Alternates real-async windows with pumps. Argon2id yields internally,
  /// and those yields deadlock against testWidgets' fake clock, so the
  /// credential flows cannot be driven with pumpAndSettle alone. Same
  /// pattern as the startup lock-gate test.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }
  }

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        // testKdf: production Argon2id (64 MiB) is pure-Dart under
        // flutter test and makes the credential flows time out.
        home: Scaffold(body: SecuritySettingsPage(kdf: testKdf)),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows both toggles off by default', (tester) async {
    await configure({});
    await pumpPage(tester);
    expect(find.text('App Lock'), findsOneWidget);
    expect(find.text('Encrypt database'), findsOneWidget);
    final switches = tester
        .widgetList<SwitchListTile>(find.byType(SwitchListTile))
        .toList();
    expect(switches, hasLength(2));
    expect(switches.every((s) => s.value == false), true);
  });

  testWidgets('warns that encryption may affect performance in settings', (
    tester,
  ) async {
    await configure({});
    await pumpPage(tester);

    expect(
      find.textContaining('Encryption may affect performance.'),
      findsOneWidget,
    );
  });

  testWidgets('enabling app lock opens the setup dialog', (tester) async {
    await configure({});
    await pumpPage(tester);
    await tester.tap(find.text('App Lock'));
    await tester.pump();
    expect(find.byType(SecuritySetupDialog), findsOneWidget);
    expect(find.text('Set app password'), findsOneWidget);
  });

  testWidgets('with app lock on, shows management tiles', (tester) async {
    await configure({'app_lock_enabled': true});
    await pumpPage(tester);
    expect(find.text('Auto-lock'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
    expect(find.text('New recovery code'), findsOneWidget);
  });

  testWidgets('encryption toggle with app lock off launches setup first', (
    tester,
  ) async {
    await configure({});
    await pumpPage(tester);
    await tester.tap(find.text('Encrypt database'));
    await tester.pump();
    // The password setup dialog appears before any encryption confirm.
    expect(find.byType(SecuritySetupDialog), findsOneWidget);
  });

  testWidgets(
    'cancelling encryption after setup leaves app lock off and clears credentials',
    (tester) async {
      await configure({});
      await pumpPage(tester);
      await tester.tap(find.text('Encrypt database'));
      await tester.pump();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'encrypt-only');
      await tester.enterText(fields.at(1), 'encrypt-only');
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await settle(tester);
      await tester.tap(find.text('I saved my recovery code'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await settle(tester);

      expect(DatabaseSecurityService.instance.appLockEnabled, false);
      expect(find.text('Encrypt database?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await settle(tester);

      expect(DatabaseSecurityService.instance.appLockEnabled, false);
      expect(DatabaseSecurityService.instance.encryptionEnabled, false);
      expect(DatabaseSecurityService.instance.isUnlocked, false);
      expect(File(p.join(tmp.path, 'submersion.keys')).existsSync(), false);
    },
  );

  testWidgets(
    'orphaned sidecar unlocks existing credential before encryption confirmation',
    (tester) async {
      await configureWithPassword(
        tester,
        'existing-encryption-pw',
        appLockEnabled: false,
      );
      await resetInMemorySecurity();
      await pumpPage(tester);

      await tester.tap(find.text('Encrypt database'));
      await settle(tester);

      expect(find.byType(SecuritySetupDialog), findsNothing);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'existing-encryption-pw');
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await settle(tester);

      expect(find.text('Encrypt database?'), findsOneWidget);
      expect(DatabaseSecurityService.instance.appLockEnabled, false);
      expect(DatabaseSecurityService.instance.encryptionEnabled, false);
    },
  );

  testWidgets('encryption-only state renders encryption on and management', (
    tester,
  ) async {
    await configure({'db_encryption_enabled': true});
    await pumpPage(tester);

    final encryptionSwitch = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Encrypt database'),
    );
    expect(encryptionSwitch.value, true);
    expect(find.text('Change password'), findsOneWidget);
    expect(find.text('New recovery code'), findsOneWidget);
    expect(find.text('Auto-lock'), findsNothing);
  });

  testWidgets('encryption-only state can enable app lock without setup', (
    tester,
  ) async {
    await configureWithPassword(tester, 'pw', appLockEnabled: false);
    await DatabaseSecurityService.instance.preferences.setDbEncryptionEnabled(
      true,
    );
    await pumpPage(tester);

    await tester.tap(find.text('App Lock'));
    await tester.pump();

    expect(find.byType(SecuritySetupDialog), findsNothing);
    expect(DatabaseSecurityService.instance.appLockEnabled, true);
  });

  testWidgets(
    'locked encryption credential is required before enabling app lock',
    (tester) async {
      await configureWithPassword(tester, 'existing-pw', appLockEnabled: false);
      await DatabaseSecurityService.instance.preferences.setDbEncryptionEnabled(
        true,
      );
      await resetInMemorySecurity();
      await pumpPage(tester);

      await tester.tap(find.text('App Lock'));
      await settle(tester);

      expect(find.byType(SecuritySetupDialog), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(DatabaseSecurityService.instance.appLockEnabled, false);

      await tester.enterText(find.byType(TextField), 'existing-pw');
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await settle(tester);

      expect(DatabaseSecurityService.instance.appLockEnabled, true);
    },
  );

  group('auto-lock timeout', () {
    testWidgets('shows the current value and persists a new selection', (
      tester,
    ) async {
      await configure({
        'app_lock_enabled': true,
        'app_lock_timeout_minutes': 5,
      });
      await pumpPage(tester);
      expect(find.text('After 5 minutes'), findsOneWidget);

      await tester.tap(find.text('Auto-lock'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Immediately').last);
      await tester.pumpAndSettle();

      expect(
        DatabaseSecurityService.instance.preferences.appLockTimeoutMinutes,
        0,
      );
      expect(find.text('Immediately'), findsOneWidget);
    });

    testWidgets('offers never, which disables re-locking entirely', (
      tester,
    ) async {
      await configure({'app_lock_enabled': true});
      await pumpPage(tester);
      await tester.tap(find.text('Auto-lock'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Never').last);
      await tester.pumpAndSettle();
      expect(
        DatabaseSecurityService.instance.preferences.appLockTimeoutMinutes,
        -1,
      );
    });
  });

  group('change password', () {
    testWidgets('rejects the wrong current password, then rewraps so only '
        'the new one unlocks', (tester) async {
      await configureWithPassword(tester, 'original');
      await pumpPage(tester);

      await tester.tap(find.text('Change password'));
      await settle(tester);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'not-the-password');
      await tester.enterText(fields.at(1), 'brand-new-pw');
      await tester.enterText(fields.at(2), 'brand-new-pw');
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await settle(tester);
      expect(find.text('Incorrect password.'), findsOneWidget);

      await tester.enterText(fields.at(0), 'original');
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await settle(tester);

      // The credential actually changed: old rejected, new accepted.
      // runAsync: the unwrap runs Argon2id, which cannot make progress on
      // the fake clock.
      final svc = DatabaseSecurityService.instance;
      final oldWorks = await tester.runAsync(
        () => svc.unlockWithSecret('original', dbPath: dbPath),
      );
      final newWorks = await tester.runAsync(
        () => svc.unlockWithSecret('brand-new-pw', dbPath: dbPath),
      );
      expect(oldWorks, false);
      expect(newWorks, true);
    });

    testWidgets('validates the new password before touching the keyslot', (
      tester,
    ) async {
      await configureWithPassword(tester, 'original');
      await pumpPage(tester);
      await tester.tap(find.text('Change password'));
      await settle(tester);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'original');
      await tester.enterText(fields.at(1), 'new-password');
      await tester.enterText(fields.at(2), 'does-not-match');
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await settle(tester);
      expect(find.text('Passwords do not match.'), findsOneWidget);

      // Unchanged: the original still unlocks.
      final stillWorks = await tester.runAsync(
        () => DatabaseSecurityService.instance.unlockWithSecret(
          'original',
          dbPath: dbPath,
        ),
      );
      expect(stillWorks, true);
    });
  });

  group('regenerate recovery code', () {
    testWidgets('requires the password, then shows a code that unlocks', (
      tester,
    ) async {
      await configureWithPassword(tester, 'pw-for-recovery');
      await pumpPage(tester);

      await tester.tap(find.text('New recovery code'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'pw-for-recovery');
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await settle(tester);

      expect(find.text('Your recovery code'), findsOneWidget);
      final codeText = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .map((w) => w.data)
          .firstWhere((d) => d != null && d.contains('-'), orElse: () => null);
      expect(codeText, isNotNull, reason: 'the code must be displayed');

      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await settle(tester);

      final codeWorks = await tester.runAsync(
        () => DatabaseSecurityService.instance.unlockWithSecret(
          codeText!,
          dbPath: dbPath,
        ),
      );
      expect(
        codeWorks,
        true,
        reason: 'the displayed code must be the one that actually works',
      );
    });

    testWidgets('a wrong password does not regenerate anything', (
      tester,
    ) async {
      await configureWithPassword(tester, 'correct-pw');
      await pumpPage(tester);
      await tester.tap(find.text('New recovery code'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'wrong-pw');
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await settle(tester);

      expect(find.text('Incorrect password.'), findsOneWidget);
      expect(find.text('Your recovery code'), findsNothing);
    });
  });

  group('disable app lock', () {
    testWidgets('while encrypted preserves encryption and credentials', (
      tester,
    ) async {
      await configureWithPassword(tester, 'keep-encryption');
      await DatabaseSecurityService.instance.preferences.setDbEncryptionEnabled(
        true,
      );
      await pumpPage(tester);

      await tester.tap(find.text('App Lock'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'keep-encryption');
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await settle(tester);

      expect(find.text('Turn off App Lock?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Turn off'));
      await settle(tester);

      expect(DatabaseSecurityService.instance.appLockEnabled, false);
      expect(DatabaseSecurityService.instance.encryptionEnabled, true);
      expect(File(p.join(tmp.path, 'submersion.keys')).existsSync(), true);
    });

    testWidgets('requires the password and a confirmation, then clears '
        'security', (tester) async {
      await configureWithPassword(tester, 'to-be-removed');
      await pumpPage(tester);

      await tester.tap(find.text('App Lock'));
      await settle(tester);

      // Password gate first.
      await tester.enterText(find.byType(TextField), 'to-be-removed');
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await settle(tester);

      // Then an explicit confirmation.
      expect(find.text('Turn off App Lock?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Turn off'));
      await settle(tester);

      expect(DatabaseSecurityService.instance.appLockEnabled, false);
      expect(File(p.join(tmp.path, 'submersion.keys')).existsSync(), false);
    });

    testWidgets('cancelling the password prompt leaves app lock on', (
      tester,
    ) async {
      await configureWithPassword(tester, 'keep-me');
      await pumpPage(tester);
      await tester.tap(find.text('App Lock'));
      await settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await settle(tester);
      expect(DatabaseSecurityService.instance.appLockEnabled, true);
    });
  });

  group('encryption confirmation', () {
    testWidgets('explains the safety backup before encrypting', (tester) async {
      await configureWithPassword(tester, 'pw');
      await pumpPage(tester);
      await tester.tap(find.text('Encrypt database'));
      await settle(tester);
      expect(find.text('Encrypt database?'), findsOneWidget);
      expect(find.textContaining('safety backup'), findsOneWidget);
    });

    testWidgets(
      'warns that encryption may affect performance before enabling',
      (tester) async {
        await configureWithPassword(tester, 'pw');
        await pumpPage(tester);
        await tester.tap(find.text('Encrypt database'));
        await settle(tester);

        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.textContaining('Encryption may affect performance.'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('cancelling leaves encryption off', (tester) async {
      await configureWithPassword(tester, 'pw');
      await pumpPage(tester);
      await tester.tap(find.text('Encrypt database'));
      await settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await settle(tester);
      expect(DatabaseSecurityService.instance.encryptionEnabled, false);
    });
  });
}
