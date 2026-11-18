import 'package:equatable/equatable.dart';

/// How sure the app must be before it names a fish (issue #4721), surest
/// first. Surer is the pack's own suggest bars; the others are measured
/// per pack and carried in its manifest.
enum NamingLevel {
  surer,
  balanced,
  eager;

  /// The level's id in a manifest and in the stored preference.
  String get id => name;

  /// The level named [id], or null for anything else.
  static NamingLevel? fromId(String? id) {
    for (final level in values) {
      if (level.id == id) return level;
    }
    return null;
  }
}

/// A naming level below the pack's own bars, as measured on that pack:
/// only the two suggest bars move.
class MeasuredNamingLevel extends Equatable {
  const MeasuredNamingLevel({
    required this.level,
    required this.target,
    required this.suggestScore,
    required this.suggestScoreNoLocation,
    required this.precision,
  });

  final NamingLevel level;

  /// The share of names that had to be right, by the scorer's test.
  final double target;
  final double suggestScore;
  final double suggestScoreNoLocation;

  /// The share of names that were right on held-out photos, with a
  /// location.
  final double precision;

  MeasuredNamingLevel copyWith({
    NamingLevel? level,
    double? target,
    double? suggestScore,
    double? suggestScoreNoLocation,
    double? precision,
  }) => MeasuredNamingLevel(
    level: level ?? this.level,
    target: target ?? this.target,
    suggestScore: suggestScore ?? this.suggestScore,
    suggestScoreNoLocation:
        suggestScoreNoLocation ?? this.suggestScoreNoLocation,
    precision: precision ?? this.precision,
  );

  @override
  List<Object?> get props => [
    level,
    target,
    suggestScore,
    suggestScoreNoLocation,
    precision,
  ];
}
