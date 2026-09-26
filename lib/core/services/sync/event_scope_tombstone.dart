import 'package:submersion/core/services/sync/hlc.dart';

/// One tombstone for a set of `dive_profile_events` rows (#1926): every
/// event on a dive, or every event one computer recorded on it.
///
/// It rides the ordinary `deletion_log` under its own entity type, so export,
/// relay and GC treat it like any tombstone, and a reader too old to know the
/// type stores it as an inert unknown entity and deletes nothing (the
/// compatibility floor keeps such readers from receiving one at all). The
/// scope is never sent as extra fields on a `diveProfileEvents` entry: an
/// older reader ignores unknown fields and would delete the one row named by
/// `id`.
class EventScopeTombstone {
  static const String entityType = 'diveProfileEventsScope';

  final String diveId;
  final String? computerId;

  const EventScopeTombstone({required this.diveId, this.computerId});

  /// `<diveId>` or `<diveId>|<computerId>`. Both ids are uuids, which never
  /// contain the separator.
  String encode() => computerId == null ? diveId : '$diveId|$computerId';

  static EventScopeTombstone? tryDecode(String recordId) {
    final parts = recordId.split('|');
    if (parts.length > 2 || parts.any((p) => p.isEmpty)) return null;
    return EventScopeTombstone(
      diveId: parts[0],
      computerId: parts.length == 2 ? parts[1] : null,
    );
  }

  /// Whether an event on [diveId] recorded by [computerId] is in scope.
  bool includes({required String diveId, required String? computerId}) =>
      diveId == this.diveId &&
      (this.computerId == null || computerId == this.computerId);
}

/// Whether an event row existed when a scope delete happened, so the delete
/// covers it. This is the per-row rule from #1769 applied to a set: with
/// both clocks the clocks decide (a tie is covered, as a per-row tombstone
/// deletes a row whose clock equals its own); otherwise creation time
/// against the delete time, so a pre-v210 row with no clock is still removed.
bool eventPredatesScopeDelete({
  required Hlc? rowHlc,
  required int rowCreatedAt,
  required Hlc? deleteHlc,
  required int deletedAt,
}) {
  if (rowHlc != null && deleteHlc != null) {
    return rowHlc.compareTo(deleteHlc) <= 0;
  }
  return rowCreatedAt <= deletedAt;
}

/// [raw] as a clock, or null when it is missing or unreadable.
Hlc? tryParseHlc(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  try {
    return Hlc.parse(raw);
  } catch (_) {
    return null;
  }
}

typedef _StoredScope = ({EventScopeTombstone scope, int deletedAt, Hlc? clock});

/// The stored scope tombstones, indexed by dive for the merge: whether an
/// incoming event row is one a scope delete already removed.
class EventScopeCoverage {
  final Map<String, List<_StoredScope>> _byDive;

  const EventScopeCoverage._(this._byDive);

  /// Built from the deletion maps the merge already holds, keyed by the
  /// scope tombstones' record ids. Undecodable ids are skipped.
  factory EventScopeCoverage.from({
    required Map<String, int> deletedAt,
    required Map<String, Hlc> clocks,
  }) {
    final byDive = <String, List<_StoredScope>>{};
    deletedAt.forEach((recordId, at) {
      final scope = EventScopeTombstone.tryDecode(recordId);
      if (scope == null) return;
      byDive.putIfAbsent(scope.diveId, () => []).add((
        scope: scope,
        deletedAt: at,
        clock: clocks[recordId],
      ));
    });
    return EventScopeCoverage._(byDive);
  }

  bool get isEmpty => _byDive.isEmpty;

  /// Whether [event], a `diveProfileEvents` record as the wire carries it,
  /// predates a stored scope delete that includes it.
  bool covers(Map<String, dynamic> event) {
    final diveId = event['diveId'];
    if (diveId is! String) return false;
    final scopes = _byDive[diveId];
    if (scopes == null) return false;
    final computerId = event['computerId'];
    final createdAt = event['createdAt'];
    final rowHlc = tryParseHlc(event['hlc']);
    for (final s in scopes) {
      if (!s.scope.includes(
        diveId: diveId,
        computerId: computerId is String ? computerId : null,
      )) {
        continue;
      }
      if (eventPredatesScopeDelete(
        rowHlc: rowHlc,
        rowCreatedAt: createdAt is int ? createdAt : 0,
        deleteHlc: s.clock,
        deletedAt: s.deletedAt,
      )) {
        return true;
      }
    }
    return false;
  }
}
