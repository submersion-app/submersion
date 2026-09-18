import 'package:flutter/widgets.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The errors a coordinate entry can show, one per thing that can be wrong.
///
/// Passed in rather than looked up inside the input so the input stays
/// usable without localization delegates, as its own tests pump it.
class CoordinateValidationMessages {
  const CoordinateValidationMessages({
    required this.invalidLatitude,
    required this.invalidLongitude,
    required this.latitudeRequired,
    required this.longitudeRequired,
    required this.invalidCoordinates,
  });

  /// The localized messages for the active locale.
  factory CoordinateValidationMessages.of(BuildContext context) {
    final l10n = context.l10n;
    return CoordinateValidationMessages(
      invalidLatitude: l10n.common_coordinates_invalidLatitude,
      invalidLongitude: l10n.common_coordinates_invalidLongitude,
      latitudeRequired: l10n.common_coordinates_latitudeRequired,
      longitudeRequired: l10n.common_coordinates_longitudeRequired,
      invalidCoordinates: l10n.common_coordinates_invalid,
    );
  }

  /// Something is typed in the latitude, but it is not a latitude.
  final String invalidLatitude;

  /// Something is typed in the longitude, but it is not a longitude.
  final String invalidLongitude;

  /// The longitude is filled and the latitude is empty.
  final String latitudeRequired;

  /// The latitude is filled and the longitude is empty.
  final String longitudeRequired;

  /// A UTM or MGRS entry that is not a position. Those formats share their
  /// fields between the axes, so the error cannot name one.
  final String invalidCoordinates;
}
