import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/ascent_rate_calculator.dart';
import 'package:submersion/features/dive_log/presentation/widgets/ascent_rate_bar_overlay.dart';

AscentRatePoint _point(int timestamp, double rate) => AscentRatePoint(
  timestamp: timestamp,
  depth: 10,
  rateMetersPerMin: rate,
  category: AscentRateCategory.fromRate(rate),
);

const _insets = (left: 0.0, top: 0.0, right: 0.0, bottom: 0.0);

Widget _harness({
  required List<AscentRatePoint> ascentRates,
  double visibleMinSeconds = 0,
  double visibleMaxSeconds = 100,
  double maxAbsRateMetersPerMin = 18,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 300,
        child: AscentRateBarOverlay(
          ascentRates: ascentRates,
          visibleMinSeconds: visibleMinSeconds,
          visibleMaxSeconds: visibleMaxSeconds,
          insets: _insets,
          maxAbsRateMetersPerMin: maxAbsRateMetersPerMin,
        ),
      ),
    ),
  );
}

/// Whether the overlay actually painted (a [CustomPaint] with a non-null
/// painter), rather than falling back to its empty [SizedBox.shrink]. The
/// widget always occupies the space its parent gives it (a [LayoutBuilder]
/// fills tight constraints regardless of its child), so checking the
/// overlay's own size cannot tell "drew nothing" from "drew something".
bool _painted(WidgetTester tester) => find
    .descendant(
      of: find.byType(AscentRateBarOverlay),
      matching: find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter != null,
      ),
    )
    .evaluate()
    .isNotEmpty;

void main() {
  testWidgets('renders a CustomPaint layer when rates are present', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(ascentRates: [_point(0, 0), _point(10, -9), _point(20, 12)]),
    );

    expect(find.byType(AscentRateBarOverlay), findsOneWidget);
    expect(_painted(tester), isTrue);
  });

  testWidgets('renders nothing for an empty rate list', (tester) async {
    await tester.pumpWidget(_harness(ascentRates: const []));

    expect(_painted(tester), isFalse);
  });

  testWidgets('renders nothing when the visible window has no span', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        ascentRates: [_point(0, 5)],
        visibleMinSeconds: 50,
        visibleMaxSeconds: 50,
      ),
    );

    expect(_painted(tester), isFalse);
  });

  testWidgets('renders nothing when the saturation range is zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(ascentRates: [_point(0, 5)], maxAbsRateMetersPerMin: 0),
    );

    expect(_painted(tester), isFalse);
  });

  testWidgets(
    'does not throw when every sample is outside the visible window',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          ascentRates: [_point(500, 9), _point(600, -9)],
          visibleMinSeconds: 0,
          visibleMaxSeconds: 100,
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'clamps the final bar to the plot width instead of bleeding into the '
    'axis gutter (a sample at exactly visibleMaxSeconds floors into a '
    'bucket whose own +1 edge overshoots the real pixel width)',
    (tester) async {
      // plotWidth 400 / _pixelsPerBar 3.0 = 133.33: the last bucket's own
      // +1 edge (134 * 3.0 = 402) lands 2px past the plot's right edge.
      await tester.pumpWidget(
        _harness(
          ascentRates: [_point(100, 5)],
          visibleMinSeconds: 0,
          visibleMaxSeconds: 100,
          maxAbsRateMetersPerMin: 10,
        ),
      );

      expect(
        find.byType(AscentRateBarOverlay),
        paints..rect(rect: const Rect.fromLTRB(399, 75, 400, 150)),
      );
    },
  );
}
