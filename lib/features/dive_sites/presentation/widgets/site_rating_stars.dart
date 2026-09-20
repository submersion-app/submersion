import 'package:flutter/material.dart';

/// The five stars a site's rating reads as.
///
/// A star is filled for any part of it, so an imported 4.4 fills five. Both
/// the header summary and the Rating card render through here so the two
/// can never disagree about the same value.
///
/// Lays out as a [Wrap] rather than a [Row]: five fixed-size icons plus
/// whatever sits beside them have no give, and a star dropping to a second
/// line reads better than an overflow stripe.
class SiteRatingStars extends StatelessWidget {
  const SiteRatingStars({
    super.key,
    required this.rating,
    required this.size,
    required this.color,
    this.spacing = 0,
  });

  /// 0 to 5. Zero fills nothing, which is how an unrated site reads.
  final double rating;

  final double size;

  final Color color;

  /// Gap between two stars.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var index = 0; index < 5; index++)
          Icon(
            index < rating ? Icons.star : Icons.star_border,
            size: size,
            color: color,
          ),
      ],
    );
  }
}
