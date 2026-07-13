import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/sync_encryption_service.dart'
    show WrongPassphraseException;
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_encryption_key_store.dart';
import 'package:submersion/features/backup/data/services/backup_encryption_service.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_recovery_code_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_encryption_section.dart';

import '../../../../support/fake_keychain_storage.dart';

/// A [BackupEncryptionService] whose crypto is stubbed out: enable / change /
/// regenerate return canned values (or throw a configured error) without ever
/// running Argon2id.
class _FakeBackupEncryptionService extends BackupEncryptionService {
  _FakeBackupEncryptionService()
    : super(keyStore: BackupEncryptionKeyStore(storage: InMemoryKeychain()));

  String recoveryCode = 'alpha-bravo-charlie-delta-echo';
  Object? regenerateError;

  @override
  Future<EnableBackupEncryptionResult> enable({
    required String passphrase,
    KdfParams kdf = const KdfParams(),
  }) async => EnableBackupEncryptionResult(
    recoveryCode: recoveryCode,
    libraryKeyId: 'k',
  );

  @override
  Future<void> changePassphrase({
    required String currentSecret,
    required String newPassphrase,
    KdfParams kdf = const KdfParams(),
  }) async {}

  @override
  Future<String> regenerateRecoveryCode({
    required String currentSecret,
    KdfParams kdf = const KdfParams(),
  }) async {
    if (regenerateError != null) throw regenerateError!;
    return recoveryCode;
  }
}

class _FakeDbAdapter implements BackupDatabaseAdapter {
  @override
  Future<void> backup(String destinationPath) async {}
  @override
  Future<void> restore(String backupPath) async {}
  @override
  Future<String> get databasePath async => '/fake/db';
  @override
  AppDatabase get database => throw UnimplementedError();
}

/// A [BackupService] whose only overridden method is the re-encrypt migration,
/// which returns a configurable tally so the section's snackbar branches can be
/// exercised without touching the filesystem.
class _FakeBackupService extends BackupService {
  _FakeBackupService(BackupPreferences preferences)
    : super(dbAdapter: _FakeDbAdapter(), preferences: preferences);

  ({int reencrypted, int skipped, int failed}) result = (
    reencrypted: 2,
    skipped: 0,
    failed: 0,
  );
  int reencryptCalls = 0;

  @override
  Future<({int reencrypted, int skipped, int failed})>
  reencryptExistingBackups() async {
    reencryptCalls++;
    return result;
  }
}

Future<({_FakeBackupEncryptionService enc, _FakeBackupService svc})> _pump(
  WidgetTester tester, {
  required bool enabled,
}) async {
  SharedPreferences.setMockInitialValues(
    enabled ? {'backup_encryption_enabled': true} : {},
  );
  final prefs = await SharedPreferences.getInstance();
  final enc = _FakeBackupEncryptionService();
  final svc = _FakeBackupService(BackupPreferences(prefs));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        backupEncryptionServiceProvider.overrideWithValue(enc),
        backupServiceProvider.overrideWithValue(svc),
      ],
      child: const MaterialApp(
        // Pinned: the assertions match English strings.
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: BackupEncryptionSection()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (enc: enc, svc: svc);
}

