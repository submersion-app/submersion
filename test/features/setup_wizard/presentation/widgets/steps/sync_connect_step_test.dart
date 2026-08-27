import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/crypto/encryption_key_store.dart';
import 'package:submersion/core/services/sync/crypto/sync_encryption_service.dart';
import 'package:submersion/core/services/sync/sync_initializer.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/sync_connect_step.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_app.dart';
import '../../../../../helpers/test_database.dart';
import '../../../../../support/fake_cloud_storage_provider.dart';

class _FakeSyncInit implements SyncInitializer {
  /// Peer artifacts on the account. Classified by the REAL rule, so these
  /// tests exercise the same manifest-vs-fragment logic production uses.
  List<CloudFileInfo> peers = [];
  bool throwOnPeers = false;

  @override
  Future<PeerLibraryState> peerLibraryState(
    CloudStorageProvider provider,
  ) async {
    if (throwOnPeers) throw Exception('network down');
    return SyncInitializer.classifyPeerFiles(peers);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSyncNotifier extends StateNotifier<SyncState>
    implements SyncNotifier {
  _FakeSyncNotifier({this.failSync = false, this.onSync, this.isUnlocked})
    : super(const SyncState());

  final bool failSync;

  /// Simulates the side effect of a real pull: writes rows into the live DB.
  final Future<void> Function()? onSync;

  /// Non-null models an ENCRYPTED library: until the callback reports an
  /// unlocked session, the pull halts with needsPassphrase and writes nothing,
  /// exactly as the real notifier does for SyncResultStatus.awaitingPassphrase
  /// (status stays idle -- it is not an error).
  final bool Function()? isUnlocked;

  int performSyncCalls = 0;

  @override
  Future<void> performSync({bool auto = false}) async {
    performSyncCalls++;
    if (failSync) {
      state = const SyncState(status: SyncStatus.error, message: 'sync boom');
      return;
    }
    if (isUnlocked != null && !isUnlocked!()) {
      state = const SyncState(
        status: SyncStatus.idle,
        needsPassphrase: true,
        message: 'Sync paused: this library is encrypted.',
      );
      return;
    }
    if (onSync != null) await onSync!();
    state = const SyncState(status: SyncStatus.success);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Only `unlock` is exercised here; the real Argon2id service is covered in
/// sync_encryption_service_test.dart and would deadlock a widget test.
class _FakeEncryptionService implements SyncEncryptionService {
  int unlockCalls = 0;

  @override
  Future<UnlockedKey> unlock({
    required CloudStorageProvider rawProvider,
    required String secret,
  }) async {
    unlockCalls++;
    return UnlockedKey(
      libraryKeyId: '8f14e45f-ceea-467f-ab37-a10a8d5f4c11',
      mlk: SecretKey(List<int>.generate(32, (i) => i)),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Writes a diver into the live test DB, mimicking what a real pull persists.
Future<void> _writeSyncedDiver() async {
  final now = DateTime.now();
  await DiverRepository().createDiver(
    Diver(
      id: '',
      name: 'Synced Diver',
      isDefault: true,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

void main() {
  late _FakeSyncInit syncInit;

  setUp(() async {
    syncInit = _FakeSyncInit();
    await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  /// [encryption] non-null models an ENCRYPTED cloud library this device has
  /// no key for: the pull halts on needsPassphrase until the unlock flow
  /// establishes a session.
  Future<List<Override>> overrides({
    bool hasDivers = true,
    bool failSync = false,
    Future<void> Function()? onSync,
    _FakeEncryptionService? encryption,
  }) async {
    final base = await getBaseOverrides();
    return [
      ...base,
      isApplePlatformProvider.overrideWithValue(false),
      dropboxConfiguredProvider.overrideWithValue(false),
      iCloudAvailabilityProvider.overrideWith(
        (ref) async => ICloudAvailability.unsupported,
      ),
      syncInitializerProvider.overrideWithValue(syncInit),
      syncStateProvider.overrideWith(
        (ref) => _FakeSyncNotifier(
          failSync: failSync,
          onSync: onSync,
          isUnlocked: encryption == null
              ? null
              : () => ref.read(encryptionKeyNotifierProvider) != null,
        ),
      ),
      hasAnyDiversProvider.overrideWith((ref) async => hasDivers),
      if (encryption != null) ...[
        syncEncryptionServiceProvider.overrideWithValue(encryption),
        // The unlock flow bails without a resolved provider to unlock against.
        cloudStorageProviderProvider.overrideWithValue(
          FakeCloudStorageProvider(),
        ),
      ],
    ];
  }

  testWidgets('connect phase gates Continue on a connected provider', (
    tester,
  ) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await overrides(),
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return SyncConnectStep(
              mode: SetupWizardMode.firstRun,
              onNoLibrary: () {},
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final continueButton = find.widgetWithText(FilledButton, 'Continue');
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

    container
        .read(setupWizardProvider(SetupWizardMode.firstRun).notifier)
        .setConnectedProvider(CloudProviderType.s3);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);
  });

  testWidgets('no peer library shows the no-library screen and pivots fresh', (
    tester,
  ) async {
    syncInit.peers = [];
    var pivoted = 0;
    late ProviderContainer container;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await overrides(),
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return SyncConnectStep(
              mode: SetupWizardMode.firstRun,
              onNoLibrary: () => pivoted++,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    container
        .read(setupWizardProvider(SetupWizardMode.firstRun).notifier)
        .setConnectedProvider(CloudProviderType.s3);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('No library found'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Start fresh'));
    expect(pivoted, 1);
  });

  testWidgets('a failing pull returns to the connect UI with an error', (
    tester,
  ) async {
    syncInit.throwOnPeers = true;
    late ProviderContainer container;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await overrides(),
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return SyncConnectStep(
              mode: SetupWizardMode.firstRun,
              onNoLibrary: () {},
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    container
        .read(setupWizardProvider(SetupWizardMode.firstRun).notifier)
        .setConnectedProvider(CloudProviderType.s3);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    // Error surfaced and the connect UI restored (Continue button present).
    expect(find.textContaining('Could not connect'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Continue'), findsOneWidget);
  });

  testWidgets('a failed sync returns to connect instead of "no library"', (
    tester,
  ) async {
    syncInit.peers = [
      CloudFileInfo(
        id: 'a',
        name: ChangesetLogLayout.manifestName('deviceB'),
        modifiedTime: DateTime(2026),
      ),
    ];
    late ProviderContainer container;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await overrides(failSync: true),
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return SyncConnectStep(
              mode: SetupWizardMode.firstRun,
              onNoLibrary: () {},
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    container
        .read(setupWizardProvider(SetupWizardMode.firstRun).notifier)
        .setConnectedProvider(CloudProviderType.s3);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not connect'), findsOneWidget);
    expect(find.text('No library found'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Continue'), findsOneWidget);
  });

  testWidgets('peer library pulls and shows the adopted screen', (
    tester,
  ) async {
    syncInit.peers = [
      CloudFileInfo(
        id: 'a',
        name: ChangesetLogLayout.manifestName('deviceB'),
        modifiedTime: DateTime(2026),
      ),
    ];
    late ProviderContainer container;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await overrides(onSync: _writeSyncedDiver),
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return SyncConnectStep(
              mode: SetupWizardMode.firstRun,
              onNoLibrary: () {},
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    container
        .read(setupWizardProvider(SetupWizardMode.firstRun).notifier)
        .setConnectedProvider(CloudProviderType.s3);
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(find.text('Library adopted'), findsOneWidget);
  });

  testWidgets('pulled divers are adopted even when the diver cache is stale', (
    tester,
  ) async {
    // Reproduces the setup-wizard bug: the pull writes a diver straight into
    // the DB, but the cached diver providers still report empty because their
    // pause-aware self-invalidation never fired (nothing is listening to
    // allDiversProvider in the wizard). The step must consult the live DB, not
    // the stale cache, or it wrongly shows "No library found" and pivots fresh.
    syncInit.peers = [
      CloudFileInfo(
        id: 'a',
        name: ChangesetLogLayout.manifestName('deviceB'),
        modifiedTime: DateTime(2026),
      ),
    ];
    final base = await getBaseOverrides();
    late ProviderContainer container;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...base,
          isApplePlatformProvider.overrideWithValue(false),
          dropboxConfiguredProvider.overrideWithValue(false),
          iCloudAvailabilityProvider.overrideWith(
            (ref) async => ICloudAvailability.unsupported,
          ),
          syncInitializerProvider.overrideWithValue(syncInit),
          syncStateProvider.overrideWith(
            (ref) => _FakeSyncNotifier(onSync: _writeSyncedDiver),
          ),
          // Stale cache: the DB has a diver, but the provider reports empty.
          allDiversProvider.overrideWith((ref) async => <Diver>[]),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return SyncConnectStep(
              mode: SetupWizardMode.firstRun,
              onNoLibrary: () {},
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    container
        .read(setupWizardProvider(SetupWizardMode.firstRun).notifier)
        .setConnectedProvider(CloudProviderType.s3);
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(find.text('Library adopted'), findsOneWidget);
    expect(find.text('No library found'), findsNothing);
  });

  testWidgets('a half-published library offers a retry, not "no library"', (
    tester,
  ) async {
    // Base parts with no manifest: the other device's publish never finished
    // (the manifest commits it and is written last). There is nothing to pull
    // yet, but the account is NOT empty -- pushing the user to Start Fresh
    // here would abandon data that is mid-upload.
    syncInit.peers = [
      CloudFileInfo(
        id: 'p0',
        name: ChangesetLogLayout.basePartName('deviceB', 1, 0),
        modifiedTime: DateTime(2026),
      ),
      CloudFileInfo(
        id: 'p1',
        name: ChangesetLogLayout.basePartName('deviceB', 1, 1),
        modifiedTime: DateTime(2026),
      ),
    ];
    var pivoted = 0;
    late ProviderContainer container;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await overrides(onSync: _writeSyncedDiver),
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return SyncConnectStep(
              mode: SetupWizardMode.firstRun,
              onNoLibrary: () => pivoted++,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    container
        .read(setupWizardProvider(SetupWizardMode.firstRun).notifier)
        .setConnectedProvider(CloudProviderType.s3);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('No library found'), findsNothing);
    expect(find.text('Library upload unfinished'), findsOneWidget);

    // Retrying once the peer has committed its manifest pulls the library.
    syncInit.peers = [
      ...syncInit.peers,
      CloudFileInfo(
        id: 'm',
        name: ChangesetLogLayout.manifestName('deviceB'),
        modifiedTime: DateTime(2026),
      ),
    ];
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Check again'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(find.text('Library adopted'), findsOneWidget);
    expect(pivoted, 0);
  });

  testWidgets('an encrypted library offers to unlock, not "no library"', (
    tester,
  ) async {
    // Issue #792: a fresh device joining an ENCRYPTED library halts with
    // needsPassphrase (status idle, nothing pulled). The step used to read
    // "not an error" as "the pull worked", find zero divers, and claim the
    // account held no library at all -- stranding the user with "Start fresh"
    // as the only way out of a wizard that had their data one passphrase away.
    syncInit.peers = [
      CloudFileInfo(
        id: 'a',
        name: ChangesetLogLayout.manifestName('deviceB'),
        modifiedTime: DateTime(2026),
      ),
    ];
    late ProviderContainer container;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await overrides(encryption: _FakeEncryptionService()),
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return SyncConnectStep(
              mode: SetupWizardMode.firstRun,
              onNoLibrary: () {},
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    container
        .read(setupWizardProvider(SetupWizardMode.firstRun).notifier)
        .setConnectedProvider(CloudProviderType.s3);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('No library found'), findsNothing);
    expect(find.text('This library is encrypted'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Enter passphrase'),
      findsOneWidget,
    );
  });

  testWidgets('unlocking an encrypted library re-pulls and adopts it', (
    tester,
  ) async {
    syncInit.peers = [
      CloudFileInfo(
        id: 'a',
        name: ChangesetLogLayout.manifestName('deviceB'),
        modifiedTime: DateTime(2026),
      ),
    ];
    final encryption = _FakeEncryptionService();
    late ProviderContainer container;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await overrides(
          encryption: encryption,
          onSync: _writeSyncedDiver,
        ),
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return SyncConnectStep(
              mode: SetupWizardMode.firstRun,
              onNoLibrary: () {},
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    container
        .read(setupWizardProvider(SetupWizardMode.firstRun).notifier)
        .setConnectedProvider(CloudProviderType.s3);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Enter passphrase'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.enterText(find.byType(TextField), 'correct horse battery');
      await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(encryption.unlockCalls, 1);
    expect(find.text('Library adopted'), findsOneWidget);
    expect(find.text('No library found'), findsNothing);
  });

  testWidgets('adopted screen Continue navigates to the dashboard', (
    tester,
  ) async {
    syncInit.peers = [
      CloudFileInfo(
        id: 'a',
        name: ChangesetLogLayout.manifestName('deviceB'),
        modifiedTime: DateTime(2026),
      ),
    ];
    var dashboard = false;
    ProviderContainer? container;
    final router = GoRouter(
      initialLocation: '/w',
      routes: [
        GoRoute(
          path: '/w',
          builder: (context, state) {
            container = ProviderScope.containerOf(context);
            return Scaffold(
              body: SyncConnectStep(
                mode: SetupWizardMode.firstRun,
                onNoLibrary: () {},
              ),
            );
          },
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) {
            dashboard = true;
            return const Scaffold(body: Text('dash'));
          },
        ),
      ],
    );
    await tester.pumpWidget(
      testAppRouter(
        locale: const Locale('en'),
        router: router,
        overrides: await overrides(onSync: _writeSyncedDiver),
      ),
    );
    await tester.pumpAndSettle();
    container!
        .read(setupWizardProvider(SetupWizardMode.firstRun).notifier)
        .setConnectedProvider(CloudProviderType.s3);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(dashboard, isTrue);
  });
}
