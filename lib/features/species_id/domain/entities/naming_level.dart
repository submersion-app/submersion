import 'package:equatable/equatable.dart';

/// How readily the app suggests a species (issue #4721), surest first.
/// Surer is the pack's own suggest bars; the others are measured per pack
/// and carried in its manifest.
enum NamingLevel {
  surer,
  balanced,
  eager;

  /// The level until the diver picks one (issue #4789). A pack without it
  /// names at the most eager level it carries.
  static const NamingLevel byDefault = eager;

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

  /// The share of names that were right on held-out photos: the lower of
  /// the shares with a location and without one, so the figure shown never
  /// overstates for either kind of photo.
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

/// [value] when it is a share in (0, 1], else null.
double? measuredShare(Object? value) =>
    value is num && value.isFinite && value > 0 && value <= 1
    ? value.toDouble()
    : null;

/// A bar in [0, [ceiling]], else null.
double? _barAtMost(Object? value, double ceiling) =>
    value is num && value.isFinite && value >= 0 && value <= ceiling
    ? value.toDouble()
    : null;

/// The naming levels a manifest's `naming.levels` ([value]) carries
/// (issue #4721), surest first. They are optional: an entry is dropped,
/// and the pack still reads, unless it is a known level below Surer, with
/// bars no higher than the level above it and at least one of them lower,
/// a target in (0, 1], and a precision in (0, 1] no higher than the level
/// above's ([surerPrecision] for Surer, when measured), so more names
/// never read as more often right.
List<MeasuredNamingLevel> measuredLevels(
  Object? value,
  double suggestScore,
  double suggestScoreNoLocation, {
  double? surerPrecision,
}) {
  if (value is! List) return const [];
  final byLevel = <NamingLevel, Map<Object?, Object?>>{};
  for (final entry in value) {
    if (entry is! Map) continue;
    final id = entry['id'];
    final level = NamingLevel.fromId(id is String ? id : null);
    if (level == null || level == NamingLevel.surer) continue;
    byLevel.putIfAbsent(level, () => entry);
  }
  final levels = <MeasuredNamingLevel>[];
  var above = (suggestScore, suggestScoreNoLocation);
  var abovePrecision = surerPrecision;
  for (final level in NamingLevel.values) {
    final entry = byLevel[level];
    if (entry == null) continue;
    final suggest = _barAtMost(entry['suggestScore'], above.$1);
    final noLocation = _barAtMost(entry['suggestScoreNoLocation'], above.$2);
    final precision = measuredShare(entry['precision']);
    // A share of names that had to be right, as the scorer writes it.
    final target = measuredShare(entry['target']);
    if (suggest == null ||
        noLocation == null ||
        precision == null ||
        target == null ||
        // Bars the level above already names at add nothing.
        (suggest, noLocation) == above ||
        (abovePrecision != null && precision > abovePrecision)) {
      continue;
    }
    levels.add(
      MeasuredNamingLevel(
        level: level,
        target: target,
        suggestScore: suggest,
        suggestScoreNoLocation: noLocation,
        precision: precision,
      ),
    );
    above = (suggest, noLocation);
    abovePrecision = precision;
  }
  return List.unmodifiable(levels);
}
