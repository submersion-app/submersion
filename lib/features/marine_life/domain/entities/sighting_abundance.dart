/// How many animals a sighting records (issue #4337).
///
/// A diver either saw the species without counting ([seen]), sorted it into
/// one of the four REEF survey groups ([single], [few], [many], [abundant]),
/// or counted it exactly ([exact], with the number in the sighting's count).
/// The REEF groups (Reef Environmental Education Foundation volunteer fish
/// survey) have fixed ranges, so an exact count always falls inside one.
enum SightingAbundance {
  seen,
  single,
  few,
  many,
  abundant,
  exact;

  /// The value stored in `sightings.abundance`. Exact is stored as null,
  /// which is what makes every sighting from before the column existed, and
  /// every sighting from an older peer, read as the exact count it carries.
  String? get storageValue => this == exact ? null : name;

  /// Reads a stored value. Null, and any text this build does not know, is
  /// [exact]: the count column is then the only thing the row says.
  static SightingAbundance fromStorage(String? value) {
    if (value == null) return exact;
    for (final a in values) {
      if (a != exact && a.name == value) return a;
    }
    return exact;
  }

  /// Whether this is one of the four REEF groups.
  bool get isGroup =>
      this == single || this == few || this == many || this == abundant;

  /// The REEF group an exact [count] falls in: 1 is Single, 2 to 10 Few,
  /// 11 to 100 Many, more than 100 Abundant. A count below 1 is Single.
  static SightingAbundance groupForCount(int count) {
    if (count <= 1) return single;
    if (count <= 10) return few;
    if (count <= 100) return many;
    return abundant;
  }

  /// Combines two sightings of the same species, as a dive merge or a trip
  /// day does. Two exact counts add up. Seen carries no number, so it gives
  /// way to the other side. Otherwise the larger REEF group wins, an exact
  /// count first placed in its group; a group is always carried with count 1.
  static SightingAmount combine(SightingAmount a, SightingAmount b) {
    if (a.abundance == exact && b.abundance == exact) {
      return (abundance: exact, count: a.count + b.count);
    }
    if (a.abundance == seen) return b;
    if (b.abundance == seen) return a;
    final groupA = _groupOf(a);
    final groupB = _groupOf(b);
    final larger = groupB.index > groupA.index ? groupB : groupA;
    return (abundance: larger, count: 1);
  }

  static SightingAbundance _groupOf(SightingAmount amount) =>
      amount.abundance == exact
      ? groupForCount(amount.count)
      : amount.abundance;
}

/// A sighting's abundance with its count. The count is the exact number for
/// [SightingAbundance.exact] and 1 for every other value.
typedef SightingAmount = ({SightingAbundance abundance, int count});
