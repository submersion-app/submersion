import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/core/presentation/widgets/ocean_background.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
import 'package:submersion/core/services/sync/sync_initializer.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/storage_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/pages/setup_wizard_page.dart';
import 'package:submersion/features/settings/domain/setup/set_up_progress.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_flow_provider.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_indicator.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_navigation.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

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
  Future<PeerLibraryState> peerLibraryState(
    CloudStorageProvider provider,
  ) async => PeerLibraryState.none;

  /// A genuinely empty account: nothing under a peer's id and nothing under
  /// ours either, so there is no inherited identity to shed.
  @override
  Future<PeerLibraryState> firstContactLibraryState(
    CloudStorageProvider provider, {
    required bool localLibraryIsEmpty,
  }) async => PeerLibraryState.none;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSyncNotifier extends StateNotifier<SyncState>
    implements SyncNotifier {
  _FakeSyncNotifier() : super(const SyncState());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _drive = groupAccounts(
  rows: [
    ConnectedAccount(
      id: 'gd',
      kind: AccountKind.googledrive,
      label: 'Google Drive',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  ],
  statusById: const {'gd': AccountStatus.signedIn},
  localLocationById: const {},
  usagesOf: (_) => const [],
).single;

/// Stands in for the shared Set up steps: names the step, its host and the
/// account the flow holds, with a button per way the step can leave.
Widget _stubStep(SetUpStep step, SetUpStepNavigation navigation) => Consumer(
  builder: (context, ref, _) {
    final chosen = ref.watch(setUpFlowProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('stub ${step.name} ${navigation.host.name}'),
        Text('chosen ${chosen?.label}'),
        TextButton(
          onPressed: () {
            if (step == SetUpStep.account) {
              ref.read(setUpFlowProvider.notifier).choose(_drive);
            }
            navigation.onNext();
          },
          child: const Text('stub next'),
        ),
        TextButton(
          onPressed: navigation.onBack,
          child: const Text('stub back'),
        ),
        TextButton(
          onPressed: navigation.onNotNow,
          child: const Text('stub not now'),
        ),
        if (navigation.onSkip != null)
          TextButton(
            onPressed: navigation.onSkip,
            child: const Text('stub skip'),
          ),
        if (navigation.onNoLibrary != null)
          TextButton(
            onPressed: navigation.onNoLibrary,
            child: const Text('stub no library'),
          ),
      ],
    );
  },
);

/// OceanBackground animates forever, so pumpAndSettle would time out.
/// Fixed pumps cover the post-frame advance, the 300 ms page transition,
/// and the setState frame that follows the transition future.
Future<void> pumpWizard(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  // The sync-connect step reads the live diver count to decide whether this
  // install has a library of its own, so these tests need a database even
  // though they assert on navigation.
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  testWidgets('wizard ocean background follows resolved brightness', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: const SetupWizardPage(mode: SetupWizardMode.firstRun),
      ),
    );
    await pumpWizard(tester);

    final background = tester.widget<OceanBackground>(
      find.byType(OceanBackground),
    );
    expect(background.brightness, Brightness.dark);
  });

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
    expect(find.text('Set up a new profile'), findsOneWidget);
    expect(find.text('I have existing Submersion data'), findsOneWidget);

    await tester.tap(find.text('Set up a new profile'));
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

  testWidgets('wizard card hugs its content instead of filling the viewport', (
    tester,
  ) async {
    // A tall viewport makes "hug content" vs "fill height" unambiguous.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: const SetupWizardPage(mode: SetupWizardMode.firstRun),
      ),
    );
    await pumpWizard(tester);

    // The fork step is short, so the translucent card must be far shorter
    // than the 2400px viewport (regression guard against the old
    // SizedBox.expand full-height card).
    final cardHeight = tester
        .getSize(find.byKey(const ValueKey('setup_wizard_card')))
        .height;
    expect(cardHeight, lessThan(1200));
  });

  testWidgets('branch steps hug their content too, not the full viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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
    await tester.tap(find.text('Open an existing folder'));
    await pumpWizard(tester);
    expect(find.text('Open existing folder'), findsOneWidget);

    // The open-folder step is short (a title and a button). It uses a
    // SingleChildScrollView, which under the wizard's loose Flexible
    // constraints sizes to min(content, available) — so it hugs here and only
    // scrolls when a step is taller than the card, rather than filling the
    // 2400px viewport. (Guards the fix for the branch steps that previously
    // used filling Center/Expanded layouts.)
    final cardHeight = tester
        .getSize(find.byKey(const ValueKey('setup_wizard_card')))
        .height;
    expect(cardHeight, lessThan(1200));
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
        child: const SetupWizardPage(
          mode: SetupWizardMode.firstRun,
          setUpStepBody: _stubStep,
        ),
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
    expect(find.text('Set up a new profile'), findsOneWidget);
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
        child: const SetupWizardPage(
          mode: SetupWizardMode.firstRun,
          setUpStepBody: _stubStep,
        ),
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

    // Connect-cloud-sync source opens the shared account step.
    await tester.tap(find.text('Connect cloud sync'));
    await pumpWizard(tester);
    expect(find.text('stub account firstRun'), findsOneWidget);
  });

  Future<void> pumpStubbed(WidgetTester tester, SetupWizardMode mode) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: SetupWizardPage(mode: mode, setUpStepBody: _stubStep),
      ),
    );
    await pumpWizard(tester);
  }

  Future<void> tapStub(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await pumpWizard(tester);
  }

  Future<void> throughProfileAndUnitsFromProfile(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField), 'Eric');
    await pumpWizard(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await pumpWizard(tester); // -> units
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await pumpWizard(tester); // -> step 1
  }

  Future<void> throughProfileAndUnits(WidgetTester tester) async {
    await tester.tap(find.text('Set up a new profile'));
    await pumpWizard(tester);
    await tester.enterText(find.byType(TextFormField), 'Eric');
    await pumpWizard(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await pumpWizard(tester); // -> units
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await pumpWizard(tester); // -> step 1
  }

  testWidgets('the fresh path runs the four set up steps, each with its own '
      'buttons, then Finish', (tester) async {
    await pumpStubbed(tester, SetupWizardMode.firstRun);
    await throughProfileAndUnits(tester);

    for (final step in SetUpStep.values) {
      expect(find.text('stub ${step.name} firstRun'), findsOneWidget);
      // The wizard's own bottom bar stays out of the way.
      expect(find.widgetWithText(OutlinedButton, 'Back'), findsNothing);
      await tapStub(tester, 'stub next');
    }
    expect(find.text("You're all set"), findsOneWidget);
  });

  testWidgets('Not now on step 1 skips step 2; on steps 2 and 3 it moves on; '
      'Skip on step 4 reaches Finish', (tester) async {
    await pumpStubbed(tester, SetupWizardMode.firstRun);
    await throughProfileAndUnits(tester);

    await tapStub(tester, 'stub not now');
    expect(find.text('stub backups firstRun'), findsOneWidget);

    await tapStub(tester, 'stub back');
    expect(find.text('stub sync firstRun'), findsOneWidget);
    await tapStub(tester, 'stub not now');
    expect(find.text('stub backups firstRun'), findsOneWidget);
    await tapStub(tester, 'stub not now');
    expect(find.text('stub photos firstRun'), findsOneWidget);

    await tapStub(tester, 'stub skip');
    expect(find.text("You're all set"), findsOneWidget);
  });

  testWidgets('Back from step 1 returns to Units', (tester) async {
    await pumpStubbed(tester, SetupWizardMode.firstRun);
    await throughProfileAndUnits(tester);

    await tapStub(tester, 'stub back');
    expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);
    expect(find.text('stub account firstRun'), findsNothing);
  });

  testWidgets('the account survives the fall back to the fresh path', (
    tester,
  ) async {
    await pumpStubbed(tester, SetupWizardMode.firstRun);
    await tester.tap(find.text('I have existing Submersion data'));
    await pumpWizard(tester);
    await tester.tap(find.text('Connect cloud sync'));
    await pumpWizard(tester);

    // The fresh path never offers to start a new logbook in step 2.
    await tapStub(tester, 'stub next'); // chooses Google Drive
    expect(find.text('stub sync firstRun'), findsOneWidget);
    await tapStub(tester, 'stub no library');

    expect(find.text('Create Your Profile'), findsOneWidget);
    await throughProfileAndUnitsFromProfile(tester);
    expect(find.text('stub account firstRun'), findsOneWidget);
    expect(find.text('chosen Google Drive'), findsOneWidget);
    await tapStub(tester, 'stub next');
    expect(find.text('stub no library'), findsNothing);
  });

  testWidgets('Finish with no diver and no name asks for the profile', (
    tester,
  ) async {
    await pumpStubbed(tester, SetupWizardMode.firstRun);
    await tester.tap(find.text('I have existing Submersion data'));
    await pumpWizard(tester);
    await tester.tap(find.text('Connect cloud sync'));
    await pumpWizard(tester);
    for (var i = 0; i < 4; i++) {
      await tapStub(tester, 'stub next');
    }
    expect(find.text("You're all set"), findsOneWidget);

    await tester.ensureVisible(find.text('Get started'));
    await tester.pump();
    await tester.tap(find.text('Get started'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await pumpWizard(tester);

    expect(find.text('Create Your Profile'), findsOneWidget);
  });

  testWidgets('the Setup assistant runs Units, the four steps as the '
      'assistant, then Finish', (tester) async {
    await pumpStubbed(tester, SetupWizardMode.settings);
    expect(find.text('Units'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await pumpWizard(tester);

    for (final step in SetUpStep.values) {
      expect(find.text('stub ${step.name} assistant'), findsOneWidget);
      await tapStub(tester, 'stub next');
    }
    expect(find.text("You're all set"), findsOneWidget);
  });

  testWidgets('the four set up steps share one indicator dot, so a phone '
      'never overflows', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpStubbed(tester, SetupWizardMode.firstRun);
    await throughProfileAndUnits(tester);

    final indicator = find.byType(WizardStepIndicator);
    expect(tester.widget<WizardStepIndicator>(indicator).labels, [
      'Profile',
      'Units',
      'Data',
      'Done',
    ]);
    expect(tester.widget<WizardStepIndicator>(indicator).currentStep, 2);
    await tapStub(tester, 'stub next');
    expect(tester.widget<WizardStepIndicator>(indicator).currentStep, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a real set up step lays out inside the wizard card', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          accountGroupsProvider.overrideWith((ref) async => const []),
          offerableAccountKindsProvider.overrideWithValue(const []),
        ],
        child: const SetupWizardPage(mode: SetupWizardMode.settings),
      ),
    );
    await pumpWizard(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await pumpWizard(tester); // -> the real account step
    expect(find.text('Where should Submersion keep your data?'), findsOne);

    await tester.tap(find.text('Not now'));
    await pumpWizard(tester); // -> the real backups step
    expect(find.text('Back up automatically'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
