import 'package:equatable/equatable.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// The richest breathing gas across a dive's tanks, poorest first.
enum DiveScrubberGas {
  air,
  nitrox,
  trimix;

  /// From the highest O2 and helium percentages across the tanks, classed by
  /// [GasMix] like the profile chart. Null when the dive has no tank.
  ///
  /// The scrubber has no oxygen class: pure oxygen counts as nitrox, the
  /// richest class without helium.
  static DiveScrubberGas? of({double? maxO2, double? maxHe}) {
    if (maxO2 == null && maxHe == null) return null;
    final mix = GasMix(o2: maxO2 ?? 0, he: maxHe ?? 0);
    if (mix.isTrimix) return trimix;
    if (mix.isOxygen || mix.isNitrox) return nitrox;
    return air;
  }
}

/// One dive in the scrubber index: just what the scrubber's value and
/// markers read, in list order.
class DiveScrubberEntry extends Equatable {
  const DiveScrubberEntry({
    required this.id,
    required this.sortTimestamp,
    this.tripId,
    this.tripName,
    this.diveNumber,
    this.siteName,
    this.maxDepth,
    this.bottomTime,
    this.rating,
    this.isFavorite = false,
    this.gas,
  });

  final String id;
  final String? tripId;
  final String? tripName;

  /// Entry time, or dive time when there is none, as a wall clock in epoch
  /// milliseconds flagged UTC, like `DiveSummary.sortTimestamp`.
  final int sortTimestamp;
  final int? diveNumber;
  final String? siteName;
  final double? maxDepth;
  final Duration? bottomTime;
  final int? rating;
  final bool isFavorite;

  /// Null when the dive has no tank.
  final DiveScrubberGas? gas;

  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(sortTimestamp, isUtc: true);

  DiveScrubberEntry copyWith({
    String? id,
    int? sortTimestamp,
    String? tripId,
    String? tripName,
    int? diveNumber,
    String? siteName,
    double? maxDepth,
    Duration? bottomTime,
    int? rating,
    bool? isFavorite,
    DiveScrubberGas? gas,
  }) => DiveScrubberEntry(
    id: id ?? this.id,
    sortTimestamp: sortTimestamp ?? this.sortTimestamp,
    tripId: tripId ?? this.tripId,
    tripName: tripName ?? this.tripName,
    diveNumber: diveNumber ?? this.diveNumber,
    siteName: siteName ?? this.siteName,
    maxDepth: maxDepth ?? this.maxDepth,
    bottomTime: bottomTime ?? this.bottomTime,
    rating: rating ?? this.rating,
    isFavorite: isFavorite ?? this.isFavorite,
    gas: gas ?? this.gas,
  );

  @override
  List<Object?> get props => [
    id,
    tripId,
    tripName,
    sortTimestamp,
    diveNumber,
    siteName,
    maxDepth,
    bottomTime,
    rating,
    isFavorite,
    gas,
  ];
}
