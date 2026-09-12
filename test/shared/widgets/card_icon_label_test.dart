import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/card_icon_label.dart';

void main() {
  Widget host(double width, Widget child) => MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  );

  group('CardIconLabel', () {
    testWidgets('renders its icon and label', (tester) async {
      await tester.pumpWidget(
        host(300, const CardIconLabel(icon: Icons.access_time, text: 'Today')),
      );

      expect(find.byIcon(Icons.access_time), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('tints icon and label with a given color', (tester) async {
      const tint = Color(0xFF00897B);
      await tester.pumpWidget(
        host(
          300,
          const CardIconLabel(icon: Icons.timer, text: '7d 0h', color: tint),
        ),
      );

      expect(tester.widget<Icon>(find.byIcon(Icons.timer)).color, tint);
      expect(tester.widget<Text>(find.text('7d 0h')).style?.color, tint);
    });

    testWidgets('defaults to the secondary text color', (tester) async {
      await tester.pumpWidget(
        host(300, const CardIconLabel(icon: Icons.timer, text: '7d 0h')),
      );

      final scheme = Theme.of(tester.element(find.text('7d 0h'))).colorScheme;
      expect(
        tester.widget<Icon>(find.byIcon(Icons.timer)).color,
        scheme.onSurfaceVariant,
      );
    });

    testWidgets('ellipsizes a label wider than its row instead of '
        'overflowing', (tester) async {
      await tester.pumpWidget(
        host(
          80,
          const Wrap(
            children: [
              CardIconLabel(
                icon: Icons.access_time,
                text: 'Last downloaded a very long time ago',
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(
        tester.getSize(find.byType(CardIconLabel)).width,
        lessThanOrEqualTo(80),
      );
    });

    testWidgets('moves to its own line in a Wrap that cannot fit both', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          120,
          const Wrap(
            spacing: 16,
            children: [
              CardIconLabel(icon: Icons.scuba_diving, text: '1234 dives'),
              CardIconLabel(icon: Icons.access_time, text: 'Dec 28, 2025'),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.text('Dec 28, 2025')).dy,
        greaterThan(tester.getTopLeft(find.text('1234 dives')).dy),
      );
    });
  });
}