void main() {
  testWidgets('off state offers to encrypt backups', (tester) async {
    await _pump(tester, enabled: false);
    expect(find.text('Encrypt backups'), findsOneWidget);
    expect(find.text('Change password'), findsNothing);
  });

  testWidgets('on state shows manage actions', (tester) async {
    await _pump(tester, enabled: true);
    expect(find.text('Change password'), findsOneWidget);
    expect(find.text('Regenerate recovery code'), findsOneWidget);
    expect(find.text('Turn off encryption'), findsOneWidget);
    expect(find.text('Encrypt backups'), findsNothing);
  });

  testWidgets('tapping Encrypt backups opens the enable dialog', (
    tester,
  ) async {
    await _pump(tester, enabled: false);
    await tester.tap(find.text('Encrypt backups'));
    await tester.pumpAndSettle();
    // The enable dialog's two password fields are shown; no crypto runs yet.
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets(
    'full enable flow flips to on state then offers and runs re-encrypt',
    (tester) async {
      final fakes = await _pump(tester, enabled: false);
      await tester.tap(find.text('Encrypt backups'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'backuppass1');
      await tester.enterText(find.byType(TextField).at(1), 'backuppass1');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Recovery gate: tick saved, then Done.
      expect(find.textContaining('alpha-bravo'), findsOneWidget);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // The re-encrypt offer appears; accept it.
      expect(find.text('Encrypt existing backups?'), findsOneWidget);
      await tester.tap(find.text('Re-encrypt now'));
      await tester.pumpAndSettle();

      expect(fakes.svc.reencryptCalls, 1);
      expect(find.text('Re-encrypted 2 backups'), findsOneWidget);
      // Section rebuilt into the on state.
      expect(find.text('Change password'), findsOneWidget);
    },
  );

  testWidgets('declining the re-encrypt offer runs nothing', (tester) async {
    final fakes = await _pump(tester, enabled: false);
    await tester.tap(find.text('Encrypt backups'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'backuppass1');
    await tester.enterText(find.byType(TextField).at(1), 'backuppass1');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(fakes.svc.reencryptCalls, 0);
  });

  testWidgets('re-encrypt with failures shows the partial warning message', (
    tester,
  ) async {
    final fakes = await _pump(tester, enabled: false);
    fakes.svc.result = (reencrypted: 1, skipped: 0, failed: 2);

    await tester.tap(find.text('Encrypt backups'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'backuppass1');
    await tester.enterText(find.byType(TextField).at(1), 'backuppass1');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Re-encrypt now'));
    await tester.pumpAndSettle();

    expect(find.textContaining('could not be encrypted'), findsOneWidget);
  });

  testWidgets('Change password opens the dialog and closes on success', (
    tester,
  ) async {
    await _pump(tester, enabled: true);
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(3));

    await tester.enterText(find.byType(TextField).at(0), 'oldpass12');
    await tester.enterText(find.byType(TextField).at(1), 'newpass12');
    await tester.enterText(find.byType(TextField).at(2), 'newpass12');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Dialog closed: back to the section's four manage tiles, no TextFields.
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
    'Regenerate recovery code unlocks then shows the gated recovery dialog',
    (tester) async {
      await _pump(tester, enabled: true);
      await tester.tap(find.text('Regenerate recovery code'));
      await tester.pumpAndSettle();

      // The passphrase prompt: enter a secret and submit.
      await tester.enterText(find.byType(TextField), 'backuppass1');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.byType(BackupRecoveryCodeDialog), findsOneWidget);
      expect(find.textContaining('alpha-bravo'), findsOneWidget);
    },
  );

  testWidgets('Regenerate with a wrong secret keeps the prompt open', (
    tester,
  ) async {
    final fakes = await _pump(tester, enabled: true);
    fakes.enc.regenerateError = const WrongPassphraseException();

    await tester.tap(find.text('Regenerate recovery code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'wrong');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // No recovery code dialog; the passphrase prompt is still up.
    expect(find.byType(BackupRecoveryCodeDialog), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Turn off encryption confirms and flips to the off state', (
    tester,
  ) async {
    await _pump(tester, enabled: true);
    await tester.tap(find.text('Turn off encryption'));
    await tester.pumpAndSettle();

    expect(find.text('Turn off backup encryption?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Turn off encryption'));
    await tester.pumpAndSettle();

    expect(find.text('Encrypt backups'), findsOneWidget);
  });

  testWidgets('Turn off cancel keeps encryption on', (tester) async {
    await _pump(tester, enabled: true);
    await tester.tap(find.text('Turn off encryption'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Change password'), findsOneWidget);
  });
}
