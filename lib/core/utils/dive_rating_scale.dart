/// A dive's rating is a count of 1 to 5 stars, with null for an unrated dive.
///
/// UDDF's `<ratingvalue>` runs from 1 to 10 instead, and Diving Log writes it
/// that way, with 0 for an unrated dive. Imported as it was, a 3-star dive
/// showed six stars and an unrated one a rating of 0 (issue #4415).
abstract final class DiveRatingScale {
  /// The most stars a dive can have.
  static const int maxStars = 5;

  /// The star count for a UDDF `<ratingvalue>` on the spec's 1 to 10 scale.
  ///
  /// Two points make a star, and a half star rounds up, so 1 is one star and
  /// 10 is five. 0, the value Diving Log writes for "not rated", is null, as
  /// is anything below it. A value above 10 is capped at five stars.
  static int? fromUddf(int? value) {
    if (value == null || value <= 0) return null;
    return _halve(value);
  }

  /// [value] as a star count a dive can store.
  ///
  /// A value on the 1 to 5 scale is kept. One above 5 can only have come from
  /// a 1 to 10 scale, so it is halved as [fromUddf] would; 0 and below are
  /// null. The v358 rung (`repairOutOfScaleDiveRatings`) applies the same rule
  /// in SQL to ratings imported before it, so keep the two in step.
  static int? normalize(int? value) {
    if (value == null || value <= 0) return null;
    if (value <= maxStars) return value;
    return _halve(value);
  }

  static int _halve(int value) {
    final stars = (value + 1) ~/ 2;
    return stars > maxStars ? maxStars : stars;
  }
}
