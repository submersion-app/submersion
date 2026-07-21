import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart' show StateNotifier;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/sync/crypto/encryption_key_store.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/sync_encryption_service.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/core/services/sync/sync_preferences.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/encryption_settings_section.dart';

import '../../../../helpers/test_app.dart';
import '../../../../support/fake_cloud_storage_provider.dart';
import '../../../../support/fake_keychain_storage.dart';

const _passphrase = 'correct horse battery staple';
const _keyId = '8f14e45f-ceea-467f-ab37-a10a8d5f4c11';

/// A fast, side-effect-light stand-in for the real service, so the SECTION's
/// orchestration can be exercised without running production Argon2id through
/// the UI. The real service is covered end-to-end in
/// sync_encryption_service_test.dart and encrypted_sync_integration_test.dart.
class _FakeEncryptionService implements SyncEncryptionService {
  _FakeEncryptionService(this._keyStore, this._preferences);

  final EncryptionKeyStore _keyStore;
  final SyncPreferences _preferences;

  int enableCalls = 0;
  int disableCalls = 0;
  int deleteKeyslotsCalls = 0;
  int selfHealCalls = 0;
  String? changedNewPassphrase;
  bool unlockShouldFail = false;

  SecretKey _mlk() => SecretKey(List<int>.generate(32, (i) => i));

  @override
  Future<EnableEncryptionResult> enable({
    required CloudStorageProvider rawProvider,
    required String passphrase,
    required LibraryEpochStore epochStore,
    required String deviceId,
    String? deviceName,
    String? appVersion,
    KdfParams kdf = const KdfParams(),
  }) async {
    enableCalls++;
    await _keyStore.saveKey(
      libraryKeyId: _keyId,
      mlkBytes: await _mlk().extractBytes(),
    );
    await _preferences.setSyncEncryptionEnabled(true);
    return const EnableEncryptionResult(
      recoveryCode: 'acid-acorn-acre-act-add-age-aid-aim',
      libraryKeyId: _keyId,
    );
  }

  @override
  Future<UnlockedKey> unlock({
    required CloudStorageProvider rawProvider,
    required String secret,
  }) async {
    if (unlockShouldFail) throw const WrongPassphraseException();
    await _keyStore.saveKey(
      libraryKeyId: _keyId,
      mlkBytes: await _mlk().extractBytes(),
    );
    await _preferences.setSyncEncryptionEnabled(true);
    return UnlockedKey(libraryKeyId: _keyId, mlk: _mlk());
  }

  @override
  Future<void> disable({
    required LibraryEpochStore epochStore,
    required String deviceId,
    String? deviceName,
    String? appVersion,
  }) async {
    disableCalls++;
    await _preferences.setSyncEncryptionEnabled(false);
  }

  @override
  Future<void> deleteCloudKeyslots(CloudStorageProvider rawProvider) async {
    deleteKeyslotsCalls++;
  }

  @override
  Future<void> changePassphrase({
    required CloudStorageProvider rawProvider,
    required String currentSecret,
    required String newPassphrase,
    KdfParams kdf = const KdfParams(),
  }) async {
    changedNewPassphrase = newPassphrase;
  }

  @override
  Future<String> regenerateRecoveryCode({
    required CloudStorageProvider rawProvider,
    required String passphrase,
    KdfParams kdf = const KdfParams(),
  }) async => 'new-code-one-two-three-four-five-six';

  @override
  Future<void> selfHealKeyslots(CloudStorageProvider rawProvider) async {
    selfHealCalls++;
  }
}

/// Returns a fixed device id so _markerIdentity() never touches a database.
class _FakeSyncRepository extends SyncRepository {
  @override
  Future<String> getDeviceId() async => 'device-a';
}

