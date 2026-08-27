import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/widgets/readout_card_placement.dart';

void main() {
  test('an empty profile keeps the historical top-right default', () {
    expect(leastOccupiedReadoutCorner(const []), const Offset(1, 0));
  });

  test('a typical dive (descent, deep bottom, ascent tail to top-right) '
      'avoids the top-right corner', () {
    // Normalized: x = time fraction, y = depth fraction (0 = surface/top).
    final profile = <Offset>[
      for (var i = 0; i <= 100; i++)
        Offset(
          i / 100,
          i < 15
              ? i /
                    15 // descent
              : i < 75
              ? 1 // deep bottom
              : (100 - i) / 25, // ascent tail rising into the top-right
        ),
    ];
    final corner = leastOccupiedReadoutCorner(profile);
    expect(
      corner,
      isNot(const Offset(1, 0)),
      reason: 'the ascent tail occupies the top-right corner window',
    );
  });

  test('an all-shallow profile hugging the top picks a bottom corner', () {
    final profile = <Offset>[
      for (var i = 0; i <= 100; i++) Offset(i / 100, 0.05),
    ];
    final corner = leastOccupiedReadoutCorner(profile);
    expect(corner.dy, 1.0, reason: 'the top edge is fully occupied');
  });

  test('points exactly on the 1.0 edges count toward the right/bottom '
      'corner windows', () {
    // A cluster parked exactly at the bottom-right edge (the last sample of
    // a dive ending at max depth normalizes to exactly (1, 1)) plus a few
    // interior points elsewhere. Exclusive edge handling would count the
    // bottom-right window as empty and park the card on the cluster.
    final profile = <Offset>[
      for (var i = 0; i < 10; i++) const Offset(1, 1),
      const Offset(0.1, 0.9),
      const Offset(0.2, 0.85),
      const Offset(0.1, 0.1),
    ];
    final corner = leastOccupiedReadoutCorner(profile);
    expect(
      corner,
      const Offset(1, 0),
      reason: 'top-right holds nothing; bottom-right holds the edge cluster',
    );
  });

  test('ties prefer top-right (the historical default)', () {
    // A single point dead center occupies no corner window.
    final corner = leastOccupiedReadoutCorner(const [Offset(0.5, 0.5)]);
    expect(corner, const Offset(1, 0));
  });
}
