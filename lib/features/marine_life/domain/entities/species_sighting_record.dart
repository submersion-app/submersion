import 'package:equatable/equatable.dart';

/// One sighting of a species on one dive, denormalized with the dive and
/// site facts the species detail page shows in its Sightings list.
///
/// Produced by `SeenSpeciesRepository.getSightingsForSpecies`. [siteId] and
/// [siteName] are null for a dive without a site; [maxDepthMeters] is null
/// when the dive has no recorded depth.
class SpeciesSightingRecord extends Equatable {
  final String sightingId;
  final String diveId;
  final int? diveNumber;
  final DateTime diveDateTime;
  final String? siteId;
  final String? siteName;
  final double? maxDepthMeters;
  final int count;
  final String notes;

  const SpeciesSightingRecord({
    required this.sightingId,
    required this.diveId,
    this.diveNumber,
    required this.diveDateTime,
    this.siteId,
    this.siteName,
    this.maxDepthMeters,
    required this.count,
    required this.notes,
  });

  SpeciesSightingRecord copyWith({
    String? sightingId,
    String? diveId,
    int? diveNumber,
    DateTime? diveDateTime,
    String? siteId,
    String? siteName,
    double? maxDepthMeters,
    int? count,
    String? notes,
  }) {
    return SpeciesSightingRecord(
      sightingId: sightingId ?? this.sightingId,
      diveId: diveId ?? this.diveId,
      diveNumber: diveNumber ?? this.diveNumber,
      diveDateTime: diveDateTime ?? this.diveDateTime,
      siteId: siteId ?? this.siteId,
      siteName: siteName ?? this.siteName,
      maxDepthMeters: maxDepthMeters ?? this.maxDepthMeters,
      count: count ?? this.count,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [
    sightingId,
    diveId,
    diveNumber,
    diveDateTime,
    siteId,
    siteName,
    maxDepthMeters,
    count,
    notes,
  ];
}
