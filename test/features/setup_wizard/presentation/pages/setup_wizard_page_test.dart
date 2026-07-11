import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
import 'package:submersion/core/services/sync/sync_initializer.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/storage_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/pages/setup_wizard_page.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Idle fakes so the existing-data source steps render without real pickers,
/// timers, or sync services when driven through the shell.
class _FakeStorageNotifier extends StateNotifier<StorageConfigState>
    implements StorageConfigNotifier {
  _FakeStorageNotifier()
    : super(const StorageConfigState(config: StorageConfig()));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBackupOp extends StateNotifier<BackupOperationState>
    implements BackupOperationNotifier {
  _FakeBackupOp() : super(const BackupOperationState());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSyncInit implements SyncInitializer {
  @override
  Future<List<CloudFileInfo>> peerSyncFiles(
    CloudStorageProvider provider,
  ) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSyncNotifier extends StateNotifier<SyncState>
    implements SyncNotifier {
  _FakeSyncNotifier() : super(const SyncState());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// OceanBackground animates forever, so pumpAndSettle would time out.
/// Fixed pumps cover the post-frame advance, the 300 ms page transition,
/// and the setState frame that follows the transition future.
Future<void> pumpWizard(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('first run shows fork; fresh choice walks to profile and back', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: const SetupWizardPage(mode: SetupWizardMode.firstRun),
      ),
    );
    await pumpWizard(tester);

    expect(find.text('Welcome to Submersion'), findsOneWidget);
    expect(find.text('Set up a new logbook'), findsOneWidget);
    expect(find.text('I have existing Submersion data'), findsOneWidget);

    await tester.tap(find.text('Set up a new logbook'));
    await pumpWizard(tester);

    expect(find.text('Create Your Profile'), findsOneWidget);

    // Next disabled with empty name.
    final nextFinder = find.widgetWithText(FilledButton, 'Next');
    expect(tester.widget<FilledButton>(nextFinder).onPressed, isNull);

    await tester.enterText(find.byType(TextFormField), 'Eric');
    await pumpWizard(tester);
    expect(tester.widget<FilledButton>(nextFinder).onPressed, isNotNull);

    await tester.tap(nextFinder);
    await pumpWizard(tester);
    // Units placeholder page (real step lands in Task 7).
    expect(find.text('Units'), findsWidgets);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Back'));
    await pumpWizard(tester);
    expect(find.text('Create Your Profile'), findsOneWidget);
  });

  testWidgets('skip setup jumps from profile straight to finish placeholder', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: const SetupWizardPage(mode: SetupWizardMode.firstRun),
      ),
    );
    await pumpWizard(tester);

    await tester.ensureVisible(find.text('Skip setup'));
    await tester.pump();
    await tester.tap(find.text('Skip setup'));
    await pumpWizard(tester);
    expect(find.text('Create Your Profile'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Eric');
    await pumpWizard(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await pumpWizard(tester);

    expect(find.text("You're all set"), findsOneWidget);
  });

  testWidgets('settings mode starts at units with no fork', (tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: const SetupWizardPage(mode: SetupWizardMode.settings),
      ),
    );
    await pumpWizard(tester);

    expect(find.text('Welcome to Submersion'), findsNothing);
    expect(find.text('Units'), findsWidgets);
  });

  testWidgets('existing-data steps have a back button to the fork', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: const SetupWizardPage(mode: SetupWizardMode.firstRun),
      ),
    );
    await pumpWizard(tester);

    await tester.tap(find.text('I have existing Submersion data'));
    await pumpWizard(tester);
    expect(find.text('Bring your data'), findsOneWidget);

    // The choice step must be reversible (regression: it had no bottom bar
    // and no back affordance, stranding the user).
    final backButton = find.byTooltip('Back');
    expect(backButton, findsOneWidget);

    await tester.tap(backButton);
    await pumpWizard(tester);
    expect(find.text('Set up a new logbook'), findsOneWidget);
  });

  testWidgets('existing-data path renders each source step, reversibly', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          isApplePlatformProvider.overrideWithValue(false),
          dropboxConfiguredProvider.overrideWithValue(false),
          iCloudAvailabilityProvider.overrideWith(
            (ref) async => ICloudAvailability.unsupported,
          ),
          backupOperationProvider.overrideWith((ref) => _FakeBackupOp()),
          storageConfigNotifierProvider.overrideWith(
            (ref) => _FakeStorageNotifier(),
          ),
          syncInitializerProvider.overrideWithValue(_FakeSyncInit()),
          syncStateProvider.overrideWith((ref) => _FakeSyncNotifier()),
        ],
        child: const SetupWizardPage(mode: SetupWizardMode.firstRun),
      ),
    );
    await pumpWizard(tester);

    await tester.tap(find.text('I have existing Submersion data'));
    await pumpWizard(tester);
    expect(find.text('Bring your data'), findsOneWidget);

    // Restore source, then back to the choice.
    await tester.tap(find.text('Restore a backup file'));
    await pumpWizard(tester);
    expect(find.text('Restore backup'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await pumpWizard(tester);
    expect(find.text('Bring your data'), findsOneWidget);

    // Open-folder source, then back.
    await tester.tap(find.text('Open an existing folder'));
    await pumpWizard(tester);
    expect(find.text('Open existing folder'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await pumpWizard(tester);

    // Connect-cloud-sync source renders its connect phase.
    await tester.tap(find.text('Connect cloud sync'));
    await pumpWizard(tester);
    expect(find.widgetWithText(FilledButton, 'Continue'), findsOneWidget);
  });

  testWidgets('fresh path walks profile, units, backup, then finish', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          isApplePlatformProvider.overrideWithValue(false),
          dropboxConfiguredProvider.overrideWithValue(false),
          iCloudAvailabilityProvider.overrideWith(
            (ref) async => ICloudAvailability.unsupported,
          ),
        ],
        child: const SetupWizardPage(mode: SetupWizardMode.firstRun),
      ),
    );
    await pumpWizard(tester);

    await tester.tap(find.text('Set up a new logbook'));
    await pumpWizard(tester);
    await tester.enterText(find.byType(TextFormField), 'Eric');
    await pumpWizard(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await pumpWizard(tester); // -> units
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await pumpWizard(tester); // -> backup & sync
    expect(find.text('Backups & Sync'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await pumpWizard(tester); // -> finish
    expect(find.text("You're all set"), findsOneWidget);
  });

  testWidgets('sync pull with no peer library pivots back to the fresh path', (
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
          iCloudAvailabilityProvider.overrideWith(
            (ref) async => ICloudAvailability.unsupported,
          ),
          backupOperationProvider.overrideWith((ref) => _FakeBackupOp()),
          storageConfigNotifierProvider.overrideWith(
            (ref) => _FakeStorageNotifier(),
          ),
          syncInitializerProvider.overrideWithValue(_FakeSyncInit()),
          syncStateProvider.overrideWith((ref) => _FakeSyncNotifier()),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const SetupWizardPage(mode: SetupWizardMode.firstRun);
          },
        ),
      ),
    );
    await pumpWizard(tester);

    await tester.tap(find.text('I have existing Submersion data'));
    await pumpWizard(tester);
    await tester.tap(find.text('Connect cloud sync'));
    await pumpWizard(tester);

    // Simulate a completed connect, then pull: no peer library is found.
    container
        .read(setupWizardProvider(SetupWizardMode.firstRun).notifier)
        .setConnectedProvider(CloudProviderType.s3);
    await pumpWizard(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await pumpWizard(tester);
    expect(find.text('No library found'), findsOneWidget);

    // Starting fresh pivots the wizard back to the profile step.
    await tester.tap(find.widgetWithText(FilledButton, 'Start fresh'));
    await pumpWizard(tester);
    expect(find.text('Create Your Profile'), findsOneWidget);
  });
}
