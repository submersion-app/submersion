import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/presentation/widgets/overlaid_profile_chart.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// A simple dive profile: descend to 18m, hold, ascend.
const _existingProfile = [
  DiveProfilePoint(timestamp: 0, depth: 0),
  DiveProfilePoint(timestamp: 60, depth: 10),
  DiveProfilePoint(timestamp: 120, depth: 18),
  DiveProfilePoint(timestamp: 300, depth: 18),
  DiveProfilePoint(timestamp: 360, depth: 5),
  DiveProfilePoint(timestamp: 420, depth: 0),
];

/// A different profile shape for the incoming dive.
const _incomingProfile = [
  DiveProfilePoint(timestamp: 0, depth: 0),
  DiveProfilePoint(timestamp: 90, depth: 12),
  DiveProfilePoint(timestamp: 180, depth: 22),
  DiveProfilePoint(timestamp: 360, depth: 22),
  DiveProfilePoint(timestamp: 420, depth: 5),
  DiveProfilePoint(timestamp: 480, depth: 0),
];

Widget _buildChart({
  List<DiveProfilePoint> existingProfile = const [],
  List<DiveProfilePoint> incomingProfile = const [],
  String? existingLabel,
  String? incomingLabel,
  double height = 80,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 600,
        height: 300,
        child: OverlaidProfileChart(
          existingProfile: existingProfile,
          incomingProfile: incomingProfile,
          existingLabel: existingLabel,
          incomingLabel: incomingLabel,
          height: height,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('OverlaidProfileChart - empty state', () {
    testWidgets('shows "No profile data" when both profiles empty', (
      tester,
    ) async {
      await tester.pumpWidget(_buildChart());
      await tester.pump();

      expect(find.text('No profile data'), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
    });
  });

  group('OverlaidProfileChart - single profile rendering', () {
    testWidgets('renders chart when only existing profile is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildChart(
          existingProfile: _existingProfile,
          existingLabel: 'Dive #42',
        ),
      );
      await tester.pump();

      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('No profile data'), findsNothing);
    });

    testWidgets('renders chart when only incoming profile is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildChart(
          incomingProfile: _incomingProfile,
          incomingLabel: 'Imported',
        ),
      );
      await tester.pump();

      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('No profile data'), findsNothing);
    });
  });

  group('OverlaidProfileChart - overlaid rendering', () {
    testWidgets('renders chart when both profiles provided', (tester) async {
      await tester.pumpWidget(
        _buildChart(
          existingProfile: _existingProfile,
          incomingProfile: _incomingProfile,
          existingLabel: 'Dive #42',
          incomingLabel: 'Imported',
        ),
      );
      await tester.pump();

      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('No profile data'), findsNothing);
    });
  });

  group('OverlaidProfileChart - legend checkboxes', () {
    testWidgets('shows existing legend only when existing has data', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildChart(
          existingProfile: _existingProfile,
          existingLabel: 'Dive #42',
        ),
      );
      await tester.pump();

      expect(find.text('Existing: Dive #42'), findsOneWidget);
      // No incoming legend since incoming profile is empty
      expect(find.textContaining('Incoming:'), findsNothing);
    });

    testWidgets('shows incoming legend only when incoming has data', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildChart(
          incomingProfile: _incomingProfile,
          incomingLabel: 'Imported',
        ),
      );
      await tester.pump();

      expect(find.text('Incoming: Imported'), findsOneWidget);
      expect(find.textContaining('Existing:'), findsNothing);
    });

    testWidgets('shows both legends when both profiles have data', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildChart(
          existingProfile: _existingProfile,
          incomingProfile: _incomingProfile,
          existingLabel: 'Dive #42',
          incomingLabel: 'Imported',
        ),
      );
      await tester.pump();

      expect(find.text('Existing: Dive #42'), findsOneWidget);
      expect(find.text('Incoming: Imported'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(2));
    });

    testWidgets('uses "Unknown" when labels are null', (tester) async {
      await tester.pumpWidget(
        _buildChart(
          existingProfile: _existingProfile,
          incomingProfile: _incomingProfile,
        ),
      );
      await tester.pump();

      expect(find.text('Existing: Unknown'), findsOneWidget);
      expect(find.text('Incoming: Unknown'), findsOneWidget);
    });
  });

  group('OverlaidProfileChart - toggle behavior', () {
    testWidgets('tapping existing checkbox hides existing series', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildChart(
          existingProfile: _existingProfile,
          incomingProfile: _incomingProfile,
          existingLabel: 'Dive #42',
          incomingLabel: 'Imported',
        ),
      );
      await tester.pump();

      // Both checkboxes start checked
      var checkboxes = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .toList();
      expect(checkboxes[0].value, isTrue); // existing
      expect(checkboxes[1].value, isTrue); // incoming

      // Tap the existing legend checkbox
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();

      // Now existing should be unchecked
      checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
      expect(checkboxes[0].value, isFalse); // existing hidden
      expect(checkboxes[1].value, isTrue); // incoming still visible
    });

    testWidgets('tapping incoming checkbox hides incoming series', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildChart(
          existingProfile: _existingProfile,
          incomingProfile: _incomingProfile,
          existingLabel: 'Dive #42',
          incomingLabel: 'Imported',
        ),
      );
      await tester.pump();

      // Tap the incoming legend checkbox
      await tester.tap(find.byType(Checkbox).last);
      await tester.pump();

      final checkboxes = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .toList();
      expect(checkboxes[0].value, isTrue); // existing still visible
      expect(checkboxes[1].value, isFalse); // incoming hidden
    });

    testWidgets(
      'cannot hide last visible series - tapping the only checked box does nothing',
      (tester) async {
        await tester.pumpWidget(
          _buildChart(
            existingProfile: _existingProfile,
            incomingProfile: _incomingProfile,
            existingLabel: 'Dive #42',
            incomingLabel: 'Imported',
          ),
        );
        await tester.pump();

        // First hide the existing series
        await tester.tap(find.byType(Checkbox).first);
        await tester.pump();

        // Now only incoming is visible. Try to hide incoming too.
        await tester.tap(find.byType(Checkbox).last);
        await tester.pump();

        // Incoming should still be checked since hiding it would leave no
        // visible series.
        final checkboxes = tester
            .widgetList<Checkbox>(find.byType(Checkbox))
            .toList();
        expect(checkboxes[0].value, isFalse); // existing remains hidden
        expect(checkboxes[1].value, isTrue); // incoming stays visible
      },
    );

    testWidgets('re-showing a hidden series works after toggle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildChart(
          existingProfile: _existingProfile,
          incomingProfile: _incomingProfile,
          existingLabel: 'Dive #42',
          incomingLabel: 'Imported',
        ),
      );
      await tester.pump();

      // Hide existing
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();

      // Re-show existing
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();

      // Both should be checked again
      final checkboxes = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .toList();
      expect(checkboxes[0].value, isTrue);
      expect(checkboxes[1].value, isTrue);
    });

    testWidgets(
      'single-profile legend checkbox cannot be hidden (no other series)',
      (tester) async {
        await tester.pumpWidget(
          _buildChart(
            existingProfile: _existingProfile,
            existingLabel: 'Dive #42',
          ),
        );
        await tester.pump();

        // Only one checkbox, try to uncheck it
        await tester.tap(find.byType(Checkbox).first);
        await tester.pump();

        // Should remain checked: incoming has no data, so hiding existing
        // would leave nothing visible.
        final checkbox = tester.widget<Checkbox>(find.byType(Checkbox).first);
        expect(checkbox.value, isTrue);
      },
    );
  });
}
