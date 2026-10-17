import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/scenes/chart_painter.dart';

Future<Uint8List> render(CustomPainter painter, Size size) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  final image = await recorder.endRecording().toImage(
    size.width.toInt(),
    size.height.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

double luminanceAt(Uint8List rgba, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return Color.fromARGB(
    255,
    rgba[i],
    rgba[i + 1],
    rgba[i + 2],
  ).computeLuminance();
}

double contrast(double a, double b) =>
    (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);

ChartPainter painter(double seconds, [Brightness b = Brightness.light]) =>
    ChartPainter(seconds: seconds, brightness: b);

void main() {
  test('paints every test size without throwing', () async {
    for (final size in const [
      Size(400, 400),
      Size(900, 700),
      Size(1600, 1000),
    ]) {
      for (final b in Brightness.values) {
        final bytes = await render(painter(3, b), size);
        expect(bytes.length, size.width.toInt() * size.height.toInt() * 4);
      }
    }
  });

  test('is deterministic for the same seconds and brightness', () async {
    const size = Size(200, 140);
    expect(await render(painter(3), size), await render(painter(3), size));
  });

  test('moves with the clock', () async {
    const size = Size(200, 140);
    expect(
      await render(painter(3), size),
      isNot(equals(await render(painter(30), size))),
    );
  });

  test('repaints only when the clock or brightness changes', () {
    expect(painter(3).shouldRepaint(painter(3)), isFalse);
    expect(painter(3).shouldRepaint(painter(4)), isTrue);
    expect(painter(3).shouldRepaint(painter(3, Brightness.dark)), isTrue);
  });

  test('the light sheet is paper and the dark sheet is slate', () async {
    const size = Size(200, 140);
    final light = await render(painter(3), size);
    final dark = await render(painter(3, Brightness.dark), size);

    expect(luminanceAt(light, 200, 20, 130), greaterThan(0.7));
    expect(luminanceAt(dark, 200, 20, 130), lessThan(0.15));
  });

  test('the ink keeps 4.5:1 contrast in the headline band', () async {
    const size = Size(400, 400);
    for (final b in Brightness.values) {
      final ink = ChartPalette.of(b).ink.computeLuminance();
      // Every clock value a sweep could be passing the band at.
      for (final seconds in [3.0, 10.0, 17.0]) {
        final bytes = await render(painter(seconds, b), size);
        for (final (x, y) in [(30, 44), (60, 70), (52, 88), (90, 110)]) {
          expect(
            contrast(ink, luminanceAt(bytes, 400, x, y)),
            greaterThanOrEqualTo(4.5),
            reason: '$b at $seconds s, ($x, $y)',
          );
        }
      }
    }
  });
}
