import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/site_scape/presentation/size_reporter.dart';

void main() {
  Widget host(double width, List<Size> reports) => Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizeReporter(
        onChange: reports.add,
        child: SizedBox(width: width, height: 40),
      ),
    ),
  );

  testWidgets('reports the laid-out size after the first frame', (
    tester,
  ) async {
    final reports = <Size>[];
    await tester.pumpWidget(host(120, reports));

    expect(reports, [const Size(120, 40)]);
  });

  testWidgets('reports again only when the size changes', (tester) async {
    final reports = <Size>[];
    await tester.pumpWidget(host(120, reports));
    await tester.pumpWidget(host(120, reports));
    await tester.pumpWidget(host(200, reports));

    expect(reports, [const Size(120, 40), const Size(200, 40)]);
  });
}
