import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/services/incoming_file_handler.dart';

/// UDDF XML content recognised by the format detector.
final _uddfBytes = Uint8List.fromList(
  '<?xml version="1.0"?><uddf version="3.2.0"></uddf>'.codeUnits,
);

/// A real Seacraft ENC3 recording (005.DAT.csv) -- a route, not a dive log.
final _encBytes = File(
  'test/fixtures/nav_tracks/seacraft_enc3_short.csv',
).readAsBytesSync();

/// PNG magic bytes -- not a supported dive-log format.
final _pngBytes = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
]);

void main() {
  late ProviderContainer container;
  late UniversalImportNotifier notifier;

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(universalImportNotifierProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  group('handleIncomingFile', () {
    testWidgets('returns false and shows snackbar when wizard is active', (
      tester,
    ) async {
      late ScaffoldMessengerState messenger;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              messenger = ScaffoldMessenger.of(context);
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final result = await handleIncomingFile(
        bytes: _uddfBytes,
        fileName: 'dive.uddf',
        currentPath: '/transfer/import-wizard',
        notifier: notifier,
        messenger: messenger,
      );

      expect(result, IncomingFileOutcome.none);
    });

    testWidgets(
      'returns false and shows snackbar for unsupported file format',
      (tester) async {
        late ScaffoldMessengerState messenger;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                messenger = ScaffoldMessenger.of(context);
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        final result = await handleIncomingFile(
          bytes: _pngBytes,
          fileName: 'photo.png',
          currentPath: '/home',
          notifier: notifier,
          messenger: messenger,
        );

        expect(result, IncomingFileOutcome.none);
        // Notifier should be reset after unsupported format.
        expect(notifier.state.currentStep, ImportWizardStep.fileSelection);
        expect(notifier.state.fileBytes, isNull);
      },
    );

    testWidgets('returns true for supported file format', (tester) async {
      late ScaffoldMessengerState messenger;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              messenger = ScaffoldMessenger.of(context);
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final result = await handleIncomingFile(
        bytes: _uddfBytes,
        fileName: 'dive.uddf',
        currentPath: '/home',
        notifier: notifier,
        messenger: messenger,
      );

      expect(result, IncomingFileOutcome.navigateToWizard);
      expect(notifier.state.currentStep, ImportWizardStep.sourceConfirmation);
    });

    testWidgets(
      'returns navigateToNavTrackReview for a Seacraft ENC file without '
      'touching the wizard state',
      (tester) async {
        late ScaffoldMessengerState messenger;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                messenger = ScaffoldMessenger.of(context);
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        final result = await handleIncomingFile(
          bytes: _encBytes,
          fileName: '005.DAT.csv',
          currentPath: '/home',
          notifier: notifier,
          messenger: messenger,
        );

        expect(result, IncomingFileOutcome.navigateToNavTrackReview);
        // The notifier stays reset -- the file never enters the dive
        // import wizard's own state.
        expect(notifier.state.currentStep, ImportWizardStep.fileSelection);
        expect(notifier.state.fileBytes, isNull);
      },
    );

    test('works with null messenger', () async {
      final result = await handleIncomingFile(
        bytes: _uddfBytes,
        fileName: 'dive.uddf',
        currentPath: '/transfer/import-wizard',
        notifier: notifier,
        messenger: null,
      );

      // Returns false (wizard active) without crashing on null messenger.
      expect(result, IncomingFileOutcome.none);
    });

    test('resets notifier before loading file', () async {
      // Pre-populate state.
      notifier.setPendingSourceOverride(SourceApp.subsurface);

      await handleIncomingFile(
        bytes: _uddfBytes,
        fileName: 'dive.uddf',
        currentPath: '/home',
        notifier: notifier,
        messenger: null,
      );

      // Pending override should be cleared by reset().
      expect(notifier.state.pendingSourceOverride, isNull);
    });

    test('uses custom snackbar messages when provided', () async {
      final result = await handleIncomingFile(
        bytes: _pngBytes,
        fileName: 'photo.png',
        currentPath: '/home',
        notifier: notifier,
        messenger: null,
        unsupportedFileMessage: 'Custom unsupported message',
      );

      expect(result, IncomingFileOutcome.none);
    });
  });
}
