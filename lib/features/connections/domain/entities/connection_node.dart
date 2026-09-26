import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import 'package:submersion/features/connections/domain/entities/node_ref.dart';

/// A node's second line. Formatting that needs localisation or the diver's
/// unit settings (a date range, a role name) is deferred to presentation, so
/// the repository never produces display text for those.
sealed class NodeSubtitle extends Equatable {
  const NodeSubtitle();
}

/// Plain text already fit to show (a country, a scientific name).
class TextSubtitle extends NodeSubtitle {
  const TextSubtitle(this.text);
  final String text;
  @override
  List<Object?> get props => [text];
}

/// A trip's span, formatted with UnitFormatter.formatDateRange.
class DateRangeSubtitle extends NodeSubtitle {
  const DateRangeSubtitle(this.start, this.end);
  final DateTime start;
  final DateTime end;
  @override
  List<Object?> get props => [start, end];
}

/// A buddy's unanimous dive role id, resolved through diveRoleMapProvider.
class RoleSubtitle extends NodeSubtitle {
  const RoleSubtitle(this.roleId);
  final String roleId;
  @override
  List<Object?> get props => [roleId];
}

class ConnectionNode extends Equatable {
  const ConnectionNode({
    required this.ref,
    required this.label,
    required this.diveCount,
    this.subtitle,
    this.photo,
  });

  final NodeRef ref;
  final String label;

  /// Distinct dives this entity has within the query's scope and filter.
  final int diveCount;
  final NodeSubtitle? subtitle;

  /// Buddy photo bytes when the buddy has one; null for every other kind.
  final Uint8List? photo;

  ConnectionNode copyWith({
    NodeRef? ref,
    String? label,
    int? diveCount,
    NodeSubtitle? subtitle,
    Uint8List? photo,
  }) {
    return ConnectionNode(
      ref: ref ?? this.ref,
      label: label ?? this.label,
      diveCount: diveCount ?? this.diveCount,
      subtitle: subtitle ?? this.subtitle,
      photo: photo ?? this.photo,
    );
  }

  /// Photos compare by identity: the bytes come from one database read, and
  /// a deep compare of every photo on each graph comparison is wasted work.
  @override
  List<Object?> get props => [
    ref,
    label,
    diveCount,
    subtitle,
    _PhotoIdentity(photo),
  ];
}

/// Wraps a photo so Equatable compares it with [identical] rather than
/// element by element.
class _PhotoIdentity {
  const _PhotoIdentity(this.bytes);
  final Uint8List? bytes;

  @override
  bool operator ==(Object other) =>
      other is _PhotoIdentity && identical(other.bytes, bytes);

  @override
  int get hashCode => identityHashCode(bytes);
}
