import 'package:submersion/core/text/fuzzy_match.dart';

/// The combining accents written after a Latin, Greek or Cyrillic letter
/// (U+0300 to U+036F). A name can carry "u" and a separate acute where
/// another carries the single letter; without the mark the two agree, as
/// [normalize] already makes the single letters agree.
final _combiningAccents = RegExp('[\u0300-\u036f]');

/// Everything that is not a letter, a digit or a mark belonging to one.
/// Marks of other scripts (Thai vowels and tones, Arabic and Hebrew
/// points) are part of the word and stay in it.
final _separators = RegExp(r'[^\p{L}\p{N}\p{M}]+', unicode: true);

/// A site name reduced to what tells one name from another: folded the way
/// the site picker folds names (case and accents), with every run of
/// punctuation or spacing read as one space. Empty when the name holds no
/// letter or digit.
String catalogueNameKey(String name) => normalize(
  name,
).replaceAll(_combiningAccents, '').replaceAll(_separators, ' ').trim();

/// Whether a diver's site and a catalogue record carry the same name.
///
/// "Salt-Pier" and "salt pier" do; "Thistlegorm" and "SS Thistlegorm" do
/// not. A name with nothing to compare equals nothing, not even another
/// such name: two blank names say nothing about being the same place.
bool catalogueNamesEqual(String a, String b) {
  final key = catalogueNameKey(a);
  return key.isNotEmpty && key == catalogueNameKey(b);
}
