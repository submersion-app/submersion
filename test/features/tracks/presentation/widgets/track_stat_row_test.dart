import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tracks/presentation/widgets/track_stat_row.dart';

import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('renders each stat in order', (tester) async {
    await tester.pumpWidget(
      testApp(
        child: const TrackStatRow(
          stats: [
            TrackStat(icon: Icons.straighten, text: '3148 m'),
            TrackStat(icon: Icons.arrow_downward, text: '138,4 m'),
            TrackStat(icon: Icons.schedule, text: '3h 4min'),
          ],
        ),
      ),
    );
    expect(find.text('3148 m'), findsOneWidget);
    expect(find.text('138,4 m'), findsOneWidget);
    expect(find.text('3h 4min'), findsOneWidget);
    expect(find.byIcon(Icons.straighten), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsOneWidget);
  });

  testWidgets('renders nothing for an empty stat list', (tester) async {
    await tester.pumpWidget(testApp(child: const TrackStatRow(stats: [])));
    expect(find.byType(SizedBox), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('wraps instead of overflowing at phone width', (tester) async {
    await tester.pumpWidget(
      testApp(
        child: const SizedBox(
          width: 160,
          child: TrackStatRow(
            stats: [
              TrackStat(icon: Icons.straighten, text: '3148 m'),
              TrackStat(icon: Icons.arrow_downward, text: '138,4 m'),
              TrackStat(icon: Icons.schedule, text: '3h 4min'),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(Wrap), findsOneWidget);
  });
}
