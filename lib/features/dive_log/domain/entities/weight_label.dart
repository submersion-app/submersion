import 'package:characters/characters.dart';

/// The longest name a weight row stores (issue #956), in characters as a
/// text field counts them (grapheme clusters).
const int weightLabelMaxLength = 256;

/// [raw] as a weight name is stored: trimmed, and cut to
/// [weightLabelMaxLength] characters without splitting one. Whitespace only
/// becomes '' (unnamed).
String normalizeWeightLabel(String raw) {
  final trimmed = raw.trim();
  final characters = trimmed.characters;
  if (characters.length <= weightLabelMaxLength) return trimmed;
  return characters.take(weightLabelMaxLength).toString().trimRight();
}
