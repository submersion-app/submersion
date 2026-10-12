import 'package:submersion/core/services/sync/hlc.dart';

/// A hybrid logical clock for one member of a club library (issue #2567).
///
/// Unlike `SyncClock` it is not a singleton: one per library sync or edit,
/// seeded from the newest clock the device already holds, so a member's
/// stamps sort after every clock they have seen, whoever wrote it.
class MemberClock {
  MemberClock(this.memberId, {int Function()? now, Hlc? seed})
    : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch),
      _current = seed == null
          ? Hlc(0, 0, memberId)
          : Hlc(seed.physicalTime, seed.counter, memberId);

  final String memberId;
  final int Function() _now;
  Hlc _current;

  /// A fresh stamp for a local edit, strictly after every earlier stamp
  /// and every clock received.
  Hlc next() {
    _current = _current.increment(_now());
    return _current;
  }

  /// Fold a remote clock in so later local stamps sort after it. The
  /// remote node id is replaced by this member's.
  void receive(Hlc remote) {
    if (remote.compareTo(_current) > 0) {
      _current = Hlc(remote.physicalTime, remote.counter, memberId);
    }
  }
}
