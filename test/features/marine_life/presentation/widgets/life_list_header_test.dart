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

Future<void> _pump(
  WidgetTester tester, {
  LifeListSummary? summary,
  int withoutPhoto = 0,
  ValueChanged<bool>? onFilter,
}) => tester.pumpWidget(
  testApp(
    locale: const Locale('en'),
    child: LifeListHeader(
      summary: summary ?? _summary(),
      year: 2026,
      withoutPhoto: withoutPhoto,
      noPhotoFilterOn: false,
      onNoPhotoFilter: onFilter ?? (_) {},
    ),
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

  testWidgets('hides the chip at zero', (tester) async {
    await _pump(tester);
    expect(find.byType(FilterChip), findsNothing);
  });

  testWidgets('the chip counts species without a photo and toggles', (
    tester,
  ) async {
    bool? toggled;
    await _pump(tester, withoutPhoto: 12, onFilter: (v) => toggled = v);
    expect(find.text('12 without a photo'), findsOneWidget);
    await tester.tap(find.byType(FilterChip));
    expect(toggled, isTrue);
  });
}
