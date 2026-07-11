import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
import 'package:submersion/core/services/sync/sync_initializer.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/settings/presentation/pages/s3_config_page.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/backup_sync_step.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_app.dart';

class _FakeSyncInit implements SyncInitializer {
  @override
  Future<void> saveProvider(CloudProviderType? provider) async {}

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

void main() {
  testWidgets('backup toggle reveals frequency and updates draft', (
    tester,
  ) async {
    late ProviderContainer container;
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          // Deterministic gates: not Apple, no Dropbox key.
          isApplePlatformProvider.overrideWithValue(false),
          dropboxConfiguredProvider.overrideWithValue(false),
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
      testApp(
        overrides: [
          ...overrides,
          isApplePlatformProvider.overrideWithValue(false),
          dropboxConfiguredProvider.overrideWithValue(false),
        ],
        child: const BackupSyncStep(mode: SetupWizardMode.firstRun),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('iCloud'), findsNothing);
    expect(find.text('Dropbox'), findsNothing);
    expect(find.text('S3'), findsOneWidget);
    expect(find.text('Not connected'), findsOneWidget);
  });

  testWidgets('tapping S3 opens the config page via the root navigator', (
    tester,
  ) async {
    // testApp provides a plain Navigator but NO GoRouter. The pre-fix
    // context.push would throw here; the fix uses the root Navigator so the
    // config page opens without going through the onboarding redirect.
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          isApplePlatformProvider.overrideWithValue(false),
          dropboxConfiguredProvider.overrideWithValue(false),
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

  const connectedNames = {
    CloudProviderType.icloud: 'iCloud',
    CloudProviderType.dropbox: 'Dropbox',
    CloudProviderType.s3: 'S3',
    CloudProviderType.googledrive: 'Google Drive',
  };
  for (final entry in connectedNames.entries) {
    testWidgets('settings mode shows connected UI for ${entry.value}', (
      tester,
    ) async {
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        testApp(
          overrides: [
            ...overrides,
            isApplePlatformProvider.overrideWithValue(false),
            dropboxConfiguredProvider.overrideWithValue(false),
            selectedCloudProviderTypeProvider.overrideWith((ref) => entry.key),
          ],
          child: const BackupSyncStep(mode: SetupWizardMode.settings),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connected to ${entry.value}'), findsOneWidget);
      expect(find.text('Manage in Settings'), findsOneWidget);

      // Toggling the cloud-copy switch drives setCloudBackupEnabled.
      await tester.tap(find.text('Keep a backup copy in the cloud'));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('first run can disconnect and return to the provider cards', (
    tester,
  ) async {
    late ProviderContainer container;
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          isApplePlatformProvider.overrideWithValue(false),
          dropboxConfiguredProvider.overrideWithValue(false),
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
      testApp(
        overrides: [
          ...overrides,
          isApplePlatformProvider.overrideWithValue(true),
          iCloudAvailabilityProvider.overrideWith(
            (ref) async => ICloudAvailability.available,
          ),
          dropboxConfiguredProvider.overrideWithValue(false),
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
      testApp(
        overrides: [
          ...overrides,
          isApplePlatformProvider.overrideWithValue(true),
          iCloudAvailabilityProvider.overrideWith(
            (ref) async => ICloudAvailability.unsupported,
          ),
          dropboxConfiguredProvider.overrideWithValue(false),
        ],
        child: const BackupSyncStep(mode: SetupWizardMode.firstRun),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('iCloud'), findsOneWidget);
    expect(find.text('iCloud is not available on this device'), findsOneWidget);
    // The disabled tile is not tappable.
    final tile = tester.widget<ListTile>(
      find.ancestor(of: find.text('iCloud'), matching: find.byType(ListTile)),
    );
    expect(tile.enabled, isFalse);
  });
}
