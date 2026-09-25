import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import 'connection_kind.dart';
import 'node_ref.dart';

/// What to load: a pair of kinds, the diver's filter, an optional focus for
/// ego mode, and the node budget.
///
/// Not Equatable on purpose: [DiveFilterState] has no value equality, so this
/// type is never used as a provider family key. Providers watch the lens,
/// filter and focus providers separately and build a query per build.
class ConnectionQuery {
  const ConnectionQuery({
    required this.kindA,
    required this.kindB,
    this.filter = const DiveFilterState(),
    this.focus,
    this.nodeBudget = 80,
  });

  final ConnectionKind kindA;
  final ConnectionKind kindB;
  final DiveFilterState filter;
  final NodeRef? focus;
  final int nodeBudget;

  bool get isSelfJoin => kindA == kindB;

  /// The kind at the far end of [focus]; null without a focus or when the
  /// focus kind is not part of this query.
  ConnectionKind? get neighbourKind {
    final f = focus;
    if (f == null) return null;
    if (f.kind == kindA) return kindB;
    if (f.kind == kindB) return kindA;
    return null;
  }

  bool get focusIsValid => focus == null || neighbourKind != null;

  ConnectionQuery copyWith({
    ConnectionKind? kindA,
    ConnectionKind? kindB,
    DiveFilterState? filter,
    NodeRef? focus,
    bool clearFocus = false,
    int? nodeBudget,
  }) {
    return ConnectionQuery(
      kindA: kindA ?? this.kindA,
      kindB: kindB ?? this.kindB,
      filter: filter ?? this.filter,
      focus: clearFocus ? null : (focus ?? this.focus),
      nodeBudget: nodeBudget ?? this.nodeBudget,
    );
  }
}
