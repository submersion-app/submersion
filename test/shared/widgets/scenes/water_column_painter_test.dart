import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/scenes/water_column_painter.dart';

Future<Uint8List> render(WaterColumnPainter painter, Size size) async {
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

WaterColumnPainter painter(double seconds, [Brightness b = Brightness.dark]) =>
    WaterColumnPainter(seconds: seconds, brightness: b);

void main() {
  test('paints every test size without throwing', () async {
    for (final size in const [
      Size(400, 400),
      Size(900, 700),
      Size(1600, 1000),
    ]) {
      final bytes = await render(painter(3), size);
      expect(bytes.length, size.width.toInt() * size.height.toInt() * 4);
    }
  });

  test('is deterministic for the same seconds, brightness and seed', () async {
    const size = Size(200, 140);
    expect(await render(painter(3), size), await render(painter(3), size));
  });

  test('moves with the clock', () async {
    const size = Size(200, 140);
    expect(
      await render(painter(3), size),
      isNot(equals(await render(painter(9), size))),
    );
  });

  test('repaints only when the clock or brightness changes', () {
    expect(painter(3).shouldRepaint(painter(3)), isFalse);
    expect(painter(3).shouldRepaint(painter(4)), isTrue);
    expect(painter(3).shouldRepaint(painter(3, Brightness.light)), isTrue);
  });

  test(
    'the light palette is brighter than the dark one at the surface',
    () async {
      const size = Size(200, 140);
      final light = await render(painter(3, Brightness.light), size);
      final dark = await render(painter(3), size);
      expect(
        luminanceAt(light, 200, 10, 40),
        greaterThan(luminanceAt(dark, 200, 10, 40)),
      );
    },
  );
}
