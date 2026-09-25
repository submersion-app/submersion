import 'package:equatable/equatable.dart';

import 'package:submersion/features/connections/domain/entities/connection_kind.dart';

/// Identity of a node: the kind plus the entity's own table id.
///
/// Ids from different tables can collide, so nothing in the feature keys on
/// a bare id. Layout, selection, focus and deep links all use this type.
class NodeRef extends Equatable {
  const NodeRef(this.kind, this.id);

  final ConnectionKind kind;
  final String id;

  /// `kind:id`, the form used in route query parameters.
  String get wire => '${kind.name}:$id';

  /// Parses [wire]; null for anything malformed or an unknown kind.
  static NodeRef? parse(String? value) {
    if (value == null) return null;
    final split = value.indexOf(':');
    if (split <= 0 || split == value.length - 1) return null;
    final kind = ConnectionKind.fromName(value.substring(0, split));
    if (kind == null) return null;
    return NodeRef(kind, value.substring(split + 1));
  }

  @override
  List<Object?> get props => [kind, id];

  @override
  String toString() => wire;
}
