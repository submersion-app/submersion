import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/scenes/chart_marks_painter.dart';

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

const _spots = [
  ChartSpot(at: Offset(0.19, 0.80), halo: false),
  ChartSpot(at: Offset(0.52, 0.56)),
  ChartSpot(at: Offset(0.77, 0.26), haloDelay: -4),
];

ChartMarksPainter painter(
  double seconds, {
  List<ChartSpot> spots = _spots,
  bool course = true,
  Brightness brightness = Brightness.light,
  ValueNotifier<double>? time,
}) => ChartMarksPainter(
  time: time ?? ValueNotifier(seconds),
  brightness: brightness,
  spots: spots,
  course: course,
);

void main() {
  test('paints spots, halos and a course at every test size', () async {
    for (final size in const [
      Size(400, 400),
      Size(900, 700),
      Size(1600, 1000),
    ]) {
      for (final b in Brightness.values) {
        final bytes = await render(painter(3, brightness: b), size);
        expect(bytes.any((v) => v != 0), isTrue);
      }
    }
  });

  test('is deterministic for the same time', () async {
    const size = Size(200, 140);
    expect(await render(painter(3), size), await render(painter(3), size));
  });

  test('the halos pulse with the clock', () async {
    const size = Size(200, 140);
    expect(
      await render(painter(0, course: false), size),
      isNot(equals(await render(painter(4, course: false), size))),
    );
  });

  test('the course creeps with the clock', () async {
    const size = Size(200, 140);
    final still = [for (final s in _spots) ChartSpot(at: s.at, halo: false)];
    expect(
      await render(painter(0, spots: still), size),
      isNot(equals(await render(painter(1, spots: still), size))),
    );
  });

  test('a single spot draws no course', () async {
    const size = Size(200, 140);
    const one = [ChartSpot(at: Offset(0.5, 0.5), halo: false)];
    expect(
      await render(painter(0, spots: one), size),
      await render(painter(0, spots: one, course: false), size),
    );
  });

  test('repaints when the clock ticks, without a new painter', () {
    final time = ValueNotifier<double>(0);
    addTearDown(time.dispose);
    final p = painter(0, time: time);
    var repaints = 0;
    p.addListener(() => repaints++);

    time.value = 1;

    expect(repaints, 1);
  });

  test('shouldRepaint follows brightness, course, spots and the clock', () {
    final time = ValueNotifier<double>(0);
    addTearDown(time.dispose);
    final base = painter(0, time: time);

    expect(base.shouldRepaint(painter(0, time: time)), isFalse);
    expect(
      base.shouldRepaint(painter(0, time: time, brightness: Brightness.dark)),
      isTrue,
    );
    expect(base.shouldRepaint(painter(0, time: time, course: false)), isTrue);
    expect(
      base.shouldRepaint(painter(0, time: time, spots: _spots.sublist(1))),
      isTrue,
    );
    expect(base.shouldRepaint(painter(0)), isTrue);
  });

  test('builds the course geometry once per size, not once per frame', () {
    final time = ValueNotifier<double>(0);
    addTearDown(time.dispose);
    final p = painter(0, time: time);
    final before = ChartMarksPainter.courseGeometryBuilds;

    for (var i = 0; i < 5; i++) {
      time.value = i / 24;
      p.paint(Canvas(ui.PictureRecorder()), const Size(200, 140));
    }
    expect(ChartMarksPainter.courseGeometryBuilds - before, 1);

    p.paint(Canvas(ui.PictureRecorder()), const Size(300, 140));
    expect(ChartMarksPainter.courseGeometryBuilds - before, 2);
  });
}
