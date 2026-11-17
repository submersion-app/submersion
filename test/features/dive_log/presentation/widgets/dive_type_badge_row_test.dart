import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/widgets/dive_type_badge.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_type_badge_row.dart';

Widget _host(double width) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: const DiveTypeBadgeRow(labels: ['Wreck', 'Deep'], dense: true),
      ),
    ),
  ),
);

void main() {
  testWidgets('collapses into +N when the labels do not fit', (tester) async {
    await tester.pumpWidget(_host(40));

    expect(tester.takeException(), isNull);
    expect(find.text('+2'), findsOneWidget);
  });

  // A crowded compact dive card can leave the row less than its "+N" badge
  // needs. It then gives the line up rather than overflowing it (#4639).
  testWidgets('shows nothing when even +N does not fit', (tester) async {
    await tester.pumpWidget(_host(6));

    expect(tester.takeException(), isNull);
    expect(find.byType(DiveTypeBadge), findsNothing);
  });
}
