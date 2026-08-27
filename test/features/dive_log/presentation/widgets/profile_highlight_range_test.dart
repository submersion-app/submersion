import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/widgets/profile_highlight_range.dart';

void main() {
  ProfileHighlightRange range(int start, int end) => ProfileHighlightRange(
    startTimestamp: start,
    endTimestamp: end,
    color: Colors.teal,
  );

  group('visibleHighlightSpan', () {
    test('returns the full span when inside the window', () {
      final span = visibleHighlightSpan(
        range(60, 120),
        visibleMinX: 0,
        visibleMaxX: 300,
      );
      expect(span, (x1: 60.0, x2: 120.0));
    });

    test('clamps the left edge to the window', () {
      final span = visibleHighlightSpan(
        range(60, 120),
        visibleMinX: 90,
        visibleMaxX: 300,
      );
      expect(span, (x1: 90.0, x2: 120.0));
    });

    test('clamps the right edge to the window', () {
      final span = visibleHighlightSpan(
        range(60, 120),
        visibleMinX: 0,
        visibleMaxX: 100,
      );
      expect(span, (x1: 60.0, x2: 100.0));
    });

    test('returns null when the range is entirely outside the window', () {
      final span = visibleHighlightSpan(
        range(60, 120),
        visibleMinX: 150,
        visibleMaxX: 300,
      );
      expect(span, isNull);
    });

    test('returns null when the visible overlap has zero width', () {
      // Window touches the range at exactly one point (x = 120).
      final span = visibleHighlightSpan(
        range(60, 120),
        visibleMinX: 120,
        visibleMaxX: 300,
      );
      expect(span, isNull);
    });

    test('keeps an instant range while its timestamp is inside the window', () {
      final span = visibleHighlightSpan(
        range(90, 90),
        visibleMinX: 0,
        visibleMaxX: 300,
      );
      expect(span, (x1: 90.0, x2: 90.0));
    });

    test('drops an instant range outside the window', () {
      final span = visibleHighlightSpan(
        range(90, 90),
        visibleMinX: 100,
        visibleMaxX: 300,
      );
      expect(span, isNull);
    });
  });

  group('highlightBandSpan', () {
    test('wide range passes through unchanged', () {
      final span = highlightBandSpan(
        range(60, 120),
        visibleMinX: 0,
        visibleMaxX: 270,
        minWidthX: 10,
      );
      expect(span, (x1: 60.0, x2: 120.0));
    });

    test('narrow range inflates to minWidthX centered on its midpoint', () {
      final span = highlightBandSpan(
        range(100, 104),
        visibleMinX: 0,
        visibleMaxX: 270,
        minWidthX: 20,
      );
      expect(span, (x1: 92.0, x2: 112.0));
    });

    test('instant range inflates to minWidthX centered on the instant', () {
      final span = highlightBandSpan(
        range(90, 90),
        visibleMinX: 0,
        visibleMaxX: 270,
        minWidthX: 12,
      );
      expect(span, (x1: 84.0, x2: 96.0));
    });

    test('inflation shifts right when clamped by the window start', () {
      final span = highlightBandSpan(
        range(2, 2),
        visibleMinX: 0,
        visibleMaxX: 270,
        minWidthX: 12,
      );
      expect(span, (x1: 0.0, x2: 12.0));
    });

    test('inflation shifts left when clamped by the window end', () {
      final span = highlightBandSpan(
        range(268, 268),
        visibleMinX: 0,
        visibleMaxX: 270,
        minWidthX: 12,
      );
      expect(span, (x1: 258.0, x2: 270.0));
    });

    test('window narrower than minWidthX returns the whole window', () {
      final span = highlightBandSpan(
        range(100, 101),
        visibleMinX: 98,
        visibleMaxX: 104,
        minWidthX: 12,
      );
      expect(span, (x1: 98.0, x2: 104.0));
    });

    test('range fully outside the window returns null', () {
      final span = highlightBandSpan(
        range(400, 500),
        visibleMinX: 0,
        visibleMaxX: 270,
        minWidthX: 12,
      );
      expect(span, isNull);
    });
  });
}
