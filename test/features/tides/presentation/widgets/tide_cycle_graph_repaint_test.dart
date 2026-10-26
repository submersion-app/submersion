import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_cycle_graph.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import 'tide_record_fixture.dart';

Widget _graph({
  DepthUnit depthUnit = DepthUnit.meters,
  TimeFormat timeFormat = TimeFormat.twentyFourHour,
}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 400,
        child: TideCycleGraph(
          record: risingTideRecord,
          referenceTime: DateTime.utc(2026, 3, 28, 10),
          height: 80,
          depthUnit: depthUnit,
          timeFormat: timeFormat,
        ),
      ),
    ),
  ),
);

CustomPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find
          .descendant(
            of: find.byType(TideCycleGraph),
            matching: find.byType(CustomPaint),
          )
          .first,
    )
    .painter!;

void main() {
  // The painter draws the tide heights in the diver's unit and the times in
  // their clock format, but shouldRepaint did not compare either: changing
  // just the setting left the graph showing the old labels.
  testWidgets('a depth unit change repaints the labels', (tester) async {
    await tester.pumpWidget(_graph());
    final before = _painter(tester);

    await tester.pumpWidget(_graph(depthUnit: DepthUnit.feet));

    expect(_painter(tester).shouldRepaint(before), isTrue);
  });

  testWidgets('a clock format change repaints the labels', (tester) async {
    await tester.pumpWidget(_graph());
    final before = _painter(tester);

    await tester.pumpWidget(_graph(timeFormat: TimeFormat.twelveHour));

    expect(_painter(tester).shouldRepaint(before), isTrue);
  });
}
