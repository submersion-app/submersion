import 'dart:convert';

import 'package:equatable/equatable.dart';

/// A colour the diver picked as "this should be white or grey", sampled from
/// the uncorrected image. Channels are 0..1.
class WhitePoint extends Equatable {
  const WhitePoint(this.r, this.g, this.b);

  final double r;
  final double g;
  final double b;

  @override
  List<Object?> get props => [r, g, b];
}

/// The diver's hand adjustment for one photo or video (issue #3520).
///
/// Stored as JSON on the synced media row; never written into the file.
/// Every slider is -1..1 with 0 meaning "no change", except [strength]
/// (how much of the automatic fix or white point applies, 0..1).
class ColorAdjustment extends Equatable {
  const ColorAdjustment({
    this.autoOverride,
    this.strength = 1.0,
    this.warmth = 0,
    this.tint = 0,
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.whitePoint,
  });

  /// Turns the automatic fix on or off for this item; null follows the
  /// diver's setting.
  final bool? autoOverride;
  final double strength;
  final double warmth;
  final double tint;
  final double brightness;
  final double contrast;
  final double saturation;
  final WhitePoint? whitePoint;

  static const _version = 1;

  bool get isNeutral => this == const ColorAdjustment();

  /// This item with [source]'s Auto switch and sliders, keeping its own
  /// white point ("Apply to this dive": a white point only holds for the
  /// photo it was picked on).
  ColorAdjustment withSlidersFrom(ColorAdjustment source) =>
      source.copyWith(whitePoint: whitePoint);

  ColorAdjustment copyWith({
    Object? autoOverride = _undefined,
    double? strength,
    double? warmth,
    double? tint,
    double? brightness,
    double? contrast,
    double? saturation,
    Object? whitePoint = _undefined,
  }) => ColorAdjustment(
    autoOverride: autoOverride == _undefined
        ? this.autoOverride
        : autoOverride as bool?,
    strength: strength ?? this.strength,
    warmth: warmth ?? this.warmth,
    tint: tint ?? this.tint,
    brightness: brightness ?? this.brightness,
    contrast: contrast ?? this.contrast,
    saturation: saturation ?? this.saturation,
    whitePoint: whitePoint == _undefined
        ? this.whitePoint
        : whitePoint as WhitePoint?,
  );

  String toJsonString() {
    final w = whitePoint;
    return jsonEncode({
      'v': _version,
      if (autoOverride != null) 'auto': autoOverride,
      if (strength != 1.0) 'strength': strength,
      if (warmth != 0) 'warmth': warmth,
      if (tint != 0) 'tint': tint,
      if (brightness != 0) 'brightness': brightness,
      if (contrast != 0) 'contrast': contrast,
      if (saturation != 0) 'saturation': saturation,
      if (w != null) 'white': [w.r, w.g, w.b],
    });
  }

  /// Parses a stored value. Anything unreadable is "no adjustment", and
  /// unknown keys (a newer peer's) are ignored, so a bad row can never break
  /// a grid.
  static ColorAdjustment? fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final map = decoded;

    double slider(String key, {double fallback = 0, double min = -1}) {
      final v = map[key];
      return v is num ? v.toDouble().clamp(min, 1.0) : fallback;
    }

    final auto = map['auto'];
    final parsed = ColorAdjustment(
      autoOverride: auto is bool ? auto : null,
      strength: slider('strength', fallback: 1.0, min: 0),
      warmth: slider('warmth'),
      tint: slider('tint'),
      brightness: slider('brightness'),
      contrast: slider('contrast'),
      saturation: slider('saturation'),
      whitePoint: _whitePointFrom(map['white']),
    );
    // The neutral value is how a cleared adjustment is stored, so that the
    // clear syncs; it means no adjustment.
    return parsed.isNeutral ? null : parsed;
  }

  static WhitePoint? _whitePointFrom(Object? raw) {
    if (raw is! List || raw.length != 3 || raw.any((v) => v is! num)) {
      return null;
    }
    double c(int i) => (raw[i] as num).toDouble().clamp(0.0, 1.0);
    return WhitePoint(c(0), c(1), c(2));
  }

  @override
  List<Object?> get props => [
    autoOverride,
    strength,
    warmth,
    tint,
    brightness,
    contrast,
    saturation,
    whitePoint,
  ];
}

const _undefined = Object();
