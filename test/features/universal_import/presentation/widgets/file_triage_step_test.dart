import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/features/universal_import/presentation/widgets/file_triage_step.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

PickedImportFile file(
  String name,
  ImportFormat format,
  ImportFileStatus status,
) {
  return PickedImportFile(
    name: name,
    path: '/tmp/$name',
    detection: DetectionResult(format: format, confidence: 1),
    status: status,
  );
}

void main() {
  testWidgets('lists files with format names and greys excluded ones', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(universalImportNotifierProvider.notifier)
        .debugSetFilesForTest([
          file('a.fit', ImportFormat.fit, ImportFileStatus.pending),
          file('b.csv', ImportFormat.csv, ImportFileStatus.excludedCsv),
          file('c.xyz', ImportFormat.unknown, ImportFileStatus.unsupported),
        ]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: FileTriageStep()),
        ),
      ),
    );

    expect(find.text('a.fit'), findsOneWidget);
    expect(find.text('Garmin FIT'), findsOneWidget);
    expect(find.text('Import individually (CSV)'), findsOneWidget);
    expect(find.text('Unsupported format'), findsOneWidget);
    expect(find.text('1 file ready to import'), findsOneWidget);
  });

  testWidgets('shows "all excluded" when no file can join the batch', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(universalImportNotifierProvider.notifier)
        .debugSetFilesForTest([
          file('a.csv', ImportFormat.csv, ImportFileStatus.excludedCsv),
          file('b.xyz', ImportFormat.unknown, ImportFileStatus.unsupported),
        ]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: FileTriageStep()),
        ),
      ),
    );

    expect(find.textContaining('None of the selected files'), findsOneWidget);
  });

  testWidgets('parsed and failed tiles render their status', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(universalImportNotifierProvider.notifier)
        .debugSetFilesForTest([
          file('done.fit', ImportFormat.fit, ImportFileStatus.parsed),
          const PickedImportFile(
            name: 'oops.uddf',
            path: '/tmp/oops.uddf',
            detection: DetectionResult(
              format: ImportFormat.uddf,
              confidence: 1,
            ),
            status: ImportFileStatus.failed,
            error: 'broken',
          ),
        ]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: FileTriageStep()),
        ),
      ),
    );

    expect(find.text('done.fit'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.text('Could not be read'), findsOneWidget);
  });

  testWidgets('shows parse progress and cancel while loading', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(universalImportNotifierProvider.notifier);
    notifier.debugSetFilesForTest([
      file('a.fit', ImportFormat.fit, ImportFileStatus.pending),
      file('b.fit', ImportFormat.fit, ImportFileStatus.pending),
    ]);
    // Simulate an in-progress batch parse.
    notifier.state = notifier.state.copyWith(
      isLoading: true,
      parseCurrent: 1,
      parseTotal: 2,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: FileTriageStep()),
        ),
      ),
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('Parsing file 1 of 2'), findsOneWidget);

    // Tapping cancel flips the cooperative cancel flag.
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    // No exception; the flag is internal, so just assert the button existed.
    expect(find.text('Cancel'), findsOneWidget);
  });
}
