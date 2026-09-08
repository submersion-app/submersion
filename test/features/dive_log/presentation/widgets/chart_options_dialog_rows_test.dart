import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/chart_options_dialog_rows.dart';

/// Row builders read [BuildContext] only for [Theme.of]/l10n, both available
/// anywhere under the pumped [MaterialApp]; [Builder] hands each test a real
/// context to build the widget under test with.
Widget _wrap(Widget Function(BuildContext context) builder) => MaterialApp(
  home: Scaffold(body: Builder(builder: (context) => builder(context))),
);

void main() {
  group('buildToggleItem', () {
    testWidgets('draws a checkbox with no ring when sourceColor is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          (context) => buildToggleItem(
            context,
            label: 'Depth',
            color: Colors.blue,
            isEnabled: true,
            onTap: () {},
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(InkWell),
          matching: find.byType(Container),
        ),
        findsNothing,
      );
      final icon = tester.widget<Icon>(find.byIcon(Icons.check_box));
      expect(icon.color, Colors.blue);
    });

    testWidgets('draws the source colour as a border around the checkbox '
        'when sourceColor is given', (tester) async {
      await tester.pumpWidget(
        _wrap(
          (context) => buildToggleItem(
            context,
            label: 'Depth',
            color: Colors.blue,
            isEnabled: true,
            onTap: () {},
            sourceColor: Colors.red,
          ),
        ),
      );

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(InkWell),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;
      final border = decoration.border! as Border;
      expect(border.top.color, Colors.red);
      expect(border.top.width, 1);
    });

    testWidgets('dims the label when disabled, plain text when enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          (context) => Column(
            children: [
              buildToggleItem(
                context,
                label: 'Enabled row',
                color: Colors.blue,
                isEnabled: true,
                onTap: () {},
              ),
              buildToggleItem(
                context,
                label: 'Disabled row',
                color: Colors.blue,
                isEnabled: false,
                onTap: () {},
              ),
            ],
          ),
        ),
      );

      final enabledText = tester.widget<Text>(find.text('Enabled row'));
      expect(enabledText.style, isNull);

      final disabledText = tester.widget<Text>(find.text('Disabled row'));
      expect(disabledText.style, isNotNull);
      expect(
        disabledText.style!.color,
        Theme.of(
          tester.element(find.text('Disabled row')),
        ).colorScheme.onSurfaceVariant,
      );
    });

    testWidgets('is announced as a checkbox with the enabled state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          (context) => buildToggleItem(
            context,
            label: 'Depth',
            color: Colors.blue,
            isEnabled: true,
            onTap: () {},
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(InkWell));
      expect(semantics.flagsCollection.isChecked, CheckedState.isTrue);
    });

    testWidgets('tapping the row invokes onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          (context) => buildToggleItem(
            context,
            label: 'Depth',
            color: Colors.blue,
            isEnabled: true,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });
  });

  group('buildToggleWithSource', () {
    testWidgets('dims the label when disabled', (tester) async {
      await tester.pumpWidget(
        _wrap(
          (context) => buildToggleWithSource<int>(
            context,
            label: 'Ceiling',
            color: Colors.blue,
            isEnabled: false,
            onTap: () {},
            currentSource: 0,
            onSourceChanged: (_) {},
            segments: const [(0, 'DC'), (1, 'Calc')],
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Ceiling'));
      expect(text.style, isNotNull);
    });

    testWidgets('shows a checkbox reflecting the enabled state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          (context) => buildToggleWithSource<int>(
            context,
            label: 'Deco stops',
            color: Colors.blue,
            isEnabled: true,
            onTap: () {},
            currentSource: 0,
            onSourceChanged: (_) {},
            segments: const [(0, 'DC'), (1, 'Calc')],
          ),
        ),
      );

      expect(find.text('Deco stops'), findsOneWidget);
      expect(find.byType(SegmentedButton<int>), findsOneWidget);
      expect(find.byIcon(Icons.check_box), findsOneWidget);
    });

    testWidgets('is announced as a checkbox with the enabled state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          (context) => buildToggleWithSource<int>(
            context,
            label: 'Deco stops',
            color: Colors.blue,
            isEnabled: true,
            onTap: () {},
            currentSource: 0,
            onSourceChanged: (_) {},
            segments: const [(0, 'DC'), (1, 'Calc')],
          ),
        ),
      );

      // The SegmentedButton has InkWells of its own; the row's is outermost.
      final semantics = tester.getSemantics(find.byType(InkWell).first);
      expect(semantics.flagsCollection.isChecked, CheckedState.isTrue);
    });
  });

  group('buildGasToggleItem', () {
    testWidgets('dims the label when disabled', (tester) async {
      await tester.pumpWidget(
        _wrap(
          (context) => buildGasToggleItem(
            context,
            label: 'Gas timeline',
            isEnabled: false,
            onTap: () {},
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Gas timeline'));
      expect(text.style, isNotNull);
    });

    testWidgets('shows no dimmed style when enabled', (tester) async {
      await tester.pumpWidget(
        _wrap(
          (context) => buildGasToggleItem(
            context,
            label: 'Gas timeline',
            isEnabled: true,
            onTap: () {},
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Gas timeline'));
      expect(text.style, isNull);
    });
  });

  group('buildBehaviorItem', () {
    testWidgets('colors the label with the primary colour when enabled, '
        'onSurfaceVariant when disabled', (tester) async {
      await tester.pumpWidget(
        _wrap(
          (context) => Column(
            children: [
              buildBehaviorItem(
                context,
                label: 'On',
                isEnabled: true,
                onTap: () {},
              ),
              buildBehaviorItem(
                context,
                label: 'Off',
                isEnabled: false,
                onTap: () {},
              ),
            ],
          ),
        ),
      );

      final onText = tester.widget<Text>(find.text('On'));
      final offText = tester.widget<Text>(find.text('Off'));
      final colorScheme = Theme.of(tester.element(find.text('On'))).colorScheme;
      expect(onText.style!.color, colorScheme.primary);
      expect(offText.style!.color, colorScheme.onSurfaceVariant);
    });

    testWidgets('is announced as a checkbox with the enabled state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          (context) => buildBehaviorItem(
            context,
            label: 'Snap to sample',
            isEnabled: true,
            onTap: () {},
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(InkWell));
      expect(semantics.flagsCollection.isChecked, CheckedState.isTrue);
    });
  });
}
