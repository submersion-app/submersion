import 'dart:async';
import 'dart:collection';

/// Lets at most [limit] "Recorded nearby" lists be fetched at once for the
/// marine life marker (issue #4668).
///
/// A list not yet saved costs GBIF one occurrence search and up to 25 name
/// lookups, a burst sized for the one site page a diver has open. Species
/// to review for the whole log builds a row per dive at once, so without
/// this every site not yet saved would be asked for together. The rest
/// wait their turn, first come first served, which is the page's order.
class NearbyListGate {
  NearbyListGate({this.limit = 2}) : assert(limit > 0);

  /// Lists fetched at once.
  final int limit;

  int _running = 0;
  final Queue<Completer<NearbyListTurn>> _waiting =
      Queue<Completer<NearbyListTurn>>();

  /// Completes with the caller's turn, to [NearbyListTurn.release] when its
  /// list has arrived or is no longer wanted.
  Future<NearbyListTurn> acquire() {
    if (_running < limit) {
      _running++;
      return Future.value(NearbyListTurn._(this));
    }
    final turn = Completer<NearbyListTurn>();
    _waiting.add(turn);
    return turn.future;
  }

  /// Hands a released turn to the next caller waiting, or frees it.
  void _handOn() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete(NearbyListTurn._(this));
    } else {
      _running--;
    }
  }
}

/// One caller's place in [NearbyListGate]. Releasing it again does nothing,
/// so a caller that hands it back from several exits cannot widen the gate.
class NearbyListTurn {
  NearbyListTurn._(this._gate);

  final NearbyListGate _gate;
  bool _held = true;

  void release() {
    if (!_held) return;
    _held = false;
    _gate._handOn();
  }
}