/// Records performSync so the flows can assert a sync was triggered.
class _RecordingSyncNotifier extends StateNotifier<SyncState>
    implements SyncNotifier {
  _RecordingSyncNotifier() : super(const SyncState());
  int performSyncCalls = 0;

  @override
  Future<void> performSync({bool auto = false}) async => performSyncCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopBackupAdapter implements BackupDatabaseAdapter {
  @override
  Future<void> backup(String destinationPath) async {}
  @override
  Future<void> restore(String backupPath) async {}
  @override
  Future<String> get databasePath async => '/noop';
  @override
  AppDatabase get database => throw UnimplementedError();
}

class _RecordingBackupService extends BackupService {
  _RecordingBackupService(BackupPreferences prefs)
    : super(dbAdapter: _NoopBackupAdapter(), preferences: prefs);
  int deleteCalls = 0;

  @override
  Future<int> deletePlaintextCloudBackups() async {
    deleteCalls++;
    return 0;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // _markerIdentity() reads the app version; stub it so the platform channel
    // never hangs the enable/disable flows in a widget test.
    PackageInfo.setMockInitialValues(
      appName: 'Submersion',
      packageName: 'app.submersion',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  late FakeCloudStorageProvider cloud;
  late EncryptionKeyStore keyStore;
  late SharedPreferences prefs;
  late _RecordingSyncNotifier syncNotifier;
  late _RecordingBackupService backupService;
  late _FakeEncryptionService service;

  Future<void> setUpProviders({
    required bool encryptionEnabled,
    bool withStoredKey = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      'sync_encryption_enabled': encryptionEnabled,
    });
    prefs = await SharedPreferences.getInstance();
    cloud = FakeCloudStorageProvider();
    keyStore = EncryptionKeyStore(storage: InMemoryKeychain());
    if (withStoredKey) {
      await keyStore.saveKey(
        libraryKeyId: _keyId,
        mlkBytes: List<int>.generate(32, (i) => i),
      );
    }
    syncNotifier = _RecordingSyncNotifier();
    backupService = _RecordingBackupService(BackupPreferences(prefs));
    service = _FakeEncryptionService(keyStore, SyncPreferences(prefs));
  }

  Widget wrap({bool nullProvider = false}) => testApp(
    child: const SingleChildScrollView(child: EncryptionSettingsSection()),
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      encryptionKeyStoreProvider.overrideWithValue(keyStore),
      syncEncryptionServiceProvider.overrideWithValue(service),
      cloudStorageProviderProvider.overrideWithValue(
        nullProvider ? null : cloud,
      ),
      syncStateProvider.overrideWith((ref) => syncNotifier),
      syncRepositoryProvider.overrideWithValue(_FakeSyncRepository()),
      backupServiceProvider.overrideWithValue(backupService),
    ],
  );

  testWidgets('enable flow: fills passphrase, saves recovery, deletes '
      'plaintext backups, and syncs', (tester) async {
    await setUpProviders(encryptionEnabled: false);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enable encryption'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Passphrase'),
      _passphrase,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm passphrase'),
      _passphrase,
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(service.enableCalls, 1);
    expect(find.text('I have saved my recovery code'), findsOneWidget);
    await tester.tap(find.text('I have saved my recovery code'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();

    expect(backupService.deleteCalls, 1);
    expect(syncNotifier.performSyncCalls, 1);
    expect(await keyStore.loadKey(), isNotNull);
  });

  testWidgets('unlock flow on a locked device recovers the key and syncs', (
    tester,
  ) async {
    await setUpProviders(encryptionEnabled: true);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Encrypted — passphrase needed'), findsOneWidget);
    await tester.tap(find.text('Enter passphrase'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), _passphrase);
    await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
    await tester.pumpAndSettle();

    expect(await keyStore.loadKey(), isNotNull);
    expect(syncNotifier.performSyncCalls, 1);
  });

  testWidgets('unlock flow shows an error on a wrong passphrase', (
    tester,
  ) async {
    await setUpProviders(encryptionEnabled: true);
    service.unlockShouldFail = true;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enter passphrase'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'nope');
    await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect passphrase or recovery code'), findsOneWidget);
    expect(syncNotifier.performSyncCalls, 0);
  });

  testWidgets('change passphrase flow calls the service with the new secret', (
    tester,
  ) async {
    await setUpProviders(encryptionEnabled: true, withStoredKey: true);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Change passphrase'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Current passphrase'),
      _passphrase,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'New passphrase'),
      'a whole new passphrase',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm passphrase'),
      'a whole new passphrase',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Change passphrase'));
    await tester.pumpAndSettle();

    expect(service.changedNewPassphrase, 'a whole new passphrase');
  });

  testWidgets('regenerate recovery code shows the new code', (tester) async {
    await setUpProviders(encryptionEnabled: true, withStoredKey: true);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generate new recovery code'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), _passphrase);
    await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
    await tester.pumpAndSettle();

    expect(find.text('new-code-one-two-three-four-five-six'), findsOneWidget);
    expect(find.text('I have saved my recovery code'), findsOneWidget);
    await tester.tap(find.text('I have saved my recovery code'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
  });

  testWidgets('disable flow confirms, clears the session, deletes keyslots, '
      'and syncs', (tester) async {
    await setUpProviders(encryptionEnabled: true, withStoredKey: true);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Turn off encryption'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Turn off encryption'));
    await tester.pumpAndSettle();

    expect(service.disableCalls, 1);
    expect(service.deleteKeyslotsCalls, 1);
    expect(syncNotifier.performSyncCalls, 1);
    expect(prefs.getBool('sync_encryption_enabled'), isFalse);
  });

  testWidgets('disable can be cancelled', (tester) async {
    await setUpProviders(encryptionEnabled: true, withStoredKey: true);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Turn off encryption'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(service.disableCalls, 0);
    expect(syncNotifier.performSyncCalls, 0);
  });

  testWidgets('unlock with no cloud provider bails without a dialog or sync', (
    tester,
  ) async {
    // Locked state but the provider resolves to null (custom-folder mode).
    // Tapping unlock must NOT open a dialog or report a spurious success.
    await setUpProviders(encryptionEnabled: true);
    await tester.pumpWidget(wrap(nullProvider: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enter passphrase'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Unlock'), findsNothing);
    expect(syncNotifier.performSyncCalls, 0);
  });
}
