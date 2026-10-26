import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/nav_track/presentation/widgets/nav_track_position_row_controls.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool placeSelected,
    required List<NavTrackPositionOption> options,
    VoidCallback? onPlace,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NavTrackPositionRowControls(
          label: 'Start:',
          placeKey: 'place-key',
          placeLabel: 'Place on map',
          placeSelected: placeSelected,
          onPlace: onPlace ?? () {},
          options: options,
        ),
      ),
    ),
  );

  testWidgets(
    'the place button has no checked look when it is not the active value',
    (tester) async {
      await pump(tester, placeSelected: false, options: const []);

      expect(find.byKey(const ValueKey('place-key')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('place-key')),
          matching: find.byIcon(Icons.check),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'the place button shows a check icon when it is the active value',
    (tester) async {
      await pump(tester, placeSelected: true, options: const []);

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('place-key')),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('tapping the place button calls onPlace', (tester) async {
    var tapped = false;
    await pump(
      tester,
      placeSelected: false,
      options: const [],
      onPlace: () => tapped = true,
    );

    await tester.tap(find.byKey(const ValueKey('place-key')));
    expect(tapped, isTrue);
  });

  testWidgets('each option renders as a FilterChip reflecting its selected '
      'state', (tester) async {
    var selectedCalls = 0;
    await pump(
      tester,
      placeSelected: false,
      options: [
        NavTrackPositionOption(
          key: 'opt-a',
          label: 'Option A',
          selected: true,
          onSelected: () => selectedCalls++,
        ),
        NavTrackPositionOption(
          key: 'opt-b',
          label: 'Option B',
          selected: false,
          onSelected: () => selectedCalls++,
        ),
      ],
    );

    expect(
      tester.widget<FilterChip>(find.byKey(const ValueKey('opt-a'))).selected,
      isTrue,
    );
    expect(
      tester.widget<FilterChip>(find.byKey(const ValueKey('opt-b'))).selected,
      isFalse,
    );

    await tester.tap(find.byKey(const ValueKey('opt-b')));
    expect(selectedCalls, 1);
  });
}
