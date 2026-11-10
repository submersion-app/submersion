import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/dive_rating_scale.dart';

/// A dive's rating is 1 to 5 stars. UDDF's `<ratingvalue>` is 1 to 10, which
/// Diving Log writes as the spec says, so a 3-star dive arrived as 6 and an
/// unrated one as 0 (issue #4415).
void main() {
  group('fromUddf', () {
    test('halves the 1 to 10 scale, rounding a half star up', () {
      expect(
        [for (var v = 1; v <= 10; v++) DiveRatingScale.fromUddf(v)],
        [1, 1, 2, 2, 3, 3, 4, 4, 5, 5],
      );
    });

    test('reads 0, a negative value and null as unrated', () {
      expect(DiveRatingScale.fromUddf(0), isNull);
      expect(DiveRatingScale.fromUddf(-2), isNull);
      expect(DiveRatingScale.fromUddf(null), isNull);
    });

    test('caps a value above the scale at 5 stars', () {
      expect(DiveRatingScale.fromUddf(14), 5);
    });
  });

  group('normalize', () {
    test('keeps a star count already on the 1 to 5 scale', () {
      expect(
        [for (var v = 1; v <= 5; v++) DiveRatingScale.normalize(v)],
        [1, 2, 3, 4, 5],
      );
    });

    test('reads 0, a negative value and null as unrated', () {
      expect(DiveRatingScale.normalize(0), isNull);
      expect(DiveRatingScale.normalize(-1), isNull);
      expect(DiveRatingScale.normalize(null), isNull);
    });

    test('halves a value above 5, which only the 1 to 10 scale writes', () {
      expect(
        [for (var v = 6; v <= 10; v++) DiveRatingScale.normalize(v)],
        [3, 4, 4, 5, 5],
      );
      expect(DiveRatingScale.normalize(40), 5);
    });
  });
}
