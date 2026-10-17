import 'package:flutter/material.dart';

import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_card_photo.dart';

/// The leading image of an earned certification row on the course page
/// (#3383): the card's photo at plastic-card proportions, so the card can be
/// recognised at a glance.
///
/// The front photo is preferred, then the back when it is the only one; a
/// certification with no photo shows its agency abbreviation on a badge of
/// the same size, so every row lines up. The row's own text names the
/// certification, so the image is hidden from screen readers.
class CourseCertificationThumbnail extends StatelessWidget {
  final Certification certification;

  /// The agency's localized display name, abbreviated on the badge.
  final String agencyName;

  /// Thumbnail width; with [height] the ID-1 card ratio (85.6 x 54 mm).
  static const double width = 72;
  static const double height = 45;

  /// Corner radius scaled down from the e-card's to suit the small size.
  static const double radius = 6;

  const CourseCertificationThumbnail({
    super.key,
    required this.certification,
    required this.agencyName,
  });

  @override
  Widget build(BuildContext context) {
    final photo = certification.photoFront ?? certification.photoBack;
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: photo != null
            ? CertificationCardPhoto(
                bytes: photo,
                radius: radius,
                showShadow: false,
              )
            : _buildBadge(context),
      ),
    );
  }

  Widget _buildBadge(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Text(
          _abbreviate(agencyName),
          style: TextStyle(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  /// Abbreviates the agency name to at most 4 characters.
  static String _abbreviate(String displayName) {
    if (displayName.length <= 4) {
      return displayName;
    }
    return displayName.substring(0, 4);
  }
}
