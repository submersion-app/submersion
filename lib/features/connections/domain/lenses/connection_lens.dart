import 'package:equatable/equatable.dart';

import '../entities/connection_kind.dart';

/// A named pair of kinds. Phase 1 ships two; phase 2 adds four more and the
/// free pair picker, which produces a [LensSelection.custom] instead.
class ConnectionLens extends Equatable {
  const ConnectionLens({
    required this.id,
    required this.kindA,
    required this.kindB,
  });

  final String id;
  final ConnectionKind kindA;
  final ConnectionKind kindB;

  static const circle = ConnectionLens(
    id: 'circle',
    kindA: ConnectionKind.buddy,
    kindB: ConnectionKind.buddy,
  );

  static const where = ConnectionLens(
    id: 'where',
    kindA: ConnectionKind.buddy,
    kindB: ConnectionKind.site,
  );

  /// The lenses offered in the chip row, in display order.
  static const phase1 = [circle, where];

  static ConnectionLens? byId(String? id) {
    for (final lens in phase1) {
      if (lens.id == id) return lens;
    }
    return null;
  }

  @override
  List<Object?> get props => [id, kindA, kindB];
}

/// The active pair: a built-in lens or a custom pair. Persisted device-local
/// under the SharedPreferences key `connections_last_lens`.
class LensSelection extends Equatable {
  const LensSelection.lens(ConnectionLens this.lens)
    : _customA = null,
      _customB = null;

  const LensSelection.custom({
    required ConnectionKind kindA,
    required ConnectionKind kindB,
  }) : lens = null,
       _customA = kindA,
       _customB = kindB;

  static const fallback = LensSelection.lens(ConnectionLens.circle);

  /// The built-in lens, or null for a custom pair.
  final ConnectionLens? lens;
  final ConnectionKind? _customA;
  final ConnectionKind? _customB;

  String? get lensId => lens?.id;
  ConnectionKind get kindA => lens?.kindA ?? _customA!;
  ConnectionKind get kindB => lens?.kindB ?? _customB!;

  bool get isSelfJoin => kindA == kindB;

  String get persisted => lensId ?? 'custom:${kindA.name}:${kindB.name}';

  static LensSelection? parse(String? value) {
    if (value == null) return null;
    final lens = ConnectionLens.byId(value);
    if (lens != null) return LensSelection.lens(lens);
    final parts = value.split(':');
    if (parts.length != 3 || parts[0] != 'custom') return null;
    final a = ConnectionKind.fromName(parts[1]);
    final b = ConnectionKind.fromName(parts[2]);
    if (a == null || b == null) return null;
    return LensSelection.custom(kindA: a, kindB: b);
  }

  @override
  List<Object?> get props => [lens, _customA, _customB];
}
