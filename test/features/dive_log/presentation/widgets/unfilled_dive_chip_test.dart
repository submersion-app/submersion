import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/unfilled_dive_chip.dart';

import '../../../../helpers/test_app.dart';

/// Plans and drafts are both dives waiting for their readings (issue #637),
/// marked by one chip with a look for each.
void main() {
  group('unfilledDiveStateOf', () {
    test('a logged dive has no state', () {
      expect(unfilledDiveStateOf(isPlanned: false, isDraft: false), isNull);
    });

    test('a plan is planned', () {
      expect(
        unfilledDiveStateOf(isPlanned: true, isDraft: false),
        UnfilledDiveState.planned,
      );
    });

    test('a draft waits for its download, or is in the water while open', () {
      expect(
        unfilledDiveStateOf(isPlanned: false, isDraft: true),
        UnfilledDiveState.awaitingDownload,
      );
      expect(
        unfilledDiveStateOf(isPlanned: false, isDraft: true, isOpenDraft: true),
        UnfilledDiveState.inWater,
      );
    });

    test('both flags read as the draft, which happened', () {
      expect(
        unfilledDiveStateOf(isPlanned: true, isDraft: true),
        UnfilledDiveState.awaitingDownload,
      );
    });
  });

  group('UnfilledDiveChip', () {
    Future<ColorScheme> pump(WidgetTester tester, UnfilledDiveState s) async {
      late ColorScheme scheme;
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          child: Builder(
            builder: (context) {
              scheme = Theme.of(context).colorScheme;
              return UnfilledDiveChip(state: s);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return scheme;
    }

    Color chipColor(WidgetTester tester) {
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(UnfilledDiveChip),
          matching: find.byType(Container),
        ),
      );
      return (box.decoration! as BoxDecoration).color!;
    }

    testWidgets('a plan keeps its look', (tester) async {
      final scheme = await pump(tester, UnfilledDiveState.planned);
      expect(find.text('Planned'), findsOneWidget);
      expect(chipColor(tester), scheme.tertiaryContainer);
    });

    testWidgets('a draft uses the secondary container', (tester) async {
      final scheme = await pump(tester, UnfilledDiveState.awaitingDownload);
      expect(find.text('Waiting for download'), findsOneWidget);
      expect(chipColor(tester), scheme.secondaryContainer);
    });

    testWidgets('an open draft says In the water', (tester) async {
      await pump(tester, UnfilledDiveState.inWater);
      expect(find.text('In the water'), findsOneWidget);
    });
  });

  test('a plan wears the calendar icon, a draft the hourglass', () {
    expect(
      unfilledDiveIcon(UnfilledDiveState.planned),
      Icons.event_available_outlined,
    );
    expect(
      unfilledDiveIcon(UnfilledDiveState.awaitingDownload),
      Icons.hourglass_top_outlined,
    );
    expect(
      unfilledDiveIcon(UnfilledDiveState.inWater),
      Icons.hourglass_top_outlined,
    );
  });
}
