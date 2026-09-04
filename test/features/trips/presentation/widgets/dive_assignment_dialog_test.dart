import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/features/trips/presentation/widgets/dive_assignment_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Dive _makeDive({
  required String id,
  int? diveNumber,
  String? siteName,
  double? maxDepth,
  DateTime? dateTime,
}) {
  return Dive(
    id: id,
    dateTime: dateTime ?? DateTime(2025, 7, 10),
    diveNumber: diveNumber,
    maxDepth: maxDepth,
    site: siteName != null ? DiveSite(id: 'site-$id', name: siteName) : null,
  );
}

List<DiveCandidate> _testCandidates() {
  return [
    DiveCandidate(
      dive: _makeDive(
        id: 'dive-1',
        diveNumber: 42,
        siteName: 'Blue Hole',
        maxDepth: 30.0,
        dateTime: DateTime(2025, 7, 10),
      ),
    ),
    DiveCandidate(
      dive: _makeDive(
        id: 'dive-2',
        diveNumber: 43,
        siteName: 'Shark Reef',
        maxDepth: 18.5,
        dateTime: DateTime(2025, 7, 11),
      ),
    ),
    DiveCandidate(
      dive: _makeDive(
        id: 'dive-3',
        diveNumber: 44,
        siteName: 'Coral Garden',
        maxDepth: 12.0,
        dateTime: DateTime(2025, 7, 12),
      ),
      currentTripId: 'other-trip-1',
      currentTripName: 'Egypt Trip',
    ),
  ];
}

/// The dialog watches settingsProvider for the diver's date and depth units.
/// The real notifier reaches for DiverSettingsRepository and a DatabaseService
/// this harness never starts, so stand in with the shared mock.
Widget _scoped(Widget child) => ProviderScope(
  overrides: [settingsProvider.overrideWith((ref) => MockSettingsNotifier())],
  child: child,
);

Future<void> _openDialog(
  WidgetTester tester,
  List<DiveCandidate> candidates,
) async {
  late BuildContext savedContext;

  await tester.pumpWidget(
    _scoped(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              savedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // Open the dialog
  showDiveAssignmentDialog(context: savedContext, candidates: candidates);
  await tester.pumpAndSettle();
}

void main() {
  group('DiveAssignmentDialog', () {
    testWidgets('shows unassigned dives pre-checked and other-trip info', (
      tester,
    ) async {
      await _openDialog(tester, _testCandidates());

      // Title should be visible
      expect(find.text('Add Dives to Trip'), findsOneWidget);

      // Subtitle with count
      expect(find.text('3 dives found in date range'), findsOneWidget);

      // Unassigned group header
      expect(find.text('Unassigned (2)'), findsOneWidget);

      // Other trips group header
      expect(find.text('On other trips (1)'), findsOneWidget);

      // Dive numbers should be present (some may need scrolling)
      expect(find.text('#42'), findsOneWidget);
      expect(find.text('#43'), findsOneWidget);

      // Scroll down to reveal other-trip section
      await tester.scrollUntilVisible(
        find.text('#44'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(find.text('#44'), findsOneWidget);

      // Current trip name for other-trip dive
      expect(find.text('Currently on: Egypt Trip'), findsOneWidget);
    });

    testWidgets('returns selected dive IDs on confirm', (tester) async {
      List<String>? result;

      late BuildContext savedContext;
      await tester.pumpWidget(
        _scoped(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  savedContext = context;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final future = showDiveAssignmentDialog(
        context: savedContext,
        candidates: _testCandidates(),
      );
      await tester.pumpAndSettle();

      // The Add button should show count of pre-selected (2 unassigned)
      expect(find.text('Add 2 Dives'), findsOneWidget);

      // Tap Add button
      await tester.tap(find.text('Add 2 Dives'));
      await tester.pumpAndSettle();

      result = await future;

      // Should return only unassigned dive IDs (pre-checked)
      expect(result, isNotNull);
      expect(result, containsAll(['dive-1', 'dive-2']));
      expect(result, isNot(contains('dive-3')));
    });

    testWidgets('returns null on cancel', (tester) async {
      late BuildContext savedContext;
      await tester.pumpWidget(
        _scoped(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  savedContext = context;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final future = showDiveAssignmentDialog(
        context: savedContext,
        candidates: _testCandidates(),
      );
      await tester.pumpAndSettle();

      // Tap Cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final result = await future;
      expect(result, isNull);
    });

    testWidgets('returns null when close (X) button is tapped', (tester) async {
      late BuildContext savedContext;
      await tester.pumpWidget(
        _scoped(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  savedContext = context;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final future = showDiveAssignmentDialog(
        context: savedContext,
        candidates: _testCandidates(),
      );
      await tester.pumpAndSettle();

      // Tap close icon
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      final result = await future;
      expect(result, isNull);
    });

    testWidgets('group checkbox toggles all dives in that group', (
      tester,
    ) async {
      await _openDialog(tester, _testCandidates());

      // Initially 2 unassigned are selected, button shows "Add 2 Dives"
      expect(find.text('Add 2 Dives'), findsOneWidget);

      // Find the "Unassigned (2)" text and tap its checkbox to deselect all
      // The group header checkbox is the first checkbox in the unassigned section
      // We find checkboxes that are checked (true)
      final checkboxes = find.byType(Checkbox);
      // First checkbox should be the unassigned group header (checked)
      await tester.tap(checkboxes.first);
      await tester.pumpAndSettle();

      // Now no dives selected - button should be disabled and text changes
      expect(find.text('Add 0 Dives'), findsOneWidget);
    });

    testWidgets('add button disabled when no dives selected', (tester) async {
      await _openDialog(tester, _testCandidates());

      // Deselect all by tapping group checkbox
      final checkboxes = find.byType(Checkbox);
      await tester.tap(checkboxes.first);
      await tester.pumpAndSettle();

      // Find the FilledButton - it should be disabled
      final addButton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(addButton.onPressed, isNull);
    });
  });
}
