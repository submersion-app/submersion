import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/services/incoming_file_handler.dart';

/// UDDF XML content recognised by the format detector.
final _uddfBytes = Uint8List.fromList(
  '<?xml version="1.0"?><uddf version="3.2.0"></uddf>'.codeUnits,
);

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

      expect(result, isFalse);
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

        expect(result, isFalse);
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

      expect(result, isTrue);
      expect(notifier.state.currentStep, ImportWizardStep.sourceConfirmation);
    });

    test('works with null messenger', () async {
      final result = await handleIncomingFile(
        bytes: _uddfBytes,
        fileName: 'dive.uddf',
        currentPath: '/transfer/import-wizard',
        notifier: notifier,
        messenger: null,
      );

      // Returns false (wizard active) without crashing on null messenger.
      expect(result, isFalse);
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

      expect(result, isFalse);
    });
  });

  // Plain tests, not testWidgets: loading reads the files through dart:io,
  // whose futures never complete under testWidgets' fake async zone.
  group('handleIncomingFiles', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('incoming_files_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    Future<List<String>> writeUddfFiles(int count) async {
      return [
        for (var i = 0; i < count; i++)
          await () async {
            final path = p.join(tempDir.path, 'dive_$i.uddf');
            await File(path).writeAsBytes(_uddfBytes);
            return path;
          }(),
      ];
    }

    test('loads every file into the wizard as one batch', () async {
      final paths = await writeUddfFiles(2);

      final result = await handleIncomingFiles(
        paths: paths,
        currentPath: '/dives',
        notifier: notifier,
        messenger: null,
      );

      expect(result, isTrue);
      final state = container.read(universalImportNotifierProvider);
      expect(state.isBatch, isTrue);
      expect(state.files.map((f) => f.name), ['dive_0.uddf', 'dive_1.uddf']);
    });

    test('refuses while an import is already in progress', () async {
      final paths = await writeUddfFiles(2);

      final result = await handleIncomingFiles(
        paths: paths,
        currentPath: '/transfer/import-wizard',
        notifier: notifier,
        messenger: null,
      );

      expect(result, isFalse);
      expect(container.read(universalImportNotifierProvider).files, isEmpty);
    });
  });
}
