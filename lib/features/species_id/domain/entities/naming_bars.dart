import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'package:submersion/features/species_id/domain/entities/naming_level.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';

/// The bars a pack named a run's media at, kept on the run (issue #4876):
/// what working out a naming level needs, so a device with no pack, or a
/// different one, names the run's rows at the diver's chosen level exactly
/// as the device that analysed it does.
class NamingBars extends Equatable {
  const NamingBars({
    required this.minCropSide,
    required this.minOpenScore,
    required this.suggestScore,
    required this.suggestScoreNoLocation,
    this.levels = const [],
  });

  factory NamingBars.fromNaming(NamingConfig naming) => NamingBars(
    minCropSide: naming.minCropSide,
    minOpenScore: naming.minOpenScore,
    suggestScore: naming.suggestScore,
    suggestScoreNoLocation: naming.suggestScoreNoLocation,
    levels: naming.levels,
  );

  final int minCropSide;
  final double minOpenScore;
  final double suggestScore;
  final double suggestScoreNoLocation;

  /// The measured levels below the suggest bars, surest first.
  final List<MeasuredNamingLevel> levels;

  NamingBars copyWith({
    int? minCropSide,
    double? minOpenScore,
    double? suggestScore,
    double? suggestScoreNoLocation,
    List<MeasuredNamingLevel>? levels,
  }) => NamingBars(
    minCropSide: minCropSide ?? this.minCropSide,
    minOpenScore: minOpenScore ?? this.minOpenScore,
    suggestScore: suggestScore ?? this.suggestScore,
    suggestScoreNoLocation:
        suggestScoreNoLocation ?? this.suggestScoreNoLocation,
    levels: levels ?? this.levels,
  );

  /// As stored on the run: the manifest's own field names, so the levels
  /// read back through the same checks as a manifest's ([measuredLevels]).
  String toJson() => jsonEncode({
    'minCropSide': minCropSide,
    'minOpenScore': minOpenScore,
    'suggestScore': suggestScore,
    'suggestScoreNoLocation': suggestScoreNoLocation,
    'levels': [
      for (final l in levels)
        {
          'id': l.level.id,
          'target': l.target,
          'suggestScore': l.suggestScore,
          'suggestScoreNoLocation': l.suggestScoreNoLocation,
          'precision': l.precision,
        },
    ],
  });

  /// [json] as stored, or null when there is none or it does not read: the
  /// run's rows then show as stored.
  static NamingBars? fromJson(String? json) {
    if (json == null) return null;
    try {
      final map = jsonDecode(json);
      if (map is! Map) return null;
      final side = map['minCropSide'];
      final open = map['minOpenScore'];
      final suggest = map['suggestScore'];
      final noLocation = map['suggestScoreNoLocation'];
      if (side is! int ||
          open is! num ||
          suggest is! num ||
          noLocation is! num) {
        return null;
      }
      return NamingBars(
        minCropSide: side,
        minOpenScore: open.toDouble(),
        suggestScore: suggest.toDouble(),
        suggestScoreNoLocation: noLocation.toDouble(),
        levels: measuredLevels(
          map['levels'],
          suggest.toDouble(),
          noLocation.toDouble(),
        ),
      );
    } on FormatException {
      return null;
    }
  }

  @override
  List<Object?> get props => [
    minCropSide,
    minOpenScore,
    suggestScore,
    suggestScoreNoLocation,
    levels,
  ];
}
