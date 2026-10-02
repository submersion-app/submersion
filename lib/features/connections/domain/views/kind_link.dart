import 'package:equatable/equatable.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';

/// An unordered pair of kinds whose entities are joined when they share a
/// dive. Stored canonically (lower enum index first) so `KindLink(a, b)` and
/// `KindLink(b, a)` are the same link.
class KindLink extends Equatable {
  factory KindLink(ConnectionKind x, ConnectionKind y) =>
      x.index <= y.index ? KindLink._(x, y) : KindLink._(y, x);

  const KindLink._(this.a, this.b);

  final ConnectionKind a;
  final ConnectionKind b;

  bool get isSameKind => a == b;

  bool touches(ConnectionKind kind) => a == kind || b == kind;

  /// `a-b` with enum names, for JSON.
  String get wire => '${a.name}-${b.name}';

  static KindLink? parse(String? value) {
    if (value == null) return null;
    final parts = value.split('-');
    if (parts.length != 2) return null;
    final x = ConnectionKind.fromName(parts[0]);
    final y = ConnectionKind.fromName(parts[1]);
    if (x == null || y == null) return null;
    return KindLink(x, y);
  }

  @override
  List<Object?> get props => [a, b];

  @override
  String toString() => wire;
}
