import 'package:submersion/core/services/sync/hlc.dart';

/// Process-wide Hybrid Logical Clock for the local device.
///
/// Repositories call [issue] on every write to stamp a record's `hlc` column;
/// the sync merge calls [receive] for every remote HLC it sees so this clock
/// advances past other devices' physical times (the clock-skew fix). The
/// clock is held in memory for a synchronous [issue]; the sync layer is
/// responsible for seeding it ([configure]) from the persisted value at
/// startup and writing [current] back when it next persists sync metadata.
///
/// Until [configure] is called, [issue] returns null and callers fall back to
/// `updatedAt`-only ordering -- so the clock is safe to reference before it is
/// wired up (e.g. in tests that do not care about HLC).
class SyncClock {
  SyncClock._();

  /// The shared instance, mirroring the `DatabaseService.instance` pattern.
  static final SyncClock instance = SyncClock._();

  Hlc? _current;
  int Function() _now = () => DateTime.now().millisecondsSinceEpoch;

  /// True once [configure] has run and [issue] will return values.
  bool get isConfigured => _current != null;

  /// The current clock reading, or null if unconfigured. The sync layer reads
  /// this to persist clock continuity across restarts.
  Hlc? get current => _current;

  /// Seed the clock for [nodeId] (this device's id). If [persisted] is given
  /// (the clock value stored at last sync) it is used so the logical counter
  /// continues across app restarts; otherwise the clock starts at "now".
  /// [now] overrides the wall-clock source for tests.
  void configure({
    required String nodeId,
    Hlc? persisted,
    int Function()? now,
  }) {
    if (now != null) _now = now;
    _current = persisted ?? Hlc.now(nodeId, _now());
  }

  /// Issue a new HLC string for a LOCAL write, advancing the clock. Returns
  /// null if the clock is not configured.
  String? issue() {
    final c = _current;
    if (c == null) return null;
    final next = c.increment(_now());
    _current = next;
    return next.toString();
  }

  /// Advance the clock on receipt of a [remote] HLC during a merge. No-op if
  /// the clock is not configured.
  void receive(Hlc remote) {
    final c = _current;
    if (c == null) return;
    _current = c.merge(remote, _now());
  }

  /// Reset to the unconfigured state. For tests and account switching.
  void reset() {
    _current = null;
    _now = () => DateTime.now().millisecondsSinceEpoch;
  }
}
