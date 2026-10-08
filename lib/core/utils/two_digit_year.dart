/// The latest year ending in [twoDigits] that is not after [now]'s year.
///
/// A dive cannot be logged in the future, so in 2026 `26` is 2026 and `91`
/// is 1991. Read literally, `91` is the year 91, which the Clock & timezone
/// check reports as dated before 1950 (#2617).
int expandTwoDigitYear(int twoDigits, {required DateTime now}) {
  final thisYear = now.year;
  final candidate = thisYear - thisYear % 100 + twoDigits;
  return candidate > thisYear ? candidate - 100 : candidate;
}
