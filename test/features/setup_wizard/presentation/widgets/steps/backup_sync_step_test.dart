import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/settings/presentation/pages/s3_config_page.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/backup_sync_step.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_app.dart';

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
        ],
        child: const BackupSyncStep(mode: SetupWizardMode.firstRun),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('S3'));
    await tester.pumpAndSettle();

    expect(find.byType(S3ConfigPage), findsOneWidget);
  });
}
