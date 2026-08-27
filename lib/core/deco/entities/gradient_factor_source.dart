import 'package:equatable/equatable.dart';

/// Where the gradient factors an analysis ran with actually came from.
enum GfOrigin {
  /// The dive itself recorded them: a dive computer that reports
  /// `DC_FIELD_DECOMODEL` in Buhlmann-GF mode, or an import that carried them.
  computer,

  /// The dive recorded none, so the diver's global setting was used instead.
  diverSettings,
}

/// The gradient factors an analysis ran with, plus their provenance (#1047).
///
/// Only 11 of libdivecomputer's 36 parsers implement `DC_FIELD_DECOMODEL`, and
/// even those report gradient factors only when the computer was in
/// Buhlmann-GF mode. So most computer-imported dives carry no GF of their own
/// and the analysis has to fall back to the diver's setting to produce a
/// ceiling at all. That fallback is correct; presenting its numbers as the
/// computer's configuration is not, which is what made a diver with a 45/80
/// computer read the app's 50/85 default off their own dive.
///
/// Resolving the pair and its origin together, once, keeps every surface from
/// re-deriving the same judgement and reaching a different answer.
class GradientFactorSource extends Equatable {
  /// GF Low as a percentage (0-100).
  final int low;

  /// GF High as a percentage (0-100).
  final int high;

  /// Whether [low]/[high] came from the dive or from the diver's settings.
  final GfOrigin origin;

  /// The deco model the dive recorded, when it recorded one: `buhlmann`,
  /// `vpm`, `rgbm`, `dciem` from libdivecomputer, `zhl_16c` from FIT, or
  /// whatever an import supplied. Null when nothing was recorded.
  final String? recordedAlgorithm;

  const GradientFactorSource({
    required this.low,
    required this.high,
    required this.origin,
    this.recordedAlgorithm,
  });

  /// Resolves the gradient factors for a dive, preferring its own over the
  /// diver's settings.
  ///
  /// A half-populated dive pair falls back entirely: mixing the dive's low
  /// with the setting's high would describe a gradient neither the computer
  /// nor the diver ever chose.
  factory GradientFactorSource.resolve({
    required int? diveGfLow,
    required int? diveGfHigh,
    required int settingsGfLow,
    required int settingsGfHigh,
    String? recordedAlgorithm,
  }) {
    if (diveGfLow != null && diveGfHigh != null) {
      return GradientFactorSource(
        low: diveGfLow.clamp(0, 100),
        high: diveGfHigh.clamp(0, 100),
        origin: GfOrigin.computer,
        recordedAlgorithm: recordedAlgorithm,
      );
    }
    return GradientFactorSource(
      low: settingsGfLow,
      high: settingsGfHigh,
      origin: GfOrigin.diverSettings,
      recordedAlgorithm: recordedAlgorithm,
    );
  }

  /// Whether [low]/[high] describe the diver's global setting rather than
  /// anything the dive recorded.
  bool get isFromDiverSettings => origin == GfOrigin.diverSettings;

  /// The deco models known not to use gradient factors.
  ///
  /// libdivecomputer emits the first three; the VPM-B spellings turn up in
  /// UDDF and other file imports.
  static const _knownNonGfAlgorithms = {
    'vpm',
    'rgbm',
    'dciem',
    'vpmb',
    'vpm-b',
  };

  /// Whether the dive recorded a deco model known not to use gradient factors.
  ///
  /// A Shearwater run in VPM reports its model with no GF pair, so the app
  /// analyzes it with the diver's gradient factors. Saying so is the
  /// difference between an explained approximation and a wrong number.
  ///
  /// Deliberately a whitelist, not "anything that is not Buhlmann". UDDF and
  /// other imports can carry an arbitrary string, and announcing that an
  /// unrecognized model "does not use gradient factors" asserts something we
  /// have no basis for. An unknown name is left unflagged, which costs a
  /// missing explanation rather than a wrong one.
  bool get recordedNonGfAlgorithm {
    final algorithm = recordedAlgorithm?.trim().toLowerCase();
    if (algorithm == null || algorithm.isEmpty) return false;
    return _knownNonGfAlgorithms.contains(algorithm);
  }

  /// GF Low as a 0.0-1.0 fraction, the form the deco engine takes.
  double get lowFraction => (low / 100.0).clamp(0.0, 1.0);

  /// GF High as a 0.0-1.0 fraction, the form the deco engine takes.
  double get highFraction => (high / 100.0).clamp(0.0, 1.0);

  @override
  List<Object?> get props => [low, high, origin, recordedAlgorithm];
}
