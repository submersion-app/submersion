import 'package:equatable/equatable.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample_point.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_summary.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// One packed profile series: the identity columns of a
/// `dive_profile_series` row, its summary scalars, and its decoded samples.
class ProfileSeries extends Equatable {
  const ProfileSeries({
    required this.id,
    required this.diveId,
    this.computerId,
    this.sourceId,
    required this.isPrimary,
    required this.summary,
    required this.samples,
    required this.codecVersion,
    required this.createdAt,
    required this.updatedAt,
    this.hlc,
  });

  final String id;
  final String diveId;
  final String? computerId;
  final String? sourceId;
  final bool isPrimary;
  final ProfileSeriesSummary summary;
  final List<ProfileSample> samples;
  final int codecVersion;
  final int createdAt;
  final int updatedAt;
  final String? hlc;

  /// The samples as the chart and analysis pipeline consume them.
  List<DiveProfilePoint> get points => [
    for (final sample in samples) sample.toPoint(),
  ];

  ProfileSeries copyWith({
    String? id,
    String? diveId,
    String? computerId,
    bool clearComputerId = false,
    String? sourceId,
    bool clearSourceId = false,
    bool? isPrimary,
    ProfileSeriesSummary? summary,
    List<ProfileSample>? samples,
    int? codecVersion,
    int? createdAt,
    int? updatedAt,
    String? hlc,
    bool clearHlc = false,
  }) {
    return ProfileSeries(
      id: id ?? this.id,
      diveId: diveId ?? this.diveId,
      computerId: clearComputerId ? null : (computerId ?? this.computerId),
      sourceId: clearSourceId ? null : (sourceId ?? this.sourceId),
      isPrimary: isPrimary ?? this.isPrimary,
      summary: summary ?? this.summary,
      samples: samples ?? this.samples,
      codecVersion: codecVersion ?? this.codecVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hlc: clearHlc ? null : (hlc ?? this.hlc),
    );
  }

  @override
  List<Object?> get props => [
    id,
    diveId,
    computerId,
    sourceId,
    isPrimary,
    summary,
    samples,
    codecVersion,
    createdAt,
    updatedAt,
    hlc,
  ];
}

/// One packed tank pressure series: a `tank_pressure_series` row decoded.
///
/// Not the Drift table class of the same name (lib/core/database/
/// database.dart); consumers that need both import this one as domain.
class TankPressureSeries extends Equatable {
  const TankPressureSeries({
    required this.id,
    required this.diveId,
    required this.tankId,
    this.computerId,
    required this.summary,
    required this.samples,
    required this.codecVersion,
    required this.createdAt,
    required this.updatedAt,
    this.hlc,
  });

  final String id;
  final String diveId;
  final String tankId;
  final String? computerId;
  final TankPressureSeriesSummary summary;
  final List<TankPressureSample> samples;
  final int codecVersion;
  final int createdAt;
  final int updatedAt;
  final String? hlc;

  TankPressureSeries copyWith({
    String? id,
    String? diveId,
    String? tankId,
    String? computerId,
    bool clearComputerId = false,
    TankPressureSeriesSummary? summary,
    List<TankPressureSample>? samples,
    int? codecVersion,
    int? createdAt,
    int? updatedAt,
    String? hlc,
    bool clearHlc = false,
  }) {
    return TankPressureSeries(
      id: id ?? this.id,
      diveId: diveId ?? this.diveId,
      tankId: tankId ?? this.tankId,
      computerId: clearComputerId ? null : (computerId ?? this.computerId),
      summary: summary ?? this.summary,
      samples: samples ?? this.samples,
      codecVersion: codecVersion ?? this.codecVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hlc: clearHlc ? null : (hlc ?? this.hlc),
    );
  }

  @override
  List<Object?> get props => [
    id,
    diveId,
    tankId,
    computerId,
    summary,
    samples,
    codecVersion,
    createdAt,
    updatedAt,
    hlc,
  ];
}
