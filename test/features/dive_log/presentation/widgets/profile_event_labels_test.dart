import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/widgets/profile_event_labels.dart';

void main() {
  const plotWidth = 300.0;
  const plotHeight = 200.0;

  EventLabelSpec spec({
    required double xPx,
    required double anchorYPx,
    double textWidth = 80,
    double textHeight = 12,
  }) => EventLabelSpec(
    xPx: xPx,
    anchorYPx: anchorYPx,
    textWidth: textWidth,
    textHeight: textHeight,
  );

  /// The pixel rect a placement produces.
  Rect rectOf(EventLabelSpec s, EventLabelPlacement p) =>
      Rect.fromLTWH(p.leftPx, p.topPx, s.textWidth, s.textHeight);

  test(
    'a lone label sits just below its depth anchor, centered on the line',
    () {
      final placements = placeEventLabels(
        [spec(xPx: 150, anchorYPx: 60)],
        plotWidth: plotWidth,
        plotHeight: plotHeight,
      );
      expect(placements, hasLength(1));
      expect(placements.first.showText, isTrue);
      expect(placements.first.topPx, 64); // anchor + default 4 px gap
      expect(placements.first.leftPx, 110); // xPx - textWidth / 2
    },
  );

  test('a label near the bottom clamps inside the plot', () {
    final placements = placeEventLabels(
      [spec(xPx: 150, anchorYPx: plotHeight - 2)],
      plotWidth: plotWidth,
      plotHeight: plotHeight,
    );
    expect(placements.first.topPx, plotHeight - 12); // plotHeight - textHeight
  });

  test('a label whose centered text would cross the right edge flips left '
      'of the line', () {
    final placements = placeEventLabels(
      [spec(xPx: 290, anchorYPx: 40)],
      plotWidth: plotWidth,
      plotHeight: plotHeight,
    );
    expect(placements.first.leftPx, 290 - 80 - 4); // xPx - textWidth - gap
  });

  test('a label wider than the space left of the line clamps inside the '
      'plot instead of underflowing', () {
    final placements = placeEventLabels(
      [spec(xPx: 295, anchorYPx: 40, textWidth: 293)],
      plotWidth: plotWidth,
      plotHeight: plotHeight,
    );
    expect(placements.first.leftPx, greaterThanOrEqualTo(0));
    expect(
      placements.first.leftPx + 293,
      lessThanOrEqualTo(plotWidth),
      reason: 'the label must stay fully inside the plot',
    );
  });

  test('a label whose centered text would cross the left edge flips right '
      'of the line', () {
    final placements = placeEventLabels(
      [spec(xPx: 10, anchorYPx: 40)],
      plotWidth: plotWidth,
      plotHeight: plotHeight,
    );
    expect(placements.first.leftPx, 10 + 4); // xPx + gap
  });

  test('overlapping labels are pushed apart vertically', () {
    final specs = [
      spec(xPx: 140, anchorYPx: 50),
      spec(xPx: 160, anchorYPx: 50),
    ];
    final placements = placeEventLabels(
      specs,
      plotWidth: plotWidth,
      plotHeight: plotHeight,
    );
    expect(placements.every((p) => p.showText), isTrue);
    final r0 = rectOf(specs[0], placements[0]);
    final r1 = rectOf(specs[1], placements[1]);
    expect(r0.overlaps(r1), isFalse);
  });

  test('a crowded column hides labels that cannot fit instead of stacking '
      'them on the profile', () {
    final specs = List.generate(
      8,
      (_) => spec(xPx: 150, anchorYPx: 90, textHeight: 30),
    );
    final placements = placeEventLabels(
      specs,
      plotWidth: plotWidth,
      plotHeight: plotHeight,
    );
    expect(placements, hasLength(8));
    expect(
      placements.where((p) => !p.showText),
      isNotEmpty,
      reason: 'a 200 px plot cannot hold 8 stacked 30 px labels',
    );
    // The shown ones still never overlap.
    final shown = [
      for (var i = 0; i < specs.length; i++)
        if (placements[i].showText) rectOf(specs[i], placements[i]),
    ];
    for (var i = 0; i < shown.length; i++) {
      for (var j = i + 1; j < shown.length; j++) {
        expect(shown[i].overlaps(shown[j]), isFalse);
      }
    }
  });

  test('labels that cannot go below the anchor are placed above it', () {
    // Anchor at the very bottom, with an existing label already occupying
    // the clamped bottom slot: the second label must land above the anchor.
    final specs = [
      spec(xPx: 150, anchorYPx: plotHeight - 2),
      spec(xPx: 152, anchorYPx: plotHeight - 2),
    ];
    final placements = placeEventLabels(
      specs,
      plotWidth: plotWidth,
      plotHeight: plotHeight,
    );
    expect(placements[1].showText, isTrue);
    expect(
      placements[1].topPx,
      lessThan(placements[0].topPx),
      reason: 'no room below the anchor, so the label must move above',
    );
    final r0 = rectOf(specs[0], placements[0]);
    final r1 = rectOf(specs[1], placements[1]);
    expect(r0.overlaps(r1), isFalse);
  });

  test('a plot shorter than the text does not throw (transient layouts)', () {
    final placements = placeEventLabels(
      [spec(xPx: 150, anchorYPx: 4, textHeight: 12)],
      plotWidth: plotWidth,
      plotHeight: 8,
    );
    expect(placements, hasLength(1));
    expect(placements.first.topPx, 0);
  });

  test('output length and order always match the input', () {
    final specs = [
      spec(xPx: 250, anchorYPx: 20),
      spec(xPx: 50, anchorYPx: 180),
      spec(xPx: 150, anchorYPx: 100),
    ];
    final placements = placeEventLabels(
      specs,
      plotWidth: plotWidth,
      plotHeight: plotHeight,
    );
    expect(placements, hasLength(3));
    // Placement i corresponds to spec i (order preserved even though the
    // algorithm scans left to right internally).
    expect(placements[0].leftPx, 250 - 40); // centered on its line
    expect(placements[1].topPx, greaterThanOrEqualTo(180));
    expect(placements[2].topPx, greaterThanOrEqualTo(100));
  });
}
