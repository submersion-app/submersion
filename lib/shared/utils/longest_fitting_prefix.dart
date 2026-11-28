/// The longest prefix of [value] that [fits] accepts, but never shorter than
/// [floor] code units.
///
/// [fits] must be monotonic: if a prefix fits, every shorter one does too.
/// That holds for "the URL built with this prefix stays under a cap", which
/// is what the suggestion links use it for (issue #5103). A binary search
/// over the prefix length sizes the cut to what the prefix actually costs
/// once encoded, so a CJK character (nine URL characters) and an ASCII one
/// (one) both keep as much text as fits.
///
/// The cut never lands between the two halves of a surrogate pair, which a
/// URL encoder would otherwise write out as a stray replacement character.
String longestFittingPrefix(
  String value,
  bool Function(String candidate) fits, {
  int floor = 0,
}) {
  if (fits(value)) return value;
  var low = floor.clamp(0, value.length);
  var high = value.length - 1;
  // Invariant: the answer is in [low, high]; prefixes past high do not fit.
  while (low < high) {
    final mid = (low + high + 1) ~/ 2;
    if (fits(value.substring(0, mid))) {
      low = mid;
    } else {
      high = mid - 1;
    }
  }
  return value.substring(0, _wholeCharacters(value, low, floor));
}

/// [end], moved off the middle of a surrogate pair: back one code unit, or
/// forward one when going back would drop below [floor].
int _wholeCharacters(String value, int end, int floor) {
  if (end == 0 || end >= value.length) return end;
  final last = value.codeUnitAt(end - 1);
  final splitsPair = last >= 0xD800 && last <= 0xDBFF;
  if (!splitsPair) return end;
  return end - 1 >= floor ? end - 1 : end + 1;
}
