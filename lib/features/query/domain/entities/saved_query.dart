import 'package:meta/meta.dart';

import 'package:submersion/core/query/domain/query_subject.dart';

/// A named query a diver saved (#2365, spec Unit 7). [queryJson] is the
/// versioned AST; [subject] is the root entity's `QuerySubject.name`, kept
/// as text so a row from a newer build with a subject this one lacks still
/// loads (flagged) instead of failing to map.
@immutable
class SavedQuery {
  const SavedQuery({
    required this.id,
    this.diverId,
    required this.subject,
    required this.name,
    required this.queryJson,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? diverId;
  final String subject;
  final String name;
  final String queryJson;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  QuerySubject? get querySubject {
    for (final s in QuerySubject.values) {
      if (s.name == subject) return s;
    }
    return null;
  }

  SavedQuery copyWith({
    String? id,
    String? diverId,
    bool clearDiverId = false,
    String? subject,
    String? name,
    String? queryJson,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SavedQuery(
    id: id ?? this.id,
    diverId: clearDiverId ? null : (diverId ?? this.diverId),
    subject: subject ?? this.subject,
    name: name ?? this.name,
    queryJson: queryJson ?? this.queryJson,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is SavedQuery &&
      other.id == id &&
      other.diverId == diverId &&
      other.subject == subject &&
      other.name == name &&
      other.queryJson == queryJson &&
      other.sortOrder == sortOrder &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    diverId,
    subject,
    name,
    queryJson,
    sortOrder,
    createdAt,
    updatedAt,
  );
}
