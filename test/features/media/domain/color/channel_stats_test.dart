import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/color/channel_stats.dart';

Uint8List solid(int r, int g, int b, {int n = 100}) => Uint8List.fromList([
  for (var i = 0; i < n; i++) ...[r, g, b, 255],
]);

void main() {
  test('means of a solid blue-green image', () {
    final s = ChannelStats.fromRgba(solid(26, 102, 153))!;
    expect(s.meanR, closeTo(26 / 255, 1e-9));
    expect(s.meanG, closeTo(102 / 255, 1e-9));
    expect(s.meanB, closeTo(153 / 255, 1e-9));
    expect(s.looksUnderwater, isTrue);
  });

  test('all-black and all-clipped images give null', () {
    expect(ChannelStats.fromRgba(solid(2, 2, 2)), isNull);
    expect(ChannelStats.fromRgba(solid(255, 255, 255)), isNull);
  });

  test('an empty buffer gives null', () {
    expect(ChannelStats.fromRgba(Uint8List(0)), isNull);
  });

  test('black and clipped pixels are left out of the means', () {
    final rgba = Uint8List.fromList([
      ...solid(0, 0, 0, n: 50),
      ...solid(255, 255, 255, n: 10),
      ...solid(40, 100, 160, n: 40),
    ]);
    final s = ChannelStats.fromRgba(rgba)!;
    expect(s.meanR, closeTo(40 / 255, 1e-9));
  });

  test('fewer than 5% usable pixels gives null', () {
    final rgba = Uint8List.fromList([
      ...solid(0, 0, 0, n: 97),
      ...solid(40, 100, 160, n: 3),
    ]);
    expect(ChannelStats.fromRgba(rgba), isNull);
  });

  test('a warm beach photo does not look underwater', () {
    expect(
      ChannelStats.fromRgba(solid(200, 170, 120))!.looksUnderwater,
      isFalse,
    );
  });

  test('a very dark blue frame does not look underwater', () {
    // Blue-dominant but below the 0.15 brightness floor.
    expect(ChannelStats.fromRgba(solid(12, 20, 30))!.looksUnderwater, isFalse);
  });

  test('stride samples every nth pixel', () {
    final rgba = Uint8List.fromList([
      ...solid(40, 100, 160, n: 1),
      ...solid(200, 100, 160, n: 1),
    ]);
    expect(
      ChannelStats.fromRgba(rgba, stride: 2)!.meanR,
      closeTo(40 / 255, 1e-9),
    );
  });
}
