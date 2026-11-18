/// How sure the app must be before it names a fish (issue #4721): the
/// level in force, and what an identification the installed pack named
/// would be at it. Pure functions, so every screen and the service share
/// them.
library;

import 'package:equatable/equatable.dart';

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/naming_level.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';

/// The bars a level names at, for the pack that measured them. Only the
/// two suggest bars differ from the pack's own.
class LevelInForce extends Equatable {
  const LevelInForce({
    required this.level,
    required this.packVersion,
    required this.minCropSide,
    required this.minOpenScore,
    required this.suggestScore,
    required this.suggestScoreNoLocation,
  });

  final NamingLevel level;
  final String packVersion;
  final int minCropSide;
  final double minOpenScore;
  final double suggestScore;
  final double suggestScoreNoLocation;

  LevelInForce copyWith({
    NamingLevel? level,
    String? packVersion,
    int? minCropSide,
    double? minOpenScore,
    double? suggestScore,
    double? suggestScoreNoLocation,
  }) => LevelInForce(
    level: level ?? this.level,
    packVersion: packVersion ?? this.packVersion,
    minCropSide: minCropSide ?? this.minCropSide,
    minOpenScore: minOpenScore ?? this.minOpenScore,
    suggestScore: suggestScore ?? this.suggestScore,
    suggestScoreNoLocation:
        suggestScoreNoLocation ?? this.suggestScoreNoLocation,
  );

  @override
  List<Object?> get props => [
    level,
    packVersion,
    minCropSide,
    minOpenScore,
    suggestScore,
    suggestScoreNoLocation,
  ];
}

/// The levels to offer: none when the pack carries no levels below its own
/// bars, else Surer and the ones it carries, surest first.
List<NamingLevel> offeredLevels(NamingConfig naming) => naming.levels.isEmpty
    ? const []
    : [NamingLevel.surer, for (final l in naming.levels) l.level];

/// The level [manifest]'s pack names at when the diver chose [chosen]: the
/// chosen one if the pack carries it, else the nearest surer one it does.
/// Null with no pack.
LevelInForce? levelInForce(SpeciesPackManifest? manifest, NamingLevel chosen) {
  if (manifest == null) return null;
  final naming = manifest.naming;
  MeasuredNamingLevel? measured;
  for (final level in naming.levels) {
    if (level.level.index <= chosen.index) measured = level;
  }
  return LevelInForce(
    level: measured?.level ?? NamingLevel.surer,
    packVersion: manifest.packVersion,
    minCropSide: naming.minCropSide,
    minOpenScore: naming.minOpenScore,
    suggestScore: measured?.suggestScore ?? naming.suggestScore,
    suggestScoreNoLocation:
        measured?.suggestScoreNoLocation ?? naming.suggestScoreNoLocation,
  );
}

/// The share of names that were right at [level] on [naming]'s pack, or
/// null when it was not measured.
double? precisionOf(NamingConfig naming, NamingLevel level) {
  if (level == NamingLevel.surer) return naming.precision;
  for (final measured in naming.levels) {
    if (measured.level == level) return measured.precision;
  }
  return null;
}

/// [precision] as a whole percentage rounded down to a multiple of 5, so
/// it never claims more than was measured.
int accuracyPercent(double precision) =>
    ((precision * 100) + 1e-9).floor() ~/ 5 * 5;

/// Whether [identification] clears [level]'s bars, worked out exactly as
/// the pack names a crop (`SpeciesNamer.name`).
bool suggestableAt(MediaIdentification identification, LevelInForce level) {
  final top = identification.top;
  final bar = identification.locationLimited
      ? level.suggestScore
      : level.suggestScoreNoLocation;
  return identification.boxShorterSide >= level.minCropSide &&
      identification.openScore >= level.minOpenScore &&
      top != null &&
      top.score >= bar;
}

/// [all] as [level] would suggest them, when the pack in force named them
/// ([namedWithPack] is their run's pack version). Otherwise, or with no
/// level, [all] as stored: the level's bars were measured on its own
/// pack's scores only. Only `suggestable` changes; the stored column keeps
/// the pack's own answer, so nothing here is written back.
List<MediaIdentification> applyNamingLevel(
  List<MediaIdentification> all, {
  required LevelInForce? level,
  required String? namedWithPack,
}) {
  if (level == null || namedWithPack != level.packVersion) return all;
  return [
    for (final i in all) i.copyWith(suggestable: suggestableAt(i, level)),
  ];
}
