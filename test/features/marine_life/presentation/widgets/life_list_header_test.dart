import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/domain/life_list_summary.dart';
import 'package:submersion/features/marine_life/presentation/widgets/life_list_header.dart';

import '../../../../helpers/test_app.dart';

LifeListSummary _summary({int points = 3}) => LifeListSummary(
  total: 142,
  newThisYear: 18,
  growth: [
    for (var i = 0; i < points; i++)
      (date: DateTime.utc(2024, 1 + i), cumulative: (i + 1) * 10),
  ],
);

Future<void> _pump(WidgetTester tester, {LifeListSummary? summary}) =>
    tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: LifeListHeader(summary: summary ?? _summary(), year: 2026),
      ),
    );

void main() {
  testWidgets('shows total, new this year and the growth line', (tester) async {
    await _pump(tester);
    expect(find.text('142'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('New in 2026'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('one first-seen day draws no growth line', (tester) async {
    await _pump(tester, summary: _summary(points: 1));
    expect(find.byType(LineChart), findsNothing);
  });
}
