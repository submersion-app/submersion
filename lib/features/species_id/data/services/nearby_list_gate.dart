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
  final Queue<Completer<void>> _waiting = Queue<Completer<void>>();

  /// Completes when it is the caller's turn. Each turn taken is handed
  /// back with [release], exactly once.
  Future<void> acquire() {
    if (_running < limit) {
      _running++;
      return Future.value();
    }
    final turn = Completer<void>();
    _waiting.add(turn);
    return turn.future;
  }

  /// Hands a turn to the next caller waiting, or frees it.
  void release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else {
      _running--;
    }
  }
}
