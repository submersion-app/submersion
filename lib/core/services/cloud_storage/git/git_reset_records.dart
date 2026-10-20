import 'dart:async';

/// What is known about one repository and branch's history resets: when the
/// history was last reset, and whether the host refused the last reset.
typedef GitResetStatus = ({DateTime? lastResetAt, bool refused});

/// History reset outcomes by repository and branch (the Git natural key),
/// with a stream of the keys whose outcome changed, so the Cloud sync page
/// can follow resets that happen while it is open.
class GitResetRecords {
  /// Nothing known: no reset seen and none refused.
  static const GitResetStatus none = (lastResetAt: null, refused: false);

  final Map<String, DateTime> _lastResetAt = {};
  final Set<String> _refused = {};
  final StreamController<String> _changes = StreamController.broadcast();

  /// The keys whose status changed, one event per change.
  Stream<String> get changes => _changes.stream;

  GitResetStatus statusFor(String key) =>
      (lastResetAt: _lastResetAt[key], refused: _refused.contains(key));

  /// Records that [key]'s history was last reset [at].
  void noteReset(String key, DateTime at) {
    if (_lastResetAt[key] == at) return;
    _lastResetAt[key] = at;
    _announce(key);
  }

  /// Records whether the host refused [key]'s last history reset.
  void noteRefused(String key, {required bool refused}) {
    final changed = refused ? _refused.add(key) : _refused.remove(key);
    if (changed) _announce(key);
  }

  // Still recorded once disposed; there is just no one left to tell.
  void _announce(String key) {
    if (!_changes.isClosed) _changes.add(key);
  }

  void dispose() => _changes.close();
}
