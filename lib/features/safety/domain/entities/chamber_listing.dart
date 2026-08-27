import 'package:equatable/equatable.dart';

import 'package:submersion/features/safety/domain/entities/emergency_info.dart';

/// A chamber paired with how far it is from the diver's last known dive site.
///
/// Distance lives here rather than on [EmergencyChamber] because a chamber has
/// no business knowing where the diver is: the same chamber is 20 km away on
/// one dive and 8,000 km away on the next.
class ChamberListing extends Equatable {
  final EmergencyChamber chamber;

  /// Null when the diver's position is unknown or the chamber has no
  /// coordinates.
  final double? distanceMeters;

  const ChamberListing({required this.chamber, this.distanceMeters});

  @override
  List<Object?> get props => [chamber, distanceMeters];
}
