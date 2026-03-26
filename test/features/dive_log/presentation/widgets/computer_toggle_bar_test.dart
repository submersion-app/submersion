import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/widgets/computer_toggle_bar.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildBar({
  required List<ComputerToggleItem> computers,
  void Function(String computerId, bool enabled)? onToggle,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ComputerToggleBar(
        computers: computers,
        onToggle: onToggle ?? (_, _) {},
      ),
    ),
  );
}

List<ComputerToggleItem> _twoComputers({
  bool firstEnabled = true,
  bool secondEnabled = true,
}) {
  return [
    ComputerToggleItem(
      computerId: 'comp-1',
      label: 'Suunto D5',
      isPrimary: true,
      isEnabled: firstEnabled,
      color: computerColorAt(0),
    ),
    ComputerToggleItem(
      computerId: 'comp-2',
      label: 'Shearwater Teric',
      isPrimary: false,
      isEnabled: secondEnabled,
      color: computerColorAt(1),
    ),
  ];
}

List<ComputerToggleItem> _threeComputers() {
  return [
    ComputerToggleItem(
      computerId: 'comp-1',
      label: 'Suunto D5',
      isPrimary: true,
      isEnabled: true,
      color: computerColorAt(0),
    ),
    ComputerToggleItem(
      computerId: 'comp-2',
      label: 'Shearwater Teric',
      isPrimary: false,
      isEnabled: true,
      color: computerColorAt(1),
    ),
    ComputerToggleItem(
      computerId: 'comp-3',
      label: 'Garmin Descent',
      isPrimary: false,
      isEnabled: false,
      color: computerColorAt(2),
    ),
  ];
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('computerColorAt', () {
    test('returns correct base colors for indices 0-3', () {
      expect(computerColorAt(0), equals(computerColors[0]));
      expect(computerColorAt(1), equals(computerColors[1]));
      expect(computerColorAt(2), equals(computerColors[2]));
      expect(computerColorAt(3), equals(computerColors[3]));
    });

    test('wraps with reduced alpha for index >= 4', () {
      final color4 = computerColorAt(4);
      // index 4 wraps to computerColors[0] with alpha 0.6
      expect(color4, equals(computerColors[0].withValues(alpha: 0.6)));

      final color5 = computerColorAt(5);
      expect(color5, equals(computerColors[1].withValues(alpha: 0.6)));

      final color7 = computerColorAt(7);
      expect(color7, equals(computerColors[3].withValues(alpha: 0.6)));
    });

    test('index within range returns full opacity color', () {
      for (var i = 0; i < computerColors.length; i++) {
        final color = computerColorAt(i);
        expect(color.a, equals(1.0));
      }
    });
  });

  group('ComputerToggleBar - shrink behavior', () {
    testWidgets('returns SizedBox.shrink when computers list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(_buildBar(computers: []));
      await tester.pump();

      // SizedBox.shrink is a zero-size box
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.width, equals(0.0));
      expect(sizedBox.height, equals(0.0));

      // No COMPUTERS label should appear
      expect(find.text('COMPUTERS'), findsNothing);
    });

    testWidgets('returns SizedBox.shrink when computers list has 1 item', (
      tester,
    ) async {
      final singleComputer = [
        ComputerToggleItem(
          computerId: 'comp-1',
          label: 'Suunto D5',
          isPrimary: true,
          isEnabled: true,
          color: computerColorAt(0),
        ),
      ];

      await tester.pumpWidget(_buildBar(computers: singleComputer));
      await tester.pump();

      expect(find.text('COMPUTERS'), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
    });
  });

  group('ComputerToggleBar - rendering with 2+ computers', () {
    testWidgets('renders COMPUTERS label and chips for each computer', (
      tester,
    ) async {
      await tester.pumpWidget(_buildBar(computers: _twoComputers()));
      await tester.pump();

      expect(find.text('COMPUTERS'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(2));
      expect(find.text('Suunto D5 (primary)'), findsOneWidget);
      expect(find.text('Shearwater Teric'), findsOneWidget);
    });

    testWidgets('renders chips for three computers', (tester) async {
      await tester.pumpWidget(_buildBar(computers: _threeComputers()));
      await tester.pump();

      expect(find.byType(Checkbox), findsNWidgets(3));
      expect(find.text('Suunto D5 (primary)'), findsOneWidget);
      expect(find.text('Shearwater Teric'), findsOneWidget);
      expect(find.text('Garmin Descent'), findsOneWidget);
    });
  });

  group('ComputerToggleBar - primary label', () {
    testWidgets('primary computer shows "(primary)" suffix in label', (
      tester,
    ) async {
      await tester.pumpWidget(_buildBar(computers: _twoComputers()));
      await tester.pump();

      expect(find.text('Suunto D5 (primary)'), findsOneWidget);
      // Non-primary should NOT have the suffix
      expect(find.text('Shearwater Teric (primary)'), findsNothing);
      expect(find.text('Shearwater Teric'), findsOneWidget);
    });
  });

  group('ComputerToggleBar - onToggle callback', () {
    testWidgets('tapping checkbox fires onToggle with correct computerId', (
      tester,
    ) async {
      String? toggledId;
      bool? toggledEnabled;

      await tester.pumpWidget(
        _buildBar(
          computers: _twoComputers(),
          onToggle: (id, enabled) {
            toggledId = id;
            toggledEnabled = enabled;
          },
        ),
      );
      await tester.pump();

      // Tap the second computer's checkbox (which is currently enabled,
      // so the onChanged callback passes false)
      final checkboxes = find.byType(Checkbox);
      await tester.tap(checkboxes.at(1));
      await tester.pump();

      expect(toggledId, equals('comp-2'));
      expect(toggledEnabled, equals(false));
    });

    testWidgets('tapping label area fires onToggle via GestureDetector', (
      tester,
    ) async {
      String? toggledId;
      bool? toggledEnabled;

      await tester.pumpWidget(
        _buildBar(
          computers: _twoComputers(),
          onToggle: (id, enabled) {
            toggledId = id;
            toggledEnabled = enabled;
          },
        ),
      );
      await tester.pump();

      // Tap on the text label for the first (enabled) computer
      await tester.tap(find.text('Suunto D5 (primary)'));
      await tester.pump();

      expect(toggledId, equals('comp-1'));
      // Was enabled, tapping toggles to disabled
      expect(toggledEnabled, equals(false));
    });
  });

  group('ComputerToggleBar - enabled/disabled visual state', () {
    testWidgets('enabled computer has full opacity', (tester) async {
      await tester.pumpWidget(_buildBar(computers: _twoComputers()));
      await tester.pump();

      // Both are enabled, so both Opacity widgets should be 1.0
      final opacities = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .toList();
      for (final opacity in opacities) {
        expect(opacity.opacity, equals(1.0));
      }
    });

    testWidgets('disabled computer has reduced opacity', (tester) async {
      await tester.pumpWidget(
        _buildBar(
          computers: _twoComputers(firstEnabled: true, secondEnabled: false),
        ),
      );
      await tester.pump();

      final opacities = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .toList();
      // First computer enabled -> opacity 1.0
      expect(opacities[0].opacity, equals(1.0));
      // Second computer disabled -> opacity 0.45
      expect(opacities[1].opacity, equals(0.45));
    });

    testWidgets('checkbox value reflects isEnabled state', (tester) async {
      await tester.pumpWidget(
        _buildBar(
          computers: _twoComputers(firstEnabled: true, secondEnabled: false),
        ),
      );
      await tester.pump();

      final checkboxes = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .toList();
      expect(checkboxes[0].value, isTrue);
      expect(checkboxes[1].value, isFalse);
    });
  });
}
