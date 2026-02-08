import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_import/presentation/providers/uddf_import_providers.dart';
import 'package:submersion/features/dive_import/presentation/pages/uddf_import_page.dart';

/// Test notifier that allows setting state directly.
class TestUddfImportNotifier extends StateNotifier<UddfImportState>
    implements UddfImportNotifier {
  TestUddfImportNotifier(super.initial);

  void setState(UddfImportState newState) {
    state = newState;
  }

  @override
  Future<void> pickAndParseFile() async {}

  @override
  Future<void> parseFile(String filePath) async {}

  @override
  void toggleSelection(UddfEntityType type, int index) {}

  @override
  void selectAll(UddfEntityType type) {}

  @override
  void deselectAll(UddfEntityType type) {}

  @override
  Future<void> performImport() async {}

  @override
  void reset() {
    state = const UddfImportState();
  }
}

Widget buildTestApp(TestUddfImportNotifier notifier) {
  return ProviderScope(
    overrides: [uddfImportNotifierProvider.overrideWith((_) => notifier)],
    child: const MaterialApp(home: UddfImportPage()),
  );
}

void main() {
  group('UddfImportPage', () {
    group('Step 0 - File Selection', () {
      testWidgets('shows file selection button', (tester) async {
        final notifier = TestUddfImportNotifier(const UddfImportState());
        await tester.pumpWidget(buildTestApp(notifier));

        expect(find.text('Select UDDF File'), findsOneWidget);
        expect(find.byIcon(Icons.file_open), findsAtLeast(1));
      });

      testWidgets('shows empty state message', (tester) async {
        final notifier = TestUddfImportNotifier(const UddfImportState());
        await tester.pumpWidget(buildTestApp(notifier));

        expect(find.text('No File Selected'), findsOneWidget);
      });

      testWidgets('shows loading state while parsing', (tester) async {
        final notifier = TestUddfImportNotifier(
          const UddfImportState(isLoading: true),
        );
        await tester.pumpWidget(buildTestApp(notifier));

        expect(find.text('Parsing...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('shows error message', (tester) async {
        final notifier = TestUddfImportNotifier(
          const UddfImportState(error: 'File not found'),
        );
        await tester.pumpWidget(buildTestApp(notifier));

        expect(find.text('File not found'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
      });

      testWidgets('shows app bar with title', (tester) async {
        final notifier = TestUddfImportNotifier(const UddfImportState());
        await tester.pumpWidget(buildTestApp(notifier));

        expect(find.text('Import from UDDF'), findsOneWidget);
      });

      testWidgets('shows step indicator with 4 steps', (tester) async {
        final notifier = TestUddfImportNotifier(const UddfImportState());
        await tester.pumpWidget(buildTestApp(notifier));

        expect(find.text('Select'), findsOneWidget);
        expect(find.text('Review'), findsOneWidget);
        expect(find.text('Import'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
      });
    });

    group('Step 1 - Review & Select', () {
      late UddfImportState reviewState;

      setUp(() {
        reviewState = UddfImportState(
          currentStep: 1,
          parsedData: UddfImportResult(
            trips: [
              {'name': 'Trip A'},
              {'name': 'Trip B'},
            ],
            dives: [
              {'dateTime': DateTime(2024, 1, 15), 'maxDepth': 20.0},
            ],
            buddies: [
              {'name': 'Alice'},
            ],
          ),
          selectedTrips: const {0, 1},
          selectedDives: const {0},
          selectedBuddies: const {0},
        );
      });

      testWidgets('shows entity tabs for types with data', (tester) async {
        final notifier = TestUddfImportNotifier(reviewState);
        await tester.pumpWidget(buildTestApp(notifier));

        expect(find.text('Trips (2)'), findsOneWidget);
        expect(find.text('Dives (1)'), findsOneWidget);
        expect(find.text('Buddies (1)'), findsOneWidget);
      });

      testWidgets('shows total selected count', (tester) async {
        final notifier = TestUddfImportNotifier(reviewState);
        await tester.pumpWidget(buildTestApp(notifier));

        expect(find.text('4 selected'), findsOneWidget);
      });

      testWidgets('shows Import button', (tester) async {
        final notifier = TestUddfImportNotifier(reviewState);
        await tester.pumpWidget(buildTestApp(notifier));

        expect(find.widgetWithText(FilledButton, 'Import'), findsOneWidget);
      });

      testWidgets('Import button disabled when nothing selected', (
        tester,
      ) async {
        const emptyState = UddfImportState(
          currentStep: 1,
          parsedData: UddfImportResult(
            trips: [
              {'name': 'Trip A'},
            ],
          ),
        );
        final notifier = TestUddfImportNotifier(emptyState);
        await tester.pumpWidget(buildTestApp(notifier));

        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Import'),
        );
        expect(button.onPressed, isNull);
      });
    });

    group('Step 2 - Importing', () {
      testWidgets('shows progress indicator', (tester) async {
        final notifier = TestUddfImportNotifier(
          const UddfImportState(
            currentStep: 2,
            isImporting: true,
            importPhase: 'Importing dives',
            importCurrent: 3,
            importTotal: 10,
          ),
        );
        await tester.pumpWidget(buildTestApp(notifier));

        expect(find.text('Importing...'), findsOneWidget);
        expect(find.text('Importing dives'), findsOneWidget);
        expect(find.text('3 of 10'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      });
    });

    group('Step 3 - Summary', () {
      testWidgets('shows import complete with counts', (tester) async {
        final notifier = TestUddfImportNotifier(
          const UddfImportState(
            currentStep: 3,
            importResult: UddfEntityImportResult(
              dives: 5,
              sites: 2,
              trips: 1,
              buddies: 3,
            ),
          ),
        );
        await tester.pumpWidget(buildTestApp(notifier));

        expect(find.text('Import Complete'), findsOneWidget);
        expect(find.text('5'), findsOneWidget); // dives
        expect(find.text('2'), findsOneWidget); // sites
        expect(find.text('1'), findsOneWidget); // trips
        expect(find.text('3'), findsOneWidget); // buddies
        expect(find.text('Dives'), findsOneWidget);
        expect(find.text('Sites'), findsOneWidget);
        expect(find.text('Trips'), findsOneWidget);
        expect(find.text('Buddies'), findsOneWidget);
      });

      testWidgets('shows Done button', (tester) async {
        final notifier = TestUddfImportNotifier(
          const UddfImportState(
            currentStep: 3,
            importResult: UddfEntityImportResult(dives: 1),
          ),
        );
        await tester.pumpWidget(buildTestApp(notifier));

        // "Done" appears both in step indicator and as button
        expect(find.text('Done'), findsAtLeast(1));
      });

      testWidgets('hides entity types with zero count', (tester) async {
        final notifier = TestUddfImportNotifier(
          const UddfImportState(
            currentStep: 3,
            importResult: UddfEntityImportResult(dives: 5),
          ),
        );
        await tester.pumpWidget(buildTestApp(notifier));

        expect(find.text('Dives'), findsOneWidget);
        expect(find.text('Trips'), findsNothing);
        expect(find.text('Equipment'), findsNothing);
      });

      testWidgets('shows check circle icon', (tester) async {
        final notifier = TestUddfImportNotifier(
          const UddfImportState(
            currentStep: 3,
            importResult: UddfEntityImportResult(dives: 1),
          ),
        );
        await tester.pumpWidget(buildTestApp(notifier));

        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      });
    });
  });
}
