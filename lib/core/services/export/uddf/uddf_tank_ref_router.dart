/// The parsed-tank key holding the computer slot a sample's
/// `<tankpressure ref="T2">` named (2 for T2), set only when the ref was tied
/// to its cylinder by pressure evidence (issue #4347). Parsed data only:
/// nothing stores it at import time.
const kUddfSourceSlotKey = 'sourceSlot';

/// Pressure agreement, in bar, for tying a ref to a cylinder. Both sides are
/// the same Pascal integer divided the same way, so any real difference is
/// far larger than this.
const _pressureToleranceBar = 0.01;

final _slotRef = RegExp(r'^T(\d+)$', caseSensitive: false);

/// Routes the `<tankpressure ref>` values a dive's samples carry to the
/// parsed cylinders that have no UDDF id to match them by.
///
/// Shearwater Cloud writes bare `<tankdata>` (no id) and labels each sample
/// pressure by its transmitter slot (`T1` to `T4`). A ref is tied to the
/// cylinder whose begin pressure equals the ref's first reading, when exactly
/// one id-less cylinder does; otherwise it takes the next unclaimed cylinder
/// in list order, which is how every ref was routed before. Only a
/// pressure-tied `T<n>` ref records a slot: a label is never given by order.
class UddfTankRefRouter {
  UddfTankRefRouter(this._tanks)
    : _candidates = [
        for (var i = 0; i < _tanks.length; i++)
          if (_tanks[i]['uddfTankId'] == null) i,
      ];

  final List<Map<String, dynamic>> _tanks;
  final List<int> _candidates;
  final _indexByRef = <String, int>{};
  final _claimed = <int>{};
  final _slotByIndex = <int, int>{};

  /// The cylinder index for [ref], whose first sample reads
  /// [firstPressureBar]; null when every id-less cylinder is already taken.
  int? indexFor(String ref, double firstPressureBar) {
    // One ref however it is spelled: the slot is read the same way.
    final name = ref.trim().toUpperCase();
    final known = _indexByRef[name];
    if (known != null) return known;

    final paired = _pairedByPressure(firstPressureBar);
    final index = paired ?? _nextUnclaimed();
    if (index == null) return null;

    _claimed.add(index);
    _indexByRef[name] = index;
    final slot = _slotRef.firstMatch(name)?.group(1);
    if (paired != null && slot != null) {
      _slotByIndex[index] = int.parse(slot);
    }
    return index;
  }

  /// Writes each recorded slot onto its parsed cylinder.
  void writeSlots() {
    for (final entry in _slotByIndex.entries) {
      _tanks[entry.key][kUddfSourceSlotKey] = entry.value;
    }
  }

  /// The one id-less cylinder whose begin pressure matches, if it is still
  /// free. Uniqueness is judged over every id-less cylinder, so a twin that
  /// an earlier ref claimed by order still makes the match ambiguous.
  int? _pairedByPressure(double pressureBar) {
    final matches = [
      for (final i in _candidates)
        if (_startOf(i) case final start?
            when (start - pressureBar).abs() < _pressureToleranceBar)
          i,
    ];
    if (matches.length != 1) return null;
    final match = matches.single;
    return _claimed.contains(match) ? null : match;
  }

  int? _nextUnclaimed() {
    for (final i in _candidates) {
      if (!_claimed.contains(i)) return i;
    }
    return null;
  }

  double? _startOf(int index) =>
      (_tanks[index]['startPressure'] as num?)?.toDouble();
}
