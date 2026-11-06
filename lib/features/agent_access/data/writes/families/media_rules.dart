import 'dart:convert';

import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';

/// The sliders a colour adjustment holds, each -1 to 1, as the editor's.
const _sliders = ['warmth', 'tint', 'brightness', 'contrast', 'saturation'];

/// A colour adjustment as an agent writes one, in the form the store keeps,
/// or a refusal: sliders -1 to 1, strength and the white point's channels
/// 0 to 1, as the editor holds them, never clamped silently.
Map<String, Object?> colorAdjustmentJson(Map<String, Object?> raw) {
  const known = {..._sliders, 'strength', 'white', 'auto', 'v'};
  final unknown = raw.keys.where((k) => !known.contains(k)).toList();
  if (unknown.isNotEmpty) {
    throw FieldRefusal('A colour adjustment has no ${unknown.join(', ')}.');
  }
  double number(String key, double fallback, double min) {
    final v = raw[key] ?? fallback;
    if (v is! num || v < min || v > 1) {
      throw FieldRefusal('$key is a number from $min to 1.');
    }
    return v.toDouble();
  }

  final white = raw['white'];
  WhitePoint? point;
  if (white != null) {
    if (white is! List ||
        white.length != 3 ||
        white.any((c) => c is! num || c < 0 || c > 1)) {
      throw const FieldRefusal('white is three channels, each 0 to 1.');
    }
    point = WhitePoint(
      (white[0] as num).toDouble(),
      (white[1] as num).toDouble(),
      (white[2] as num).toDouble(),
    );
  }
  final auto = raw['auto'];
  if (auto != null && auto is! bool) {
    throw const FieldRefusal('auto is true, false or null.');
  }
  final adjustment = ColorAdjustment(
    autoOverride: auto as bool?,
    strength: number('strength', 1, 0),
    warmth: number('warmth', 0, -1),
    tint: number('tint', 0, -1),
    brightness: number('brightness', 0, -1),
    contrast: number('contrast', 0, -1),
    saturation: number('saturation', 0, -1),
    whitePoint: point,
  );
  return (jsonDecode(adjustment.toJsonString()) as Map).cast<String, Object?>();
}

/// [json], a stored-form adjustment, as the model the repository writes.
ColorAdjustment? colorAdjustmentOf(Map<String, Object?>? json) =>
    json == null ? null : ColorAdjustment.fromJsonString(jsonEncode(json));
