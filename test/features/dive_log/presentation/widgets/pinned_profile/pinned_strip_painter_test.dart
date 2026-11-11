import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_painter.dart';

void main() {
  const profile = [
    DiveProfilePoint(timestamp: 60, depth: 0),
    DiveProfilePoint(timestamp: 600, depth: 24),
    DiveProfilePoint(timestamp: 1260, depth: 0),
  ];
  const chart = PlotMapping(
    rect: Rect.fromLTWH(30, -80, 340, 220),
    minSeconds: 0,
    maxSeconds: 1500,
    minDepthMeters: 0,
    maxDepthMeters: 27,
  );

  PinnedStripPainter painter({PlotMapping? from, double morph = 0}) =>
      PinnedStripPainter(
        profile: profile,
        selectedSeconds: null,
        curveColor: Colors.blue,
        fillColor: Colors.blue,
        markerColor: Colors.red,
        from: from,
        morph: morph,
      );

  test('at morph 0 it draws through the chart plot mapping', () {
    final m = painter(from: chart).mappingFor(const Size(400, 300));
    for (final (s, d) in [(60, 0.0), (600, 24.0), (1260, 0.0)]) {
      expect(m.project(s, d), chart.project(s, d));
    }
  });

  test('at morph 1 it draws through its own curve area', () {
    final m = painter(
      from: chart,
      morph: 1,
    ).mappingFor(const Size(400, kPinnedStripHeight));
    expect(m.minSeconds, 60);
    expect(m.maxSeconds, 1260);
    expect(m.minDepthMeters, 0);
    expect(m.maxDepthMeters, 24);
    expect(m.rect.left, 0);
    expect(m.rect.right, 400);
    // Inside the curve area, above the 16 px values row.
    expect(m.rect.top, greaterThanOrEqualTo(0));
    expect(m.rect.bottom, lessThanOrEqualTo(kPinnedStripHeight - 16));
  });

  test('without a chart plot it draws through its own mapping', () {
    final own = painter(morph: 1).mappingFor(const Size(400, 300));
    final none = painter().mappingFor(const Size(400, 300));
    expect(none.rect, own.rect);
  });
}
