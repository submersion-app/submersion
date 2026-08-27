import 'package:equatable/equatable.dart';

import 'package:submersion/features/reef/domain/entities/nearby_species.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_habitat.dart';
import 'package:submersion/features/reef/domain/entities/reef_health.dart';
import 'package:submersion/features/reef/domain/entities/reef_protection.dart';

/// The four reef-data parts for one location, each independently statused so
/// one provider outage never blanks the others.
class ReefSnapshot extends Equatable {
  final ReefPart<ReefHabitat> habitat;
  final ReefPart<ReefHealth> health;
  final ReefPart<List<ReefProtection>> protection;
  final ReefPart<NearbySpecies> species;

  const ReefSnapshot({
    required this.habitat,
    required this.health,
    required this.protection,
    required this.species,
  });

  /// True when every provider failed, which usually means the device is
  /// offline rather than that the site has no reef data.
  bool get allUnavailable =>
      habitat.status == ReefDataStatus.unavailable &&
      health.status == ReefDataStatus.unavailable &&
      protection.status == ReefDataStatus.unavailable &&
      species.status == ReefDataStatus.unavailable;

  @override
  List<Object?> get props => [habitat, health, protection, species];
}
