import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/display_zoom.dart';

Widget _harness({required double zoom, required Widget child}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(
        size: Size(1000, 800),
        padding: EdgeInsets.only(top: 40),
        viewPadding: EdgeInsets.only(top: 40),
        viewInsets: EdgeInsets.only(bottom: 200),
        devicePixelRatio: 2.0,
      ),
      child: DisplayZoomScope(zoom: zoom, child: child),
    ),
  );
}

void main() {
  testWidgets('is a no-op at the default zoom', (tester) async {
    await tester.pumpWidget(
      _harness(
        zoom: DisplayZoom.defaultValue,
        child: const SizedBox(key: Key('child')),
      ),
    );

    expect(find.byKey(const Key('child')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DisplayZoomScope),
        matching: find.byType(Transform),
      ),
      findsNothing,
      reason: 'no transform layer should be added at 100%',
    );
  });

  testWidgets('divides logical size and insets by the zoom factor', (
    tester,
  ) async {
    late MediaQueryData inner;

    await tester.pumpWidget(
      _harness(
        zoom: 0.8,
        child: Builder(
          builder: (context) {
            inner = MediaQuery.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(inner.size.width, moreOrLessEquals(1250));
    expect(inner.size.height, moreOrLessEquals(1000));
    expect(inner.padding.top, moreOrLessEquals(50));
    expect(inner.viewPadding.top, moreOrLessEquals(50));
    expect(inner.viewInsets.bottom, moreOrLessEquals(250));
  });

  testWidgets('multiplies devicePixelRatio by the zoom factor', (tester) async {
    late MediaQueryData inner;

    await tester.pumpWidget(
      _harness(
        zoom: 0.8,
        child: Builder(
          builder: (context) {
            inner = MediaQuery.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(inner.devicePixelRatio, moreOrLessEquals(1.6));
  });

  // Regression: MaterialApp.builder hands its child TIGHT constraints equal to
  // the physical window. A plain SizedBox is forced to those constraints, so
  // the child was laid out at the physical size and then scaled, leaving an
  // unpainted band on the right and bottom at zoom < 1 (and overflowing at
  // zoom > 1). The child must escape the incoming constraints.
  for (final (zoom, expected) in const [
    (0.8, Size(1000, 750)),
    (1.25, Size(640, 480)),
  ]) {
    testWidgets('lays the child out at the logical size at zoom $zoom', (
      tester,
    ) async {
      const physical = Size(800, 600);
      await tester.binding.setSurfaceSize(physical);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: physical),
            child: DisplayZoomScope(
              zoom: zoom,
              child: const SizedBox.expand(key: Key('zoomed-child')),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byKey(const Key('zoomed-child'))), expected);
    });
  }

  group('defends against an unnormalized zoom', () {
    // The provider always hands over a normalized value, but this widget is
    // public. A raw 0, NaN, or negative would produce infinite or NaN logical
    // sizes and blank the UI, so it normalizes at the boundary rather than
    // trusting the call site.
    testWidgets('treats a non-finite zoom as the default', (tester) async {
      await tester.pumpWidget(
        _harness(
          zoom: double.nan,
          child: const SizedBox(key: Key('child')),
        ),
      );

      expect(find.byKey(const Key('child')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DisplayZoomScope),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
    });

    testWidgets('clamps a zero zoom up to the minimum', (tester) async {
      late MediaQueryData inner;

      await tester.pumpWidget(
        _harness(
          zoom: 0.0,
          child: Builder(
            builder: (context) {
              inner = MediaQuery.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      // 1000 / 0.7, not a division by zero.
      expect(inner.size.width, moreOrLessEquals(1000 / DisplayZoom.min));
      expect(inner.size.width.isFinite, isTrue);
    });

    testWidgets('takes the no-op path for a float-drifted 100%', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          zoom: 1.0000000000000002,
          child: const SizedBox(key: Key('child')),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(DisplayZoomScope),
          matching: find.byType(Transform),
        ),
        findsNothing,
        reason: 'a drifted 100% must still skip the transform layer',
      );
    });
  });

  testWidgets('shrinks the logical viewport when zooming in', (tester) async {
    late MediaQueryData inner;

    await tester.pumpWidget(
      _harness(
        zoom: 1.25,
        child: Builder(
          builder: (context) {
            inner = MediaQuery.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(inner.size.width, moreOrLessEquals(800));
  });
}
