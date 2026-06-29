import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail_row.dart';

/// Pumps a single [DiveDetailRow] inside a deliberately narrow viewport so a
/// long value is forced to compete with the label for horizontal space. This
/// reproduces issue #434 (Galaxy S24 Ultra): a long "Dive Type" / weather
/// "Description" value jammed against its label and ran off the right edge.
Future<void> _pumpRow(
  WidgetTester tester, {
  required String label,
  required String value,
  String? sourceName,
  double width = 250,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: DiveDetailRow(
              label: label,
              value: value,
              sourceName: sourceName,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('DiveDetailRow', () {
    testWidgets('a long value wraps instead of overflowing a narrow row', (
      tester,
    ) async {
      await _pumpRow(
        tester,
        label: 'Dive Type',
        value: 'Recreational, Shore, Photography',
      );

      // The buggy layout (no Flexible around the value) emits a RenderFlex
      // "overflowed" error here; the fixed layout must lay out cleanly.
      expect(
        tester.takeException(),
        isNull,
        reason: 'a long value must wrap within the row, not overflow it',
      );

      // The whole value must remain on screen, not be truncated away.
      expect(find.text('Recreational, Shore, Photography'), findsOneWidget);
      expect(find.text('Dive Type'), findsOneWidget);
    });

    testWidgets('a long free-form description does not overflow', (
      tester,
    ) async {
      await _pumpRow(
        tester,
        label: 'Description',
        value: 'Overcast, 27C, moderate breeze from the east, choppy surface',
      );

      expect(
        tester.takeException(),
        isNull,
        reason: 'a long weather description must wrap, not run off the edge',
      );
    });

    testWidgets(
      'a short value stays at the trailing edge, clear of the label',
      (tester) async {
        await _pumpRow(tester, label: 'Avg Depth', value: '22.3ft', width: 300);

        expect(tester.takeException(), isNull);

        // Value hugs the trailing edge of the row (no horizontal padding).
        final rowRight = tester.getTopRight(find.byType(DiveDetailRow)).dx;
        final valueRight = tester.getTopRight(find.text('22.3ft')).dx;
        expect((rowRight - valueRight).abs(), lessThan(1.0));

        // ...and is plainly separated from the label, not jammed against it.
        final labelRight = tester.getTopRight(find.text('Avg Depth')).dx;
        final valueLeft = tester.getTopLeft(find.text('22.3ft')).dx;
        expect(valueLeft - labelRight, greaterThan(16.0));
      },
    );

    testWidgets('shows an attribution badge after the value when provided', (
      tester,
    ) async {
      await _pumpRow(
        tester,
        label: 'Avg Depth',
        value: '22.3ft',
        sourceName: 'Perdix',
        width: 300,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('22.3ft'), findsOneWidget);
      expect(find.text('Perdix'), findsOneWidget);
    });
  });
}
