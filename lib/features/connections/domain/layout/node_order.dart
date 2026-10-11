import 'package:submersion/features/connections/domain/entities/connection_node.dart';

/// Busiest first, then by label, then by id, so equal nodes keep one order
/// on every device.
int compareDivesLabel(ConnectionNode a, ConnectionNode b) {
  final byDives = b.diveCount.compareTo(a.diveCount);
  if (byDives != 0) return byDives;
  final byLabel = a.label.compareTo(b.label);
  return byLabel != 0 ? byLabel : a.ref.id.compareTo(b.ref.id);
}

/// Kind in enum order first, then [compareDivesLabel]: the reading order the
/// static layouts and the matrix share.
int compareKindDivesLabel(ConnectionNode a, ConnectionNode b) {
  final byKind = a.ref.kind.index.compareTo(b.ref.kind.index);
  return byKind != 0 ? byKind : compareDivesLabel(a, b);
}
