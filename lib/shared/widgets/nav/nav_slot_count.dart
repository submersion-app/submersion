/// Minimum number of customizable slots between Home and More on the phone
/// bottom bar. Matches the value every device got before #1424, so no phone
/// ever ends up with fewer primary slots than it had before.
const int kMinPhonePrimarySlotCount = 3;

/// Width in logical pixels reserved for one nav slot (icon + label), based on
/// Material 3's bottom-navigation-item guidance.
const double navSlotWidthWithLabel = 80;

/// Width reserved for one nav slot when labels are hidden.
const double navSlotWidthIconOnly = 64;

/// How many customizable slots fit between the pinned Home and More
/// destinations on the phone bottom bar.
///
/// [baseWidth] should be `min(width, height)` of the current view rather than
/// the raw width: a phone rotation only swaps width and height, so the
/// minimum -- and therefore the result -- stays the same across rotation. An
/// actual resize (e.g. Android split screen, a foldable) changes the minimum
/// and is free to change the result.
///
/// [availableCount] is the number of movable destinations that exist; the
/// result never exceeds it; a very wide screen can show every destination
/// as a primary slot but not more.
///
/// The result is never below [kMinPhonePrimarySlotCount], so no device ever
/// shows fewer primary slots than the fixed value every phone got before
/// this became width-dependent, unless fewer destinations than that exist:
/// the [availableCount] cap always wins.
int phonePrimarySlotCount({
  required double baseWidth,
  required bool showLabels,
  required int availableCount,
}) {
  final slotWidth = showLabels ? navSlotWidthWithLabel : navSlotWidthIconOnly;
  // Home and More each occupy one slot's worth of width too.
  final usableWidth = baseWidth - (2 * slotWidth);
  final computed = usableWidth <= 0 ? 0 : (usableWidth / slotWidth).floor();
  final atLeastMinimum = computed < kMinPhonePrimarySlotCount
      ? kMinPhonePrimarySlotCount
      : computed;
  return atLeastMinimum > availableCount ? availableCount : atLeastMinimum;
}
