import 'package:submersion/core/text/fuzzy_match.dart';

final _notLetterOrDigit = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

/// A site name reduced to what tells one name from another: folded the way
/// the site picker folds names (case and accents), with every run of
/// punctuation or spacing read as one space. Empty when the name holds no
/// letter or digit.
String catalogueNameKey(String name) =>
    normalize(name).replaceAll(_notLetterOrDigit, ' ').trim();

/// Whether a diver's site and a catalogue record carry the same name.
///
/// "Salt-Pier" and "salt pier" do; "Thistlegorm" and "SS Thistlegorm" do
/// not. A name with nothing to compare equals nothing, not even another
/// such name: two blank names say nothing about being the same place.
bool catalogueNamesEqual(String a, String b) {
  final key = catalogueNameKey(a);
  return key.isNotEmpty && key == catalogueNameKey(b);
}
