import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/download_step_widget.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_import_adapter_deps.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

DiscoveredDevice _testDevice() => DiscoveredDevice(
  id: 'test-device',
  name: 'Test Device',
  connectionType: DeviceConnectionType.usb,
  address: 'COM3',
  discoveredAt: DateTime(2026, 1, 1),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
//
// Regression guard for a bug Copilot caught on PR #216:
// DownloadStepWidget._startDownload() calls notifier.reset() immediately
// before notifier.startDownload(). reset() restores newDivesOnly to its
// default (true). Any earlier mutation of newDivesOnly (e.g., from an
// ancestor widget's initState) is wiped out before startDownload reads it.
//
// The fix is for DownloadStepWidget itself to apply setNewDivesOnly(false)
// AFTER reset() and BEFORE startDownload(), driven by its own
// forceFullDownload constructor argument. These tests verify that contract.

void main() {
  testWidgets(
    'forceFullDownload=true → newDivesOnly is false after _startDownload runs',
    (tester) async {
      final deps = FakeImportAdapterDeps();
      final container = ProviderContainer(
        overrides: [
          diveComputerServiceProvider.overrideWithValue(deps.fakeService),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DownloadStepWidget(
                device: _testDevice(),
                forceFullDownload: true,
                onComplete: () {},
                onError: (_) {},
              ),
            ),
          ),
        ),
      );

      // initState schedules _startDownload as a post-frame callback.
      // A single pump lets the callback fire; the async body runs up to
      // the startDownload await point which resolves immediately against
      // the fake service's no-op. newDivesOnly is set between reset() and
      // startDownload() in that body, so by this point it must be false.
      await tester.pump();

      expect(
        container.read(downloadNotifierProvider).newDivesOnly,
        isFalse,
        reason:
            'forceFullDownload must survive the reset() inside _startDownload; '
            'if this fails, the fingerprint-bypass flag is wiped out before '
            'libdivecomputer sees it and the re-import becomes a no-op.',
      );
    },
  );

  testWidgets('forceFullDownload=false (default) leaves newDivesOnly at true', (
    tester,
  ) async {
    final deps = FakeImportAdapterDeps();
    final container = ProviderContainer(
      overrides: [
        diveComputerServiceProvider.overrideWithValue(deps.fakeService),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DownloadStepWidget(
              device: _testDevice(),
              onComplete: () {},
              onError: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(
      container.read(downloadNotifierProvider).newDivesOnly,
      isTrue,
      reason:
          'default behavior must preserve fingerprint-based incremental '
          'download (newDivesOnly = true).',
    );
  });
}
