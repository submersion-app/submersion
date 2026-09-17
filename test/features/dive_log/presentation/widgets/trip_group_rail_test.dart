import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/widgets/trip_group_rail.dart';

/// Rasterizes [decoration] over a [size] area and returns a pixel sampler.
///
/// The rail's whole contract is where paint lands and where it does not, which
/// a widget-tree assertion cannot see: the decoration paints behind a sliver,
/// so its geometry never reaches the element tree. Painting it for real and
/// reading pixels back is the only honest check.
///
/// Run through [WidgetTester.runAsync]: rasterizing needs the real event loop,
/// and inside the fake-async zone `Picture.toImage` never completes. The test
/// just sits there until the ten-minute timeout kills it.
///
/// [paintSize] overrides the box handed to the painter, for the degenerate
/// boxes a raster image cannot itself have.
Future<Color Function(int x, int y)> _paint(
  Decoration decoration, {
  required Size size,
  Size? paintSize,
  TextDirection textDirection = TextDirection.ltr,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  decoration.createBoxPainter().paint(
    canvas,
    Offset.zero,
    ImageConfiguration(size: paintSize ?? size, textDirection: textDirection),
  );
  final image = await recorder.endRecording().toImage(
    size.width.round(),
    size.height.round(),
  );
  final bytes = (await image.toByteData())!;
  final stride = size.width.round() * 4;

  return (int x, int y) {
    final i = y * stride + x * 4;
    return Color.fromARGB(
      bytes.getUint8(i + 3),
      bytes.getUint8(i),
      bytes.getUint8(i + 1),
      bytes.getUint8(i + 2),
    );
  };
}

void main() {
  const size = Size(200, 100);
  const rail = GutterRailDecoration(color: Color(0xFF336699));

  group('GutterRailDecoration', () {
    testWidgets('paints a 3px bar in the gutter, 6px from the leading edge', (
      tester,
    ) async {
      final at = (await tester.runAsync(() => _paint(rail, size: size)))!;

      // The bar spans x = 6.0 to 9.0, so columns 6, 7 and 8 are covered.
      expect(at(6, 50).a, 1.0);
      expect(at(7, 50), const Color(0xFF336699));
      expect(at(8, 50).a, 1.0);
      // And nothing either side of it.
      expect(at(5, 50).a, 0.0);
      expect(at(9, 50).a, 0.0);
    });

    testWidgets('mirrors to the trailing edge under RTL', (tester) async {
      final at = (await tester.runAsync(
        () => _paint(rail, size: size, textDirection: TextDirection.rtl),
      ))!;

      // 200 - 6 - 3 = 191, so columns 191, 192 and 193.
      expect(at(192, 50), const Color(0xFF336699));
      expect(at(190, 50).a, 0.0);
      expect(at(194, 50).a, 0.0);
      // The leading gutter stays clear: the rail moved, it did not multiply.
      expect(at(7, 50).a, 0.0);
    });

    testWidgets('runs the full height of the group', (tester) async {
      final at = (await tester.runAsync(() => _paint(rail, size: size)))!;

      expect(at(7, 3).a, 1.0);
      expect(at(7, 96).a, 1.0);
    });

    testWidgets('paints nothing anywhere else', (tester) async {
      final at = (await tester.runAsync(() => _paint(rail, size: size)))!;

      // No band fill behind the cards.
      expect(at(100, 50).a, 0.0);
      expect(at(199, 50).a, 0.0);
      // No rule along the top or bottom edge, which is what replaced the
      // 2px accent borders the band used to draw.
      expect(at(100, 0).a, 0.0);
      expect(at(100, 99).a, 0.0);
    });

    testWidgets('an empty area paints nothing and does not throw', (
      tester,
    ) async {
      // A collapsed sliver can hand the painter a zero-height box.
      final at = (await tester.runAsync(
        () => _paint(
          rail,
          size: const Size(200, 1),
          paintSize: const Size(200, 0),
        ),
      ))!;

      expect(at(7, 0).a, 0.0);
    });

    test('equal rails share a hash code', () {
      expect(
        const GutterRailDecoration(color: Color(0xFF336699)).hashCode,
        const GutterRailDecoration(color: Color(0xFF336699)).hashCode,
      );
    });

    test('two rails with the same colour are equal', () {
      // DecoratedSliver repaints on inequality, so a rail rebuilt with an
      // unchanged colour must not force one.
      expect(
        const GutterRailDecoration(color: Color(0xFF336699)),
        const GutterRailDecoration(color: Color(0xFF336699)),
      );
      expect(
        const GutterRailDecoration(color: Color(0xFF336699)),
        isNot(const GutterRailDecoration(color: Color(0xFF993366))),
      );
    });
  });
}
