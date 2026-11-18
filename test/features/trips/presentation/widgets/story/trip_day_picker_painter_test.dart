import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/services/trip_picker_model.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_day_picker_painter.dart';

/// A day's tile in the trip day picker: its dives hang from the surface
/// line, as deep as they went and as wide as they were long, on scales the
/// whole trip shares.
void main() {
  TripPickerDive dive({
    required double span,
    required double depth,
    bool dashed = false,
    String id = 'd',
  }) => TripPickerDive(
    diveId: id,
    dashed: dashed,
    points: [
      const TripPickerPoint(0, 0),
      TripPickerPoint(span * 0.2, depth),
      TripPickerPoint(span * 0.8, depth),
      TripPickerPoint(span, 0),
    ],
  );

  TripPickerDay dayOf(List<TripPickerDive> dives) =>
      TripPickerDay(date: DateTime(2026, 10, 29), dives: dives);

  group('layoutTripPickerDay', () {
    test('the deepest dive of the trip reaches the bottom; a half-depth dive '
        'goes half way', () {
      final shapes = layoutTripPickerDay(
        dayOf([dive(span: 3000, depth: 40), dive(span: 3000, depth: 20)]),
        size: const Size(40, 60),
        maxDepth: 40,
        widestDaySeconds: 6000,
      );

      expect(shapes, hasLength(2));
      expect(shapes[0].bounds.bottom, closeTo(58, 0.01));
      expect(shapes[1].bounds.bottom, closeTo(31, 0.01));
      expect(shapes[0].bounds.top, closeTo(4, 0.01));
    });

    test('widths follow span on the trip scale, and the run is centred', () {
      final shapes = layoutTripPickerDay(
        dayOf([dive(span: 1500, depth: 20)]),
        size: const Size(40, 60),
        maxDepth: 40,
        widestDaySeconds: 6000,
      );

      expect(shapes.single.bounds.width, closeTo(34 * 1500 / 6000, 0.01));
      expect(shapes.single.bounds.center.dx, closeTo(20, 0.01));
    });

    test('dives run left to right in order, with a gap between them', () {
      final shapes = layoutTripPickerDay(
        dayOf([dive(span: 1000, depth: 20), dive(span: 1000, depth: 20)]),
        size: const Size(40, 60),
        maxDepth: 40,
        widestDaySeconds: 6000,
      );

      expect(
        shapes[1].bounds.left - shapes[0].bounds.right,
        closeTo(kTripPickerDiveGap, 0.01),
      );
    });

    test('eight dives in a narrow tile stay inside it', () {
      final shapes = layoutTripPickerDay(
        dayOf([for (var i = 0; i < 8; i++) dive(span: 60, depth: 10)]),
        size: const Size(38, 60),
        maxDepth: 40,
        widestDaySeconds: 20000,
      );

      expect(shapes, hasLength(8));
      expect(shapes.first.bounds.left, greaterThanOrEqualTo(3 - 0.01));
      expect(shapes.last.bounds.right, lessThanOrEqualTo(35 + 0.01));
      for (var i = 1; i < shapes.length; i++) {
        expect(
          shapes[i].bounds.left,
          greaterThanOrEqualTo(shapes[i - 1].bounds.right - 0.01),
        );
      }
    });

    test('the widest day itself fits its tile, gaps included', () {
      final shapes = layoutTripPickerDay(
        dayOf([
          dive(span: 2000, depth: 20),
          dive(span: 2000, depth: 20),
          dive(span: 2000, depth: 20),
        ]),
        size: const Size(40, 60),
        maxDepth: 40,
        widestDaySeconds: 6000,
      );

      expect(shapes.first.bounds.left, closeTo(3, 0.01));
      expect(shapes.last.bounds.right, closeTo(37, 0.01));
    });

    test('a very short dive keeps the minimum width', () {
      final shapes = layoutTripPickerDay(
        dayOf([dive(span: 1, depth: 20)]),
        size: const Size(40, 60),
        maxDepth: 40,
        widestDaySeconds: 6000,
      );

      expect(
        shapes.single.bounds.width,
        closeTo(kTripPickerMinDiveWidth, 0.01),
      );
    });

    test('zero scales lay out nothing', () {
      expect(
        layoutTripPickerDay(
          dayOf([dive(span: 60, depth: 10)]),
          size: const Size(40, 60),
          maxDepth: 0,
          widestDaySeconds: 0,
        ),
        isEmpty,
      );
    });

    test('a day with no dives lays out nothing', () {
      expect(
        layoutTripPickerDay(
          dayOf(const []),
          size: const Size(40, 60),
          maxDepth: 40,
          widestDaySeconds: 6000,
        ),
        isEmpty,
      );
    });

    test('dashed carries through', () {
      final shapes = layoutTripPickerDay(
        dayOf([
          dive(span: 1000, depth: 20),
          dive(span: 1000, depth: 20, dashed: true),
        ]),
        size: const Size(40, 60),
        maxDepth: 40,
        widestDaySeconds: 6000,
      );

      expect([for (final s in shapes) s.dashed], [false, true]);
    });
  });

  group('TripDayPickerPainter', () {
    TripDayPickerPainter painter({
      TripPickerDay? day,
      double maxDepth = 40,
      double widestDaySeconds = 6000,
      Color surfaceColor = Colors.blue,
      Color shapeColor = Colors.indigo,
      double fillOpacity = 0.5,
    }) => TripDayPickerPainter(
      day: day ?? dayOf([dive(span: 1000, depth: 20)]),
      maxDepth: maxDepth,
      widestDaySeconds: widestDaySeconds,
      surfaceColor: surfaceColor,
      shapeColor: shapeColor,
      fillOpacity: fillOpacity,
    );

    test('repaints when what it draws changes, and not otherwise', () {
      final base = painter();
      expect(painter().shouldRepaint(base), isFalse);
      expect(
        painter(day: dayOf([dive(span: 2000, depth: 20)])).shouldRepaint(base),
        isTrue,
      );
      expect(painter(maxDepth: 30).shouldRepaint(base), isTrue);
      expect(painter(widestDaySeconds: 9000).shouldRepaint(base), isTrue);
      expect(painter(shapeColor: Colors.red).shouldRepaint(base), isTrue);
      expect(painter(surfaceColor: Colors.red).shouldRepaint(base), isTrue);
      expect(painter(fillOpacity: 0.2).shouldRepaint(base), isTrue);
    });

    testWidgets('paints solid and dashed shapes without error', (tester) async {
      await tester.pumpWidget(
        Center(
          child: CustomPaint(
            size: const Size(40, 60),
            painter: painter(
              day: dayOf([
                dive(span: 1000, depth: 20),
                dive(span: 1000, depth: 35, dashed: true),
              ]),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('paints an empty day as only the surface line', (tester) async {
      await tester.pumpWidget(
        Center(
          child: CustomPaint(
            size: const Size(40, 60),
            painter: painter(day: dayOf(const []), maxDepth: 0),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
