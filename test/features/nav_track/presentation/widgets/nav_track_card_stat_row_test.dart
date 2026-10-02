import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/nav_track/presentation/widgets/nav_track_card_stat_row.dart';

void main() {
  testWidgets('renders every stat\'s icon and text in order', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NavTrackCardStatRow(
            stats: [
              NavTrackCardStat(icon: Icons.arrow_downward, text: '38 m'),
              NavTrackCardStat(icon: Icons.timer_outlined, text: '1h 10min'),
              NavTrackCardStat(icon: Icons.straighten, text: '1.05 km'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('38 m'), findsOneWidget);
    expect(find.text('1h 10min'), findsOneWidget);
    expect(find.text('1.05 km'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    expect(find.byIcon(Icons.straighten), findsOneWidget);
  });

  testWidgets('wraps onto a second line instead of overflowing on a narrow '
      'width', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 90,
            child: NavTrackCardStatRow(
              stats: [
                NavTrackCardStat(icon: Icons.arrow_downward, text: '38 m'),
                NavTrackCardStat(icon: Icons.timer_outlined, text: '1h 10min'),
                NavTrackCardStat(icon: Icons.straighten, text: '1.05 km'),
              ],
            ),
          ),
        ),
      ),
    );

    // No overflow exception recorded for the narrow width.
    expect(tester.takeException(), isNull);
    final firstTop = tester.getTopLeft(find.text('38 m')).dy;
    final lastTop = tester.getTopLeft(find.text('1.05 km')).dy;
    expect(
      lastTop,
      greaterThan(firstTop),
      reason: 'the stats should wrap rather than overflow at 90px',
    );
  });
}
