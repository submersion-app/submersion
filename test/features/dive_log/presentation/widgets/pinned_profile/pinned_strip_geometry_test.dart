import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';

void main() {
  group('condenseProgress', () {
    test('is 0 with the card bottom well below the strip', () {
      expect(condenseProgress(cardBottom: 500), 0);
      expect(
        condenseProgress(cardBottom: kPinnedStripHeight + kCondenseWindow),
        0,
      );
    });

    test('is 1 once the bottom passes the strip', () {
      expect(condenseProgress(cardBottom: kPinnedStripHeight), 1);
      expect(condenseProgress(cardBottom: -10), 1);
    });

    test('is linear in the window', () {
      expect(
        condenseProgress(
          cardBottom: kPinnedStripHeight + kCondenseWindow / 2,
        ),
        closeTo(0.5, 1e-9),
      );
    });
  });

  group('condenseRect', () {
    const card = Rect.fromLTRB(16, -200, 384, 150);

    test('at t=0 is the visible part of the card', () {
      expect(
        condenseRect(card: card, width: 400, t: 0),
        const Rect.fromLTRB(16, 0, 384, 150),
      );
    });

    test('at t=1 is the full-width strip', () {
      expect(
        condenseRect(card: card, width: 400, t: 1),
        const Rect.fromLTWH(0, 0, 400, kPinnedStripHeight),
      );
    });

    test('at t=0.5 is halfway, with the top clamped to 0', () {
      final r = condenseRect(card: card, width: 400, t: 0.5);
      expect(r.left, 8);
      expect(r.top, 0);
      expect(r.right, 392);
      expect(r.bottom, closeTo((150 + kPinnedStripHeight) / 2, 1e-9));
    });
  });
}
