import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
import 'package:submersion/core/services/sync/sync_initializer.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/settings/presentation/pages/s3_config_page.dart';
import 'package:submersion/features/settings/presentation/pages/webdav_config_page.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/cloud_provider_authenticate.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/backup_sync_step.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_app.dart';

class _FakeSyncInit implements SyncInitializer {
  @override
  Future<void> saveProvider(CloudProviderType? provider) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Authenticates on demand, so both the success and failure branches of
/// _connect are reachable.
class _FakeCloudProvider implements CloudStorageProvider {
  final Object? failWith;
  var authenticateCalls = 0;

  _FakeCloudProvider({this.failWith});

  @override
  Future<void> authenticate() async {
    authenticateCalls++;
    if (failWith != null) throw failWith!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSyncNotifier extends StateNotifier<SyncState>
    implements SyncNotifier {
  _FakeSyncNotifier() : super(const SyncState());

  @override
  Future<void> refreshState() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _englishTestApp({required Widget child, List<dynamic>? overrides}) =>
    testApp(locale: const Locale('en'), overrides: overrides, child: child);

void main() {
  testWidgets('backup toggle reveals frequency and updates draft', (
    tester,
  ) async {
    // Prove these English text finders are independent of the machine running
    // the suite. Without an explicit app locale below, this German host locale
    // makes the test fail before it ever reaches the interaction assertions.
    tester.binding.platformDispatcher.localesTestValue = const [
      Locale('de', 'DE'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    late ProviderContainer container;
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      _englishTestApp(
        overrides: [
          ...overrides,
          // Deterministic gates: not Apple, no Dropbox key, no Drive.
          isApplePlatformProvider.overrideWithValue(false),
          dropboxConfiguredProvider.overrideWithValue(false),
          googleDriveAvailableProvider.overrideWith((ref) async => false),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const BackupSyncStep(mode: SetupWizardMode.firstRun);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Frequency'), findsNothing);
    await tester.tap(find.text('Automatic backups'));
    await tester.pumpAndSettle();

    expect(find.text('Frequency'), findsOneWidget);
    await tester.tap(find.text('Daily'));
    await tester.pumpAndSettle();

    final draft = container.read(setupWizardProvider(SetupWizardMode.firstRun));
    expect(draft.backupEnabled, isTrue);
    expect(draft.backupFrequency, BackupFrequency.daily);
  });

  testWidgets('non-Apple platform without Dropbox shows S3 card only', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      _englishTestApp(
        overrides: [
          ...overrides,
          isApplePlatformProvider.overrideWithValue(false),
          dropboxConfiguredProvider.overrideWithValue(false),
          googleDriveAvailableProvider.overrideWith((ref) async => false),
        ],
        child: const BackupSyncStep(mode: SetupWizardMode.firstRun),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('iCloud'), findsNothing);
    expect(find.text('Dropbox'), findsNothing);
    expect(find.text('Google Drive'), findsNothing);
    expect(find.text('S3'), findsOneWidget);
    expect(find.text('Not connected'), findsOneWidget);
  });

  testWidgets('Google Drive card renders when the build supports it', (
    tester,
  ) async {
    // The wizard used to offer only iCloud, Dropbox and S3, so a first-run
    // user could not pick Google Drive even though Cloud Sync settings has
    // offered it all along.
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      _englishTestApp(
        overrides: [
          ...overrides,
          isApplePlatformProvider.overrideWithValue(false),
          dropboxConfiguredProvider.overrideWithValue(false),
          googleDriveAvailableProvider.overrideWith((ref) async => true),
        ],
        child: const BackupSyncStep(mode: SetupWizardMode.firstRun),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Google Drive'), findsOneWidget);
    final tile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Google Drive'),
        matching: find.byType(ListTile),
      ),
    );
    expect(tile.onTap, isNotNull);
  });

  testWidgets('Google Drive card is hidden on a build without OAuth config', (
    tester,
  ) async {
    // Desktop builds without the committed Desktop-app OAuth client cannot
    // authenticate, so the card is hidden rather than offered and broken --
    // the same treatment the wizard already gives an unconfigured Dropbox.
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      _englishTestApp(
        overrides: [
          ...overrides,
          isApplePlatformProvider.overrideWithValue(false),
          dropboxConfiguredProvider.overrideWithValue(false),
          googleDriveAvailableProvider.overrideWith((ref) async => false),
        ],
        child: const BackupSyncStep(mode: SetupWizardMode.firstRun),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Google Drive'), findsNothing);
  });

  testWidgets('tapping S3 opens the config page via the root navigator', (
    tester,
  ) async {
    // testApp provides a plain Navigator but NO GoRouter. The pre-fix
    // context.push would throw here; the fix uses the root Navigator so the
    // config page opens without going through the onboarding redirect.
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      _englishTestApp(
        overrides: [
          ...overrides,
          isApplePlatformProvider.overrideWithValue(false),
          dropboxConfiguredProvider.overrideWithValue(false),
          googleDriveAvailableProvider.overrideWith((ref) async => false),
          // Simulate S3 having been activated on the config page so the
          // post-return handler records it in the draft.
          selectedCloudProviderTypeProvider.overrideWith(
            (ref) => CloudProviderType.s3,
          ),
        ],
        child: const BackupSyncStep(mode: SetupWizardMode.firstRun),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('S3'));
    await tester.pumpAndSettle();
    expect(find.byType(S3ConfigPage), findsOneWidget);

    // Close the config page; the step reads the active provider and reflects
    // it as connected.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Connected to S3'), findsOneWidget);
  });

  testWidgets('tapping WebDAV opens its config page via the root navigator', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      _englishTestApp(
        overrides: [
          ...overrides,
          isApplePlatformProvider.overrideWithValue(false),
          dropboxConfiguredProvider.overrideWithValue(false),
          googleDriveAvailableProvider.overrideWith((ref) async => false),
          selectedCloudProviderTypeProvider.overrideWith(
            (ref) => CloudProviderType.webdav,
          ),
        ],
        child: const BackupSyncStep(mode: SetupWizardMode.firstRun),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('WebDAV'), findsOneWidget);
    await tester.tap(find.text('WebDAV'));
    await tester.pumpAndSettle();
    expect(find.byType(WebDavConfigPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Connected to WebDAV'), findsOneWidget);
  });

  const connectedNames = {
    CloudProviderType.icloud: 'iCloud',
    CloudProviderType.dropbox: 'Dropbox',
    CloudProviderType.s3: 'S3',
    CloudProviderType.googledrive: 'Google Drive',
    CloudProviderType.webdav: 'WebDAV',
  };
  for (final entry in connectedNames.entries) {
    testWidgets('settings mode shows connected UI for ${entry.value}', (
      tester,
    ) async {
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        _englishTestApp(
          overrides: [
            ...overrides,
            isApplePlatformProvider.overrideWithValue(false),
            dropboxConfiguredProvider.overrideWithValue(false),
            googleDriveAvailableProvider.overrideWith((ref) async => false),
            selectedCloudProviderTypeProvider.overrideWith((ref) => entry.key),
          ],
          child: const BackupSyncStep(mode: SetupWizardMode.settings),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connected to ${entry.value}'), findsOneWidget);
      expect(find.text('Manage in Settings'), findsOneWidget);

      // Toggling the cloud-copy switch drives setCloudBackupEnabled.
      await tester.tap(find.text('Store backups in the cloud'));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('connecting Google Drive records it in the draft', (
    tester,
  ) async {
    // _connect resolves the backend through cloudStorageProviderProvider --
    // the same seam Cloud Sync settings uses -- so a fake can stand in for
    // the real Drive singleton here.
    late ProviderContainer container;
    final cloud = _FakeCloudProvider();
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      _englishTestApp(
        overrides: [
          ...overrides,
          isApplePlatformProvider.overrideWithValue(false),
          dropboxConfiguredProvider.overrideWithValue(false),
          googleDriveAvailableProvider.overrideWith((ref) async => true),
          cloudStorageProviderProvider.overrideWithValue(cloud),
          syncInitializerProvider.overrideWithValue(_FakeSyncInit()),
          syncStateProvider.overrideWith((ref) => _FakeSyncNotifier()),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const BackupSyncStep(mode: SetupWizardMode.firstRun);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Google Drive'));
    await tester.pumpAndSettle();

    expect(cloud.authenticateCalls, 1);
    expect(
      container.read(selectedCloudProviderTypeProvider),
      CloudProviderType.googledrive,
    );
    expect(
      container
          .read(setupWizardProvider(SetupWizardMode.firstRun))
          .connectedProvider,
      CloudProviderType.googledrive,
    );
    expect(find.text('Connected to Google Drive'), findsOneWidget);
  });

  testWidgets('a failed connect rolls the selection back and reports it', (
    tester,
  ) async {
    late ProviderContainer container;
    final cloud = _FakeCloudProvider(
      failWith: const CloudStorageException('no network'),
    );
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      _englishTestApp(
        overrides: [
          ...overrides,
          isApplePlatformProvider.overrideWithValue(false),
          dropboxConfiguredProvider.overrideWithValue(false),
          googleDriveAvailableProvider.overrideWith((ref) async => true),
          cloudStorageProviderProvider.overrideWithValue(cloud),
          syncInitializerProvider.overrideWithValue(_FakeSyncInit()),
          syncStateProvider.overrideWith((ref) => _FakeSyncNotifier()),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const BackupSyncStep(mode: SetupWizardMode.firstRun);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Google Drive'));
    await tester.pumpAndSettle();

    // Nothing may stay half-selected after a failure: the card list comes
    // back and both the global selection and the draft are cleared.
    expect(container.read(selectedCloudProviderTypeProvider), isNull);
    expect(
      container
          .read(setupWizardProvider(SetupWizardMode.firstRun))
          .connectedProvider,
      isNull,
    );
    expect(find.text('Google Drive'), findsOneWidget);
    expect(find.textContaining('no network'), findsOneWidget);
  });

  testWidgets('cancelling the sign-in rolls back without an error', (
    tester,
  ) async {
    // A cancel is a decision, not a failure: the cards come back and nothing
    // is reported, unlike the genuine-failure case above.
    late ProviderContainer container;
    final cloud = _FakeCloudProvider(failWith: const CloudAuthCancelled());
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      _englishTestApp(
        overrides: [
          ...overrides,
          isApplePlatformProvider.overrideWithValue(false),
          dropboxConfiguredProvider.overrideWithValue(false),
          googleDriveAvailableProvider.overrideWith((ref) async => true),
          cloudStorageProviderProvider.overrideWithValue(cloud),
          syncInitializerProvider.overrideWithValue(_FakeSyncInit()),
          syncStateProvider.overrideWith((ref) => _FakeSyncNotifier()),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const BackupSyncStep(mode: SetupWizardMode.firstRun);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Google Drive'));
    await tester.pumpAndSettle();

    expect(container.read(selectedCloudProviderTypeProvider), isNull);
    expect(
      container
          .read(setupWizardProvider(SetupWizardMode.firstRun))
          .connectedProvider,
      isNull,
    );
    expect(find.text('Google Drive'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('Could not connect'), findsNothing);
  });

  testWidgets('connect reports an unresolvable backend instead of hanging', (
    tester,
  ) async {
    // cloudStorageProviderProvider returns null in custom-folder mode, where
    // app-managed sync is off. Surfacing that beats silently doing nothing.
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      _englishTestApp(
        overrides: [
          ...overrides,
          isApplePlatformProvider.overrideWithValue(false),
          dropboxConfiguredProvider.overrideWithValue(false),
          googleDriveAvailableProvider.overrideWith((ref) async => true),
          cloudStorageProviderProvider.overrideWithValue(null),
          syncInitializerProvider.overrideWithValue(_FakeSyncInit()),
          syncStateProvider.overrideWith((ref) => _FakeSyncNotifier()),
        ],
        child: const BackupSyncStep(mode: SetupWizardMode.firstRun),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Google Drive'));
    await tester.pumpAndSettle();

    // The message carries the display name, not the enum's `googledrive`.
    expect(
      find.text(
        AppLocalizationsEn().settings_cloudSync_provider_initFailed(
          'Google Drive',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('Google Drive'), findsOneWidget);
  });

  testWidgets('first run can disconnect and return to the provider cards', (
    tester,
  ) async {
    late ProviderContainer container;
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      _englishTestApp(
        overrides: [
          ...overrides,
          isApplePlatformProvider.overrideWithValue(false),
          dropboxConfiguredProvider.overrideWithValue(false),
          googleDriveAvailableProvider.overrideWith((ref) async => false),
          syncInitializerProvider.overrideWithValue(_FakeSyncInit()),
          syncStateProvider.overrideWith((ref) => _FakeSyncNotifier()),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const BackupSyncStep(mode: SetupWizardMode.firstRun);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Simulate a connected provider (e.g. iCloud connected, then a failed
    // pull left the user here). The cards are hidden.
    container
        .read(setupWizardProvider(SetupWizardMode.firstRun).notifier)
        .setConnectedProvider(CloudProviderType.icloud);
    await tester.pumpAndSettle();
    expect(find.text('Connected to iCloud'), findsOneWidget);
    expect(find.text('S3'), findsNothing);

    // Change provider clears the connection and restores the cards.
    await tester.tap(find.text('Change provider'));
    await tester.pumpAndSettle();
    expect(find.text('Connected to iCloud'), findsNothing);
    expect(find.text('S3'), findsOneWidget);
    expect(
      container
          .read(setupWizardProvider(SetupWizardMode.firstRun))
          .connectedProvider,
      isNull,
    );
  });

  testWidgets('iCloud card renders when the platform supports it', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      _englishTestApp(
        overrides: [
          ...overrides,
          isApplePlatformProvider.overrideWithValue(true),
          iCloudAvailabilityProvider.overrideWith(
            (ref) async => ICloudAvailability.available,
          ),
          dropboxConfiguredProvider.overrideWithValue(false),
          googleDriveAvailableProvider.overrideWith((ref) async => false),
        ],
        child: const BackupSyncStep(mode: SetupWizardMode.firstRun),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('iCloud'), findsOneWidget);
    expect(find.text('S3'), findsOneWidget);
  });

  testWidgets('unsupported iCloud on Apple shows a disabled explanation', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      _englishTestApp(
        overrides: [
          ...overrides,
          isApplePlatformProvider.overrideWithValue(true),
          iCloudAvailabilityProvider.overrideWith(
            (ref) async => ICloudAvailability.unsupported,
          ),
          dropboxConfiguredProvider.overrideWithValue(false),
          googleDriveAvailableProvider.overrideWith((ref) async => false),
        ],
        child: const BackupSyncStep(mode: SetupWizardMode.firstRun),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('iCloud'), findsOneWidget);
    // Issue #1088: "iCloud is not available on this device" read as a fault
    // with the user's Mac or iCloud account. The real cause is the build
    // (Developer ID signing cannot carry the iCloud entitlement), which is
    // what the Cloud Sync settings page already says. Asserting against the
    // settings string rather than a literal keeps the two surfaces from
    // drifting apart again.
    expect(
      find.text(
        AppLocalizationsEn()
            .settings_cloudSync_provider_icloud_unsupportedSubtitle,
      ),
      findsOneWidget,
    );
    // The disabled tile is not tappable.
    final tile = tester.widget<ListTile>(
      find.ancestor(of: find.text('iCloud'), matching: find.byType(ListTile)),
    );
    expect(tile.enabled, isFalse);
  });
}
